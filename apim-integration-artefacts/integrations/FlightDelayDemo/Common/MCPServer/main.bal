// =============================================================================
// ADR Flight Recovery — MCP (Model Context Protocol) Server
// =============================================================================
// Exposes all service capabilities as MCP tools for dynamic AI tool discovery.
// Any MCP-compatible client (Claude Desktop, VS Code Copilot, custom AI agents)
// can connect and use these tools.
//
// Architecture:
// - Listens on port 9096 at /mcp (Streamable HTTP transport)
// - Proxies tool calls to the underlying Ballerina microservices
// - 22 tools spanning: Recovery, Disruption, Crew, Passenger, Logistics

import ballerina/http;
import ballerina/log;
import ballerina/mcp;

// ── Configurable service URLs ──────────────────────────────────────────────
configurable string disruptionServiceUrl = "http://localhost:9090";
configurable string crewServiceUrl = "http://localhost:9091";
configurable string passengerServiceUrl = "http://localhost:9092";
configurable string logisticsServiceUrl = "http://localhost:9093";
configurable string orchestratorUrl = "http://localhost:9094";
configurable int mcpPort = 9096;

// ── HTTP clients for downstream services ───────────────────────────────────
final http:Client disruptionClient = check new (disruptionServiceUrl);
final http:Client crewClient = check new (crewServiceUrl);
final http:Client passengerClient = check new (passengerServiceUrl);
final http:Client logisticsClient = check new (logisticsServiceUrl);
final http:Client orchestratorClient = check new (orchestratorUrl);

listener mcp:Listener mcpListener = check new (mcpPort);

