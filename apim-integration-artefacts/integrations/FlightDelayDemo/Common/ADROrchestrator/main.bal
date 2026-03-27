// Autonomous Disruption Recovery — ADR Orchestrator Service
// The "Digital War Room" that coordinates all services via REST APIs.
// The AI Agent (natural language interface) is a separate service in Common/AdminAgent/.
//
// When a disruption is detected, this orchestrator:
// 1. Queries the Disruption Detection service for details + seat availability
// 2. Asks the Crew Service to check compliance, evaluate fitness, and find replacements
// 3. Asks the Passenger Service to rebook (with seat tracking), notify, and smart-compensate
// 4. Asks the Logistics Service to reassign gates, redirect catering, and notify ground crews
// 5. Produces a unified Recovery Plan with a full negotiation log
//
// SMART COMPENSATION: Only triggers when no alternative flights have available seats.

import ballerina/http;
import ballerina/log;
import ballerina/sql;
import ballerina/time;
import ballerina/uuid;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

// Database configuration
configurable string username = ?;
configurable string password = ?;
configurable string host = ?;
configurable int port = ?;
configurable string database = ?;

// Service URLs (configurable for Docker networking)
configurable string disruptionServiceUrl = "http://localhost:9090";
configurable string crewServiceUrl = "http://localhost:9091";
configurable string passengerServiceUrl = "http://localhost:9092";
configurable string logisticsServiceUrl = "http://localhost:9093";

mysql:Options mysqlOptions = {
    ssl: {
        mode: mysql:SSL_DISABLED,
        allowPublicKeyRetrieval: true
    }
};

final mysql:Client dbClient = check new (host, username, password, database, port, options = mysqlOptions);

// Service HTTP clients
final http:Client disruptionClient = check new (disruptionServiceUrl);
final http:Client crewClient = check new (crewServiceUrl);
final http:Client passengerClient = check new (passengerServiceUrl);
final http:Client logisticsClient = check new (logisticsServiceUrl);

service /adr on new http:Listener(9094) {

    // =====================================================================
    // ACTION API — Main recovery orchestration
    // =====================================================================

    // POST /adr/recover — Trigger full autonomous recovery with seat-aware logic
    resource function post recover(@http:Payload RecoveryRequest request) returns RecoverySummary|error {
        log:printInfo(string `=== ADR RECOVERY INITIATED for flight ${request.flightId} ===`);
        time:Utc startTime = time:utcNow();

        NegotiationStep[] negotiationLog = [];
        string[] crewDetails = [];
        string[] passengerDetails = [];
        string[] logisticsDetails = [];
        decimal estimatedCost = 0.0;
        int crewReassignments = 0;
        int passengersRebooked = 0;
        int passengersNotified = 0;
        int compensationsIssued = 0;
        int compensatedNoAlternatives = 0;
        decimal totalCompensationValue = 0.0;
        int gateChanges = 0;
        int cateringRedirections = 0;
        int groundTasksCreated = 0;

        // ====================================================================
        // STEP 1: Disruption Detection Service — Get details + seat availability
        // ====================================================================
        log:printInfo("STEP 1: Querying Disruption Detection Service...");
        addNegotiationStep(negotiationLog, "Orchestrator", "Querying Disruption Detection Service for flight details & seat availability", "Initiated");

        FlightInfo flight = check disruptionClient->get(string `/disruption/flights/${request.flightId}`);

        // Get active disruptions for this flight
        DisruptionInfo[] disruptions = check disruptionClient->get("/disruption/delays");
        DisruptionInfo? activeDisruption = ();
        foreach DisruptionInfo d in disruptions {
            if d.flight_id == request.flightId {
                activeDisruption = d;
                break;
            }
        }

        string disruptionId;
        int delayMinutes;
        string severity;
        string reason;

        if activeDisruption is DisruptionInfo {
            disruptionId = activeDisruption.disruption_id;
            delayMinutes = activeDisruption.delay_minutes;
            severity = activeDisruption.severity;
            reason = activeDisruption.reason ?: "Unknown";
        } else {
            // No active disruption found, create one
            json delayPayload = {"delayMinutes": 120, "reason": request.disruptionType};
            DisruptionInfo newDisruption = check disruptionClient->put(
                string `/disruption/flights/${request.flightId}/delay`, delayPayload);
            disruptionId = newDisruption.disruption_id;
            delayMinutes = newDisruption.delay_minutes;
            severity = newDisruption.severity;
            reason = newDisruption.reason ?: request.disruptionType;
        }

        addNegotiationStep(negotiationLog, "DisruptionService",
                string `Flight ${flight.flight_number} (${flight.origin}→${flight.destination}) delayed ${delayMinutes}min`,
                string `Severity: ${severity}. ${flight.passenger_count} passengers affected.`);

        log:printInfo(string `Disruption: ${flight.flight_number} delayed ${delayMinutes}min, severity ${severity}`);

        // ====================================================================
        // STEP 2: Crew Service — Check compliance, evaluate fitness, reassign
        // ====================================================================
        log:printInfo("STEP 2: Consulting Crew Service for compliance + crew fitness...");
        addNegotiationStep(negotiationLog, "Orchestrator", "Consulting Crew Service for duty compliance & crew evaluation", "In progress");

        // Get crew assigned to delayed flight
        CrewAssignmentInfo[] assignments = check crewClient->get(string `/crew/assignments/${request.flightId}`);

        int nonCompliantCrew = 0;
        decimal additionalHours = <decimal>delayMinutes / 60.0;

        foreach CrewAssignmentInfo assignment in assignments {
            // Check if crew can handle the extended duty
            json compliancePayload = {
                "crew_id": assignment.crew_id,
                "flight_id": request.flightId,
                "additional_hours": additionalHours
            };
            ComplianceResult compResult = check crewClient->post("/crew/check-compliance", compliancePayload);

            if !compResult.compliant {
                nonCompliantCrew += 1;
                addNegotiationStep(negotiationLog, "CrewService",
                        string `ALERT: ${compResult.crew_name} (${assignment.role}) will exceed legal duty hours`,
                        string `${compResult.message}. Finding replacement crew.`);

                // Find available replacement crew
                AvailableCrewInfo[] availableCrew = check crewClient->get(
                    string `/crew/available?airport=${flight.origin}&role=${assignment.role}`);

                if availableCrew.length() > 0 {
                    AvailableCrewInfo replacement = availableCrew[0];

                    // Find an alternative flight to reassign to
                    AlternativeFlightInfo[] altFlights = check passengerClient->get(
                        string `/passenger/alternatives/${request.flightId}`);

                    string targetFlight = altFlights.length() > 0 ? altFlights[0].flight_id : request.flightId;

                    json assignPayload = {
                        "crew_id": replacement.crew_id,
                        "flight_id": request.flightId,
                        "role": assignment.role
                    };

                    // The replacement crew takes over the delayed flight
                    json _ = check crewClient->post("/crew/assign", assignPayload);
                    crewReassignments += 1;

                    string detail = string `Replaced ${compResult.crew_name} with ${replacement.first_name} ${replacement.last_name} as ${assignment.role}`;
                    crewDetails.push(detail);
                    addNegotiationStep(negotiationLog, "CrewService",
                            string `Replacement found: ${replacement.first_name} ${replacement.last_name}`,
                            detail);
                } else {
                    string detail = string `WARNING: No available ${assignment.role} at ${flight.origin}. Manual intervention required.`;
                    crewDetails.push(detail);
                    addNegotiationStep(negotiationLog, "CrewService", "No replacement available", detail);
                }
            } else {
                string detail = string `${compResult.crew_name} (${assignment.role}): COMPLIANT — can continue operating`;
                crewDetails.push(detail);
                addNegotiationStep(negotiationLog, "CrewService",
                        string `${compResult.crew_name} compliance check passed`, detail);
            }
        }

        // ====================================================================
        // STEP 3: Passenger Service — Seat-aware rebook, notify, smart-compensate
        // ====================================================================
        log:printInfo("STEP 3: Activating Passenger Service for seat-aware rebooking...");
        addNegotiationStep(negotiationLog, "Orchestrator", "Activating Passenger Service for seat-aware passenger recovery", "In progress");

        // Get all affected passengers
        BookingInfo[] affectedPassengers = check passengerClient->get(string `/passenger/bookings/${request.flightId}`);

        // Get alternative flights
        AlternativeFlightInfo[] alternatives = check passengerClient->get(
            string `/passenger/alternatives/${request.flightId}`);

        // Build seat availability map from Disruption Detection service
        map<int> altRemainingSeats = {};
        foreach AlternativeFlightInfo alt in alternatives {
            // Query seat availability for each alternative flight
            SeatAvailabilityInfo|error seatInfo = disruptionClient->get(string `/disruption/flights/${alt.flight_id}/seats`);
            if seatInfo is SeatAvailabilityInfo {
                altRemainingSeats[alt.flight_id] = seatInfo.total_available;
            } else {
                // Fallback: estimate from aircraft capacity
                altRemainingSeats[alt.flight_id] = alt.available_seats;
            }
        }

        addNegotiationStep(negotiationLog, "PassengerService",
                string `Found ${affectedPassengers.length()} affected passengers`,
                string `${alternatives.length()} alternative flight(s) available. Seat availability tracked.`);

        // Get current hour for compensation reasoning
        time:Civil now = time:utcToCivil(time:utcNow());
        int currentHour = now.hour;

        // Process each passenger (prioritized by loyalty tier in the query)
        foreach BookingInfo pax in affectedPassengers {
            boolean wasRebooked = false;

            // Only attempt rebook if the disruption is severe enough
            if delayMinutes >= 120 && alternatives.length() > 0 {
                // Find an alternative flight that still has seats
                string? targetFlightId = ();
                foreach AlternativeFlightInfo alt in alternatives {
                    int? remaining = altRemainingSeats[alt.flight_id];
                    if remaining is int && remaining > 0 {
                        targetFlightId = alt.flight_id;
                        break;
                    }
                }

                if targetFlightId is string {
                    json rebookPayload = {
                        "passenger_id": pax.passenger_id,
                        "original_flight_id": request.flightId,
                        "new_flight_id": targetFlightId
                    };

                    RebookResultInfo|error rebookResult = passengerClient->post("/passenger/rebook", rebookPayload);
                    if rebookResult is RebookResultInfo {
                        passengersRebooked += 1;
                        wasRebooked = true;
                        // Decrement tracked available seats
                        int? currentSeats = altRemainingSeats[targetFlightId];
                        if currentSeats is int {
                            altRemainingSeats[targetFlightId] = currentSeats - 1;
                        }
                        string seatStatus = rebookResult.seat_confirmed ? "SEAT CONFIRMED" : "WAITLISTED";
                        string detail = string `${pax.first_name} ${pax.last_name} (${pax.loyalty_tier}) → ${targetFlightId} in ${rebookResult.booking_class} [${seatStatus}]`;
                        passengerDetails.push(detail);
                    }
                } else {
                    // No alternative flights with available seats!
                    string detail = string `${pax.first_name} ${pax.last_name} (${pax.loyalty_tier}): NO SEATS AVAILABLE on any alternative — smart compensation triggered`;
                    passengerDetails.push(detail);
                }
            }

            // Determine compensation (smart: if no alternatives available, flag it)
            boolean noAlternativesAvailable = delayMinutes >= 120 && !wasRebooked;
            json compensationPayload = {
                "passenger_id": pax.passenger_id,
                "flight_id": request.flightId,
                "delay_minutes": delayMinutes,
                "current_hour": currentHour,
                "no_alternatives_available": noAlternativesAvailable
            };

            CompensationResultInfo|error compResult = passengerClient->post("/passenger/compensation", compensationPayload);
            if compResult is CompensationResultInfo {
                compensationsIssued += 1;
                totalCompensationValue += compResult.total_value;
                estimatedCost += compResult.total_value;

                if compResult.triggered_by_no_availability {
                    compensatedNoAlternatives += 1;
                }

                if pax.loyalty_tier == "PLATINUM" || pax.loyalty_tier == "GOLD" || noAlternativesAvailable {
                    passengerDetails.push(string `Compensation for ${compResult.passenger_name} (${pax.loyalty_tier}): ${compResult.reasoning}`);
                }
            }

            // Notify passenger with context-aware message
            string notificationMsg;
            if wasRebooked {
                notificationMsg = string `Dear ${pax.first_name}, your flight ${flight.flight_number} has been delayed. You have been automatically rebooked to an alternative flight. Check your email for details.`;
            } else if noAlternativesAvailable {
                notificationMsg = string `Dear ${pax.first_name}, your flight ${flight.flight_number} has been significantly delayed and no alternative flights with available seats were found. Enhanced compensation has been applied to your account. Our team will contact you with options.`;
            } else {
                notificationMsg = string `Dear ${pax.first_name}, your flight ${flight.flight_number} is delayed by ${delayMinutes} minutes. We apologize for the inconvenience.`;
            }

            json notifyPayload = {
                "passenger_id": pax.passenger_id,
                "notification_type": "EMAIL",
                "message": notificationMsg
            };
            json _ = check passengerClient->post("/passenger/notify", notifyPayload);
            passengersNotified += 1;
        }

        addNegotiationStep(negotiationLog, "PassengerService",
                string `Recovery complete: ${passengersRebooked} rebooked, ${passengersNotified} notified, ${compensationsIssued} compensated`,
                string `Total compensation: $${totalCompensationValue}. ${compensatedNoAlternatives} compensated due to no seat availability.`);

        // ====================================================================
        // STEP 4: Logistics Service — Gate, catering, ground handling
        // ====================================================================
        log:printInfo("STEP 4: Coordinating with Logistics Service...");
        addNegotiationStep(negotiationLog, "Orchestrator", "Coordinating Logistics Service for ground operations", "In progress");

        // Check if gate change is needed (for long delays, free up the gate)
        if delayMinutes >= 120 {
            // Find available gate
            GateInfo[] availableGates = check logisticsClient->get(
                string `/logistics/gates/available/${flight.origin}`);

            if availableGates.length() > 0 {
                GateInfo newGate = availableGates[0];
                json gatePayload = {
                    "flight_id": request.flightId,
                    "gate_id": newGate.gate_id
                };

                GateAssignResultInfo gateResult = check logisticsClient->post("/logistics/gates/assign", gatePayload);
                gateChanges += 1;
                logisticsDetails.push(gateResult.message);
                addNegotiationStep(negotiationLog, "LogisticsService", "Gate reassigned", gateResult.message);

                // Redirect catering to new gate
                json cateringPayload = {
                    "flight_id": request.flightId,
                    "new_gate": newGate.gate_id,
                    "notes": "Redirected due to gate change from disruption recovery"
                };
                CateringRedirectResultInfo cateringResult = check logisticsClient->post("/logistics/catering/redirect", cateringPayload);
                cateringRedirections += cateringResult.orders_redirected;
                logisticsDetails.push(cateringResult.message);
                addNegotiationStep(negotiationLog, "LogisticsService", "Catering redirected", cateringResult.message);
            }
        }

        // Create ground handling tasks for the disruption
        json baggagePayload = {
            "flight_id": request.flightId,
            "task_type": "BAGGAGE_TRANSFER",
            "gate": flight.gate,
            "assigned_team": null,
            "notes": string `Disruption recovery — transfer bags for ${passengersRebooked} rebooked passengers`
        };
        GroundHandlingResultInfo baggageResult = check logisticsClient->post("/logistics/ground-handling/notify", baggagePayload);
        groundTasksCreated += 1;
        logisticsDetails.push(baggageResult.message);

        // Notify gate change to ground crew
        json gateChangePayload = {
            "flight_id": request.flightId,
            "task_type": "GATE_CHANGE",
            "gate": flight.gate,
            "assigned_team": null,
            "notes": "Disruption recovery — coordinate new gate assignment"
        };
        GroundHandlingResultInfo gateChangeResult = check logisticsClient->post("/logistics/ground-handling/notify", gateChangePayload);
        groundTasksCreated += 1;
        logisticsDetails.push(gateChangeResult.message);

        addNegotiationStep(negotiationLog, "LogisticsService",
                string `Logistics coordinated: ${gateChanges} gate change(s), ${cateringRedirections} catering redirect(s), ${groundTasksCreated} ground task(s)`,
                "Ground operations updated");

        // ====================================================================
        // STEP 5: Create the Recovery Plan record
        // ====================================================================
        string planId = uuid:createType1AsString();

        sql:ParameterizedQuery insertPlan = `INSERT INTO recovery_plans 
            (plan_id, disruption_id, flight_id, status, total_passengers_affected, passengers_rebooked,
             crew_reassignments, gate_changes, estimated_cost, total_compensations, negotiation_log)
            VALUES (${planId}, ${disruptionId}, ${request.flightId}, 'COMPLETED', 
                    ${affectedPassengers.length()}, ${passengersRebooked}, ${crewReassignments}, 
                    ${gateChanges}, ${estimatedCost}, ${totalCompensationValue}, 
                    ${negotiationLog.toJsonString()})`;
        _ = check dbClient->execute(insertPlan);

        // Update disruption status
        sql:ParameterizedQuery updateDisruption = `UPDATE disruptions 
            SET status = 'RECOVERY_IN_PROGRESS' WHERE disruption_id = ${disruptionId}`;
        _ = check dbClient->execute(updateDisruption);

        time:Utc endTime = time:utcNow();
        decimal durationSeconds = <decimal>(time:utcDiffSeconds(endTime, startTime));

        addNegotiationStep(negotiationLog, "Orchestrator",
                "Recovery plan complete",
                string `Executed in ${durationSeconds} seconds. Plan ID: ${planId}`);

        log:printInfo(string `=== ADR RECOVERY COMPLETE === Plan: ${planId}, Duration: ${durationSeconds}s ===`);

        return {
            plan_id: planId,
            flight_id: request.flightId,
            disruption_id: disruptionId,
            status: "COMPLETED",
            disruption: {
                flight_id: request.flightId,
                flight_number: flight.flight_number,
                delay_minutes: delayMinutes,
                severity: severity,
                reason: reason
            },
            crew: {
                compliance_checks: assignments.length(),
                non_compliant_crew: nonCompliantCrew,
                reassignments: crewReassignments,
                details: crewDetails
            },
            passengers: {
                total_affected: affectedPassengers.length(),
                rebooked: passengersRebooked,
                notified: passengersNotified,
                compensations_issued: compensationsIssued,
                compensated_no_alternatives: compensatedNoAlternatives,
                total_compensation_value: totalCompensationValue,
                details: passengerDetails
            },
            logistics: {
                gate_changes: gateChanges,
                catering_redirections: cateringRedirections,
                ground_tasks_created: groundTasksCreated,
                details: logisticsDetails
            },
            negotiation_log: negotiationLog,
            estimated_cost: estimatedCost,
            message: string `Recovery plan ${planId} executed in ${durationSeconds}s. ` +
                string `${affectedPassengers.length()} passengers affected, ${passengersRebooked} rebooked, ` +
                string `${crewReassignments} crew reassignment(s), ${gateChanges} gate change(s). ` +
                string `Est. cost: $${estimatedCost}`
        };
    }

    // ========================================================================
    // GET /adr/recovery-plans — List all recovery plans
    // ========================================================================
    resource function get recovery\-plans() returns RecoveryPlan[]|error {
        log:printInfo("Fetching all recovery plans");
        sql:ParameterizedQuery query = `SELECT plan_id, disruption_id, flight_id, status, 
            total_passengers_affected, passengers_rebooked, crew_reassignments, gate_changes,
            estimated_cost, total_compensations, negotiation_log
            FROM recovery_plans ORDER BY created_at DESC`;
        stream<RecoveryPlan, sql:Error?> resultStream = dbClient->query(query);
        RecoveryPlan[] plans = [];
        check from RecoveryPlan plan in resultStream
            do {
                plans.push(plan);
            };
        return plans;
    }

    // ========================================================================
    // GET /adr/recovery-plans/{id} — Get recovery plan details
    // ========================================================================
    resource function get recovery\-plans/[string id]() returns RecoveryPlan|http:NotFound|error {
        log:printInfo("Fetching recovery plan: " + id);
        sql:ParameterizedQuery query = `SELECT plan_id, disruption_id, flight_id, status, 
            total_passengers_affected, passengers_rebooked, crew_reassignments, gate_changes,
            estimated_cost, total_compensations, negotiation_log
            FROM recovery_plans WHERE plan_id = ${id}`;
        RecoveryPlan|sql:Error result = dbClient->queryRow(query);
        if result is sql:NoRowsError {
            return http:NOT_FOUND;
        }
        return result;
    }
}

// Helper function to add a step to the negotiation log
function addNegotiationStep(NegotiationStep[] log, string agent, string action, string result) {
    time:Utc now = time:utcNow();
    log.push({
        agent: agent,
        action: action,
        result: result,
        timestamp: time:utcToString(now)
    });
}