@mcp:ServiceConfig {
    info: {
        name: "ADR Flight Recovery MCP Server",
        version: "1.0.0"
    },
    sessionMode: mcp:STATELESS,
    options: {
        instructions: string `This MCP server provides tools for autonomous disruption recovery (ADR) in airline operations.

Tool categories:
- Recovery Operations: Trigger and monitor full autonomous recovery workflows
- Disruption Detection: Query flights, delays, seat availability, and disruption assessments
- Crew Management: Check crew assignments, compliance, availability, and reassignment
- Passenger Management: View bookings, find alternatives, rebook, notify, and compensate passengers
- Logistics: Manage gates, catering, and ground handling tasks

Typical workflow:
1. Use get_active_delays or assess_disruption to identify disrupted flights
2. Use trigger_recovery for automated end-to-end recovery, OR
3. Use individual tools for manual step-by-step recovery operations`
    }
}
service mcp:Service /mcp on mcpListener {

    function init() {
        log:printInfo(string `ADR MCP Server starting on port ${mcpPort}`);
        log:printInfo(string `  Disruption Detection: ${disruptionServiceUrl}`);
        log:printInfo(string `  Crew Service: ${crewServiceUrl}`);
        log:printInfo(string `  Passenger Service: ${passengerServiceUrl}`);
        log:printInfo(string `  Logistics Service: ${logisticsServiceUrl}`);
        log:printInfo(string `  Orchestrator: ${orchestratorUrl}`);
    }

    // ========================================================================
    // RECOVERY OPERATIONS (via ADR Orchestrator)
    // ========================================================================

    # Trigger full autonomous recovery for a disrupted flight.
    # Orchestrates crew compliance checks, passenger rebooking with seat tracking,
    # logistics coordination, and produces a unified recovery plan.
    #
    # + flight_id - The flight ID (e.g. FL001, FL002)
    # + disruption_type - Type of disruption: DELAY, CANCELLATION, or DIVERSION
    # + return - Recovery plan summary with crew, passenger, and logistics details
    @mcp:Tool {
        description: "Trigger full autonomous recovery for a disrupted flight. Orchestrates crew compliance, passenger rebooking, logistics coordination, and produces a unified recovery plan."
    }
    remote function trigger_recovery(string flight_id, string disruption_type) returns json|error {
        log:printInfo(string `MCP Tool: trigger_recovery(${flight_id}, ${disruption_type})`);
        json payload = {"flightId": flight_id, "disruptionType": disruption_type};
        json result = check orchestratorClient->post("/adr/recover", payload);
        return result;
    }

    # Get detailed information about a specific recovery plan.
    #
    # + plan_id - The recovery plan UUID
    # + return - Recovery plan details including status, passengers affected, crew changes, and costs
    @mcp:Tool {
        description: "Get detailed information about a specific recovery plan by its plan ID (UUID)."
    }
    remote function get_recovery_plan(string plan_id) returns json|error {
        log:printInfo(string `MCP Tool: get_recovery_plan(${plan_id})`);
        json result = check orchestratorClient->get(string `/adr/recovery-plans/${plan_id}`);
        return result;
    }

    # List all recovery plans that have been created in the system.
    #
    # + return - Array of recovery plans ordered by creation time (newest first)
    @mcp:Tool {
        description: "List all recovery plans that have been created. Returns plan IDs, statuses, passenger counts, and costs."
    }
    remote function list_recovery_plans() returns json|error {
        log:printInfo("MCP Tool: list_recovery_plans()");
        json result = check orchestratorClient->get("/adr/recovery-plans");
        return result;
    }

    // ========================================================================
    // DISRUPTION DETECTION (via Disruption Detection Service)
    // ========================================================================

    # Get a list of all flights in the system with their current status.
    #
    # + return - Array of flight records with ID, airline, route, status, and passenger counts
    @mcp:Tool {
        description: "Get a list of all flights in the system with their current status, route, and passenger count."
    }
    remote function get_all_flights() returns json|error {
        log:printInfo("MCP Tool: get_all_flights()");
        json result = check disruptionClient->get("/disruption/flights");
        return result;
    }

    # Get detailed information about a specific flight.
    #
    # + flight_id - The flight ID (e.g. FL001)
    # + return - Flight details including airline, route, status, gate, and seat configuration
    @mcp:Tool {
        description: "Get detailed information about a specific flight by its ID (e.g. FL001). Returns airline, route, status, gate, and seat counts."
    }
    remote function get_flight_details(string flight_id) returns json|error {
        log:printInfo(string `MCP Tool: get_flight_details(${flight_id})`);
        json result = check disruptionClient->get(string `/disruption/flights/${flight_id}`);
        return result;
    }

    # Get seat availability for a specific flight by class.
    #
    # + flight_id - The flight ID
    # + return - Seat availability breakdown: total capacity, booked, and available by class
    @mcp:Tool {
        description: "Get seat availability for a specific flight. Returns total capacity, booked seats, and available seats."
    }
    remote function get_flight_seats(string flight_id) returns json|error {
        log:printInfo(string `MCP Tool: get_flight_seats(${flight_id})`);
        json result = check disruptionClient->get(string `/disruption/flights/${flight_id}/seats`);
        return result;
    }

    # Assess a flight for potential disruptions and operational readiness.
    #
    # + flight_id - The flight ID to assess
    # + return - Assessment including crew requirements, disruption risk, and operational status
    @mcp:Tool {
        description: "Assess a flight for potential disruptions. Returns crew requirements, disruption risk, and operational readiness status."
    }
    remote function assess_disruption(string flight_id) returns json|error {
        log:printInfo(string `MCP Tool: assess_disruption(${flight_id})`);
        json result = check disruptionClient->get(string `/disruption/flights/${flight_id}/assess`);
        return result;
    }

    # Get all active flight delays and disruptions across the system.
    #
    # + return - Array of active disruptions with delay duration, severity, and status
    @mcp:Tool {
        description: "Get all active flight delays and disruptions. Returns disruption type, delay minutes, severity, and status for each."
    }
    remote function get_active_delays() returns json|error {
        log:printInfo("MCP Tool: get_active_delays()");
        json result = check disruptionClient->get("/disruption/delays");
        return result;
    }

    # Report or update a delay for a specific flight.
    #
    # + flight_id - The flight ID to report delay for
    # + delay_minutes - Duration of the delay in minutes
    # + reason - Reason for the delay (e.g. WEATHER, MECHANICAL, CREW_SHORTAGE)
    # + return - Created/updated disruption record with severity assessment
    @mcp:Tool {
        description: "Report a delay for a flight. Creates or updates the delay record with severity assessment."
    }
    remote function report_flight_delay(string flight_id, string delay_minutes, string reason) returns json|error {
        int delayMins = check int:fromString(delay_minutes);
        log:printInfo(string `MCP Tool: report_flight_delay(${flight_id}, ${delayMins}min, ${reason})`);
        json payload = {"delayMinutes": delayMins, "reason": reason};
        json result = check disruptionClient->put(string `/disruption/flights/${flight_id}/delay`, payload);
        return result;
    }

    // ========================================================================
    // CREW MANAGEMENT (via Crew Service)
    // ========================================================================

    # Get crew members currently assigned to a specific flight.
    #
    # + flight_id - The flight ID
    # + return - Array of crew assignments with crew ID, role, and status
    @mcp:Tool {
        description: "Get crew members assigned to a specific flight. Returns crew IDs, roles (CAPTAIN, FIRST_OFFICER, CABIN_CREW), and assignment status."
    }
    remote function get_crew_assignments(string flight_id) returns json|error {
        log:printInfo(string `MCP Tool: get_crew_assignments(${flight_id})`);
        json result = check crewClient->get(string `/crew/assignments/${flight_id}`);
        return result;
    }

    # Get available crew members at a specific airport, optionally filtered by role.
    #
    # + airport - Airport code (e.g. JFK, LAX, ORD)
    # + role - Crew role to filter by (e.g. CAPTAIN, FIRST_OFFICER, CABIN_CREW). Use empty string for all roles.
    # + return - Array of available crew with duty hours and qualification details
    @mcp:Tool {
        description: "Get available crew members at an airport, optionally filtered by role. Returns crew details, duty hours, and availability status."
    }
    remote function get_available_crew(string airport, string role) returns json|error {
        log:printInfo(string `MCP Tool: get_available_crew(${airport}, ${role})`);
        string query = role.length() > 0 ? string `?airport=${airport}&role=${role}` : string `?airport=${airport}`;
        json result = check crewClient->get(string `/crew/available${query}`);
        return result;
    }

    # Check if a crew member can handle additional duty hours without violating compliance limits.
    #
    # + crew_id - The crew member's ID
    # + flight_id - The flight they're assigned to
    # + additional_hours - Extra duty hours to check (e.g. from a delay)
    # + return - Compliance result with current hours, limits, and whether the crew member is compliant
    @mcp:Tool {
        description: "Check crew duty compliance. Determines if a crew member can handle additional hours without exceeding legal duty limits."
    }
    remote function check_crew_compliance(string crew_id, string flight_id, string additional_hours) returns json|error {
        decimal addHours = check decimal:fromString(additional_hours);
        log:printInfo(string `MCP Tool: check_crew_compliance(${crew_id}, ${flight_id}, ${addHours}h)`);
        json payload = {"crew_id": crew_id, "flight_id": flight_id, "additional_hours": addHours};
        json result = check crewClient->post("/crew/check-compliance", payload);
        return result;
    }

    # Reassign a crew member to a different flight or role.
    #
    # + crew_id - The crew member's ID
    # + flight_id - Target flight to assign to
    # + role - Role for the assignment (CAPTAIN, FIRST_OFFICER, CABIN_CREW)
    # + return - Reassignment result with confirmation details
    @mcp:Tool {
        description: "Reassign a crew member to a flight with a specific role. Use after checking compliance and finding available crew."
    }
    remote function reassign_crew(string crew_id, string flight_id, string role) returns json|error {
        log:printInfo(string `MCP Tool: reassign_crew(${crew_id}, ${flight_id}, ${role})`);
        json payload = {"crew_id": crew_id, "flight_id": flight_id, "role": role};
        json result = check crewClient->post("/crew/reassign", payload);
        return result;
    }

    // ========================================================================
    // PASSENGER MANAGEMENT (via Passenger Service)
    // ========================================================================

    # Get all passenger bookings for a specific flight.
    #
    # + flight_id - The flight ID
    # + return - Array of booking records with passenger details, class, loyalty tier, and special needs
    @mcp:Tool {
        description: "Get all passenger bookings for a flight. Returns passenger names, booking class, loyalty tier, and special needs."
    }
    remote function get_passenger_bookings(string flight_id) returns json|error {
        log:printInfo(string `MCP Tool: get_passenger_bookings(${flight_id})`);
        json result = check passengerClient->get(string `/passenger/bookings/${flight_id}`);
        return result;
    }

    # Get detailed alternative flight options for rebooking passengers from a disrupted flight.
    #
    # + flight_id - The disrupted flight ID
    # + return - Array of alternative flights with available seats and schedule details
    @mcp:Tool {
        description: "Get alternative flight options for passengers on a disrupted flight. Returns available flights with seat counts for rebooking."
    }
    remote function get_alternative_flights(string flight_id) returns json|error {
        log:printInfo(string `MCP Tool: get_alternative_flights(${flight_id})`);
        json result = check passengerClient->get(string `/passenger/alternatives-detailed/${flight_id}`);
        return result;
    }

    # Rebook a passenger from their disrupted flight to a new flight.
    #
    # + passenger_id - The passenger's ID
    # + original_flight_id - The disrupted flight the passenger was on
    # + new_flight_id - The alternative flight to rebook to
    # + return - Rebooking result with new booking details and seat confirmation status
    @mcp:Tool {
        description: "Rebook a passenger from a disrupted flight to a new flight. Returns seat confirmation and new booking details."
    }
    remote function rebook_passenger(string passenger_id, string original_flight_id, string new_flight_id) returns json|error {
        log:printInfo(string `MCP Tool: rebook_passenger(${passenger_id}, ${original_flight_id} → ${new_flight_id})`);
        json payload = {
            "passenger_id": passenger_id,
            "original_flight_id": original_flight_id,
            "new_flight_id": new_flight_id
        };
        json result = check passengerClient->post("/passenger/rebook", payload);
        return result;
    }

    # Send a notification to a passenger about their flight status.
    #
    # + passenger_id - The passenger's ID
    # + notification_type - Type of notification: EMAIL, SMS, or PUSH
    # + message - The notification message content
    # + return - Notification delivery confirmation
    @mcp:Tool {
        description: "Send a notification to a passenger. Supports EMAIL, SMS, and PUSH notification types."
    }
    remote function notify_passenger(string passenger_id, string notification_type, string message) returns json|error {
        log:printInfo(string `MCP Tool: notify_passenger(${passenger_id}, ${notification_type})`);
        json payload = {
            "passenger_id": passenger_id,
            "notification_type": notification_type,
            "message": message
        };
        json result = check passengerClient->post("/passenger/notify", payload);
        return result;
    }

    # Process compensation for a passenger affected by a flight disruption.
    # Uses smart compensation logic based on delay duration, loyalty tier, and seat availability.
    #
    # + passenger_id - The passenger's ID
    # + flight_id - The disrupted flight ID
    # + delay_minutes - Duration of the delay in minutes
    # + no_alternatives_available - Whether alternative flights have no available seats
    # + return - Compensation details with reasoning, amount, and whether triggered by no availability
    @mcp:Tool {
        description: "Process smart compensation for a disrupted passenger. Considers delay duration, loyalty tier, and seat availability."
    }
    remote function process_compensation(string passenger_id, string flight_id, string delay_minutes,
            string no_alternatives_available) returns json|error {
        int delayMins = check int:fromString(delay_minutes);
        boolean noAlts = no_alternatives_available == "true";
        log:printInfo(string `MCP Tool: process_compensation(${passenger_id}, ${flight_id}, ${delayMins}min)`);
        json payload = {
            "passenger_id": passenger_id,
            "flight_id": flight_id,
            "delay_minutes": delayMins,
            "current_hour": 12,
            "no_alternatives_available": noAlts
        };
        json result = check passengerClient->post("/passenger/compensation", payload);
        return result;
    }

    // ========================================================================
    // LOGISTICS (via Logistics Service)
    // ========================================================================

    # Get available gates at a specific airport.
    #
    # + airport - Airport code (e.g. JFK, LAX, ORD)
    # + return - Array of available gates with terminal, gate type, and status
    @mcp:Tool {
        description: "Get available gates at an airport. Returns gate IDs, terminals, gate types, and availability status."
    }
    remote function get_available_gates(string airport) returns json|error {
        log:printInfo(string `MCP Tool: get_available_gates(${airport})`);
        json result = check logisticsClient->get(string `/logistics/gates/available/${airport}`);
        return result;
    }

    # Assign a gate to a flight.
    #
    # + flight_id - The flight ID
    # + gate_id - The gate ID to assign
    # + return - Gate assignment confirmation
    @mcp:Tool {
        description: "Assign a gate to a flight. Use after checking available gates at the airport."
    }
    remote function assign_gate(string flight_id, string gate_id) returns json|error {
        log:printInfo(string `MCP Tool: assign_gate(${flight_id}, ${gate_id})`);
        json payload = {"flight_id": flight_id, "gate_id": gate_id};
        json result = check logisticsClient->post("/logistics/gates/assign", payload);
        return result;
    }

    # Redirect catering orders to a new gate after a gate change.
    #
    # + flight_id - The flight ID
    # + new_gate - The new gate ID to redirect catering to
    # + return - Catering redirection result with number of orders redirected
    @mcp:Tool {
        description: "Redirect catering orders to a new gate after a gate change. Returns the number of catering orders redirected."
    }
    remote function redirect_catering(string flight_id, string new_gate) returns json|error {
        log:printInfo(string `MCP Tool: redirect_catering(${flight_id}, gate=${new_gate})`);
        json payload = {
            "flight_id": flight_id,
            "new_gate": new_gate,
            "notes": "Redirected via MCP tool due to gate change"
        };
        json result = check logisticsClient->post("/logistics/catering/redirect", payload);
        return result;
    }

    # Create a ground handling task for airport ground crew.
    #
    # + flight_id - The flight ID
    # + task_type - Task type: BAGGAGE_TRANSFER, GATE_CHANGE, CLEANING, FUELING, or DE_ICING
    # + notes - Additional notes or instructions for the ground crew
    # + return - Created task details with task ID and confirmation
    @mcp:Tool {
        description: "Create a ground handling task (BAGGAGE_TRANSFER, GATE_CHANGE, CLEANING, FUELING, DE_ICING) for airport ground crew."
    }
    remote function notify_ground_handling(string flight_id, string task_type, string notes) returns json|error {
        log:printInfo(string `MCP Tool: notify_ground_handling(${flight_id}, ${task_type})`);
        json payload = {
            "flight_id": flight_id,
            "task_type": task_type,
            "gate": null,
            "assigned_team": null,
            "notes": notes
        };
        json result = check logisticsClient->post("/logistics/ground-handling/notify", payload);
        return result;
    }
}
