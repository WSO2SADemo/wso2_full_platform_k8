// Autonomous Disruption Recovery — Disruption Detection Service
// Monitors flights, detects delays, and manages disruption events.
// Separated into: Data APIs | Reasoning APIs | Action APIs (for future AI/MCP integration)

import ballerina/http;
import ballerina/log;
import ballerina/sql;
import ballerina/uuid;
import ballerina/time;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

// Database configuration
configurable string username = ?;
configurable string password = ?;
configurable string host = ?;
configurable int port = ?;
configurable string database = ?;

mysql:Options mysqlOptions = {
    ssl: {
        mode: mysql:SSL_DISABLED,
        allowPublicKeyRetrieval: true
    }
};

final mysql:Client dbClient = check new (host, username, password, database, port, options = mysqlOptions);

// Common flight columns for SELECT queries
final string FLIGHT_COLS = "flight_id, airline, flight_number, origin, destination, scheduled_departure, scheduled_arrival, actual_departure, actual_arrival, aircraft_type, gate, status, passenger_count, seats_first, seats_business, seats_premium_economy, seats_economy, required_captains, required_first_officers, required_cabin_crew_leads, required_cabin_crew";

service /disruption on new http:Listener(9090) {

    // =====================================================================
    // DATA APIs — Pure read operations (future: MCP tools for LLM context)
    // =====================================================================

    // GET /disruption/flights — List all flights
    resource function get flights() returns Flight[]|error {
        log:printInfo("Fetching all flights");
        sql:ParameterizedQuery query = `SELECT flight_id, airline, flight_number, origin, destination,
            scheduled_departure, scheduled_arrival, actual_departure, actual_arrival,
            aircraft_type, gate, status, passenger_count,
            seats_first, seats_business, seats_premium_economy, seats_economy,
            required_captains, required_first_officers, required_cabin_crew_leads, required_cabin_crew
            FROM flights`;
        stream<Flight, sql:Error?> resultStream = dbClient->query(query);
        Flight[] flights = [];
        check from Flight flight in resultStream
            do {
                flights.push(flight);
            };
        return flights;
    }

    // GET /disruption/flights/{id} — Get flight details
    resource function get flights/[string id]() returns Flight|http:NotFound|error {
        log:printInfo("Fetching flight: " + id);
        sql:ParameterizedQuery query = `SELECT flight_id, airline, flight_number, origin, destination,
            scheduled_departure, scheduled_arrival, actual_departure, actual_arrival,
            aircraft_type, gate, status, passenger_count,
            seats_first, seats_business, seats_premium_economy, seats_economy,
            required_captains, required_first_officers, required_cabin_crew_leads, required_cabin_crew
            FROM flights WHERE flight_id = ${id}`;
        Flight|sql:Error result = dbClient->queryRow(query);
        if result is sql:NoRowsError {
            return http:NOT_FOUND;
        }
        return result;
    }

    // GET /disruption/flights/{id}/seats — Get seat availability for a flight
    resource function get flights/[string id]/seats() returns SeatAvailability|http:NotFound|error {
        log:printInfo("Fetching seat availability for flight: " + id);
        sql:ParameterizedQuery query = `SELECT id, flight_id, seat_class, total_seats, booked_seats 
            FROM seat_inventory WHERE flight_id = ${id}`;
        stream<SeatInventory, sql:Error?> resultStream = dbClient->query(query);
        SeatClassInfo[] classes = [];
        int totalCap = 0;
        int totalBooked = 0;
        check from SeatInventory si in resultStream
            do {
                int avail = si.total_seats - si.booked_seats;
                classes.push({seat_class: si.seat_class, total_seats: si.total_seats, booked_seats: si.booked_seats, available_seats: avail});
                totalCap += si.total_seats;
                totalBooked += si.booked_seats;
            };
        if classes.length() == 0 {
            return http:NOT_FOUND;
        }
        return {flight_id: id, classes: classes, total_capacity: totalCap, total_booked: totalBooked, total_available: totalCap - totalBooked};
    }

    // GET /disruption/flights/{id}/crew-requirements — Get crew requirements for a flight
    resource function get flights/[string id]/crew\-requirements() returns CrewRequirementSummary|http:NotFound|error {
        log:printInfo("Fetching crew requirements for flight: " + id);
        sql:ParameterizedQuery query = `SELECT id, flight_id, role, required_count, assigned_count 
            FROM flight_crew_requirements WHERE flight_id = ${id}`;
        stream<FlightCrewRequirement, sql:Error?> resultStream = dbClient->query(query);
        FlightCrewRequirement[] reqs = [];
        int totalReq = 0;
        int totalAsgn = 0;
        check from FlightCrewRequirement r in resultStream
            do {
                reqs.push(r);
                totalReq += r.required_count;
                totalAsgn += r.assigned_count;
            };
        if reqs.length() == 0 {
            return http:NOT_FOUND;
        }
        return {flight_id: id, requirements: reqs, fully_staffed: totalAsgn >= totalReq, total_required: totalReq, total_assigned: totalAsgn};
    }

    // GET /disruption/delays — Get all active disruptions
    resource function get delays() returns Disruption[]|error {
        log:printInfo("Fetching all active disruptions");
        sql:ParameterizedQuery query = `SELECT disruption_id, flight_id, disruption_type, delay_minutes, 
            reason, severity, status, detected_at, resolved_at 
            FROM disruptions WHERE status != 'RESOLVED' ORDER BY detected_at DESC`;
        stream<Disruption, sql:Error?> resultStream = dbClient->query(query);
        Disruption[] disruptions = [];
        check from Disruption d in resultStream
            do {
                disruptions.push(d);
            };
        return disruptions;
    }

    // GET /disruption/{disruptionId} — Get disruption details
    resource function get [string disruptionId]() returns Disruption|http:NotFound|error {
        log:printInfo("Fetching disruption: " + disruptionId);
        sql:ParameterizedQuery query = `SELECT disruption_id, flight_id, disruption_type, delay_minutes, 
            reason, severity, status, detected_at, resolved_at 
            FROM disruptions WHERE disruption_id = ${disruptionId}`;
        Disruption|sql:Error result = dbClient->queryRow(query);
        if result is sql:NoRowsError {
            return http:NOT_FOUND;
        }
        return result;
    }

    // =====================================================================
    // REASONING APIs — Decision/evaluation logic (future: replaceable by LLM)
    // =====================================================================

    // GET /disruption/flights/{id}/assess — Assess disruption severity and recommend actions
    resource function get flights/[string id]/assess() returns json|http:NotFound|error {
        log:printInfo("Assessing disruption for flight: " + id);

        // Get flight info
        sql:ParameterizedQuery flightQuery = `SELECT flight_id, airline, flight_number, origin, destination,
            scheduled_departure, scheduled_arrival, actual_departure, actual_arrival,
            aircraft_type, gate, status, passenger_count,
            seats_first, seats_business, seats_premium_economy, seats_economy,
            required_captains, required_first_officers, required_cabin_crew_leads, required_cabin_crew
            FROM flights WHERE flight_id = ${id}`;
        Flight|sql:Error flightResult = dbClient->queryRow(flightQuery);
        if flightResult is sql:NoRowsError {
            return http:NOT_FOUND;
        }
        Flight flight = check flightResult;

        // Get seat availability
        sql:ParameterizedQuery seatQuery = `SELECT id, flight_id, seat_class, total_seats, booked_seats 
            FROM seat_inventory WHERE flight_id = ${id}`;
        stream<SeatInventory, sql:Error?> seatStream = dbClient->query(seatQuery);
        int totalAvailable = 0;
        check from SeatInventory si in seatStream
            do {
                totalAvailable += (si.total_seats - si.booked_seats);
            };

        // Find alternative flights (same origin-dest, status = SCHEDULED or AVAILABLE)
        sql:ParameterizedQuery altQuery = `SELECT COUNT(*) as alt_count FROM flights 
            WHERE origin = ${flight.origin} AND destination = ${flight.destination} 
            AND flight_id != ${id} AND status IN ('SCHEDULED', 'AVAILABLE')`;
        record {|int alt_count;|}|sql:Error altResult = dbClient->queryRow(altQuery);
        int alternativeCount = 0;
        if altResult is record {|int alt_count;|} {
            alternativeCount = altResult.alt_count;
        }

        // Get crew requirements
        sql:ParameterizedQuery crewQuery = `SELECT id, flight_id, role, required_count, assigned_count 
            FROM flight_crew_requirements WHERE flight_id = ${id}`;
        stream<FlightCrewRequirement, sql:Error?> crewStream = dbClient->query(crewQuery);
        boolean crewFullyStaffed = true;
        check from FlightCrewRequirement r in crewStream
            do {
                if r.assigned_count < r.required_count {
                    crewFullyStaffed = false;
                }
            };

        // Build assessment
        string[] recommendations = [];
        string riskLevel = "LOW";

        if flight.status == "CANCELLED" {
            riskLevel = "CRITICAL";
            if alternativeCount > 0 {
                recommendations.push("Rebook passengers on alternative flights");
            } else {
                recommendations.push("No alternative flights — compensate all passengers");
            }
        } else if flight.status == "DELAYED" {
            if totalAvailable < flight.passenger_count && alternativeCount == 0 {
                riskLevel = "HIGH";
                recommendations.push("Limited rebooking options — prepare compensation packages");
            } else if alternativeCount > 0 {
                riskLevel = "MEDIUM";
                recommendations.push("Rebook affected passengers on alternative flights");
            }
        }

        if !crewFullyStaffed {
            recommendations.push("Crew shortage detected — reassign available crew");
        }
        if totalAvailable < 20 {
            recommendations.push("Low seat availability — prioritize high-tier loyalty passengers");
        }

        return {
            "flight_id": id,
            "flight_status": flight.status,
            "risk_level": riskLevel,
            "passengers_affected": flight.passenger_count,
            "seats_available_on_flight": totalAvailable,
            "alternative_flights_count": alternativeCount,
            "crew_fully_staffed": crewFullyStaffed,
            "recommendations": recommendations
        };
    }

    // =====================================================================
    // ACTION APIs — State-changing operations (future: MCP tools for LLM)
    // =====================================================================

    // POST /disruption/flights — Register a new flight (with seat inventory + crew requirements)
    resource function post flights(@http:Payload FlightInput flight) returns Flight|error {
        log:printInfo("Registering new flight: " + flight.flight_number);
        string flightId = flight.flight_id ?: "FL" + uuid:createType1AsString().substring(0, 6);
        string flightStatus = flight.status ?: "UNSCHEDULED";
        int sFirst = flight.seats_first ?: 0;
        int sBusiness = flight.seats_business ?: 0;
        int sPremEco = flight.seats_premium_economy ?: 0;
        int sEconomy = flight.seats_economy ?: 0;
        int rCaptains = flight.required_captains ?: 1;
        int rFirstOfficers = flight.required_first_officers ?: 1;
        int rCCLeads = flight.required_cabin_crew_leads ?: 1;
        int rCC = flight.required_cabin_crew ?: 2;

        sql:ParameterizedQuery query = `INSERT INTO flights 
            (flight_id, airline, flight_number, origin, destination, scheduled_departure, 
             scheduled_arrival, aircraft_type, gate, status, passenger_count,
             seats_first, seats_business, seats_premium_economy, seats_economy,
             required_captains, required_first_officers, required_cabin_crew_leads, required_cabin_crew)
            VALUES (${flightId}, ${flight.airline}, ${flight.flight_number}, ${flight.origin}, 
                    ${flight.destination}, ${flight.scheduled_departure}, ${flight.scheduled_arrival},
                    ${flight.aircraft_type}, ${flight.gate}, ${flightStatus}, ${flight.passenger_count ?: 0},
                    ${sFirst}, ${sBusiness}, ${sPremEco}, ${sEconomy},
                    ${rCaptains}, ${rFirstOfficers}, ${rCCLeads}, ${rCC})`;
        _ = check dbClient->execute(query);

        // Create seat inventory entries
        if sFirst > 0 {
            _ = check dbClient->execute(`INSERT INTO seat_inventory (flight_id, seat_class, total_seats, booked_seats) VALUES (${flightId}, 'FIRST', ${sFirst}, 0)`);
        }
        if sBusiness > 0 {
            _ = check dbClient->execute(`INSERT INTO seat_inventory (flight_id, seat_class, total_seats, booked_seats) VALUES (${flightId}, 'BUSINESS', ${sBusiness}, 0)`);
        }
        if sPremEco > 0 {
            _ = check dbClient->execute(`INSERT INTO seat_inventory (flight_id, seat_class, total_seats, booked_seats) VALUES (${flightId}, 'PREMIUM_ECONOMY', ${sPremEco}, 0)`);
        }
        if sEconomy > 0 {
            _ = check dbClient->execute(`INSERT INTO seat_inventory (flight_id, seat_class, total_seats, booked_seats) VALUES (${flightId}, 'ECONOMY', ${sEconomy}, 0)`);
        }

        // Create crew requirement entries
        _ = check dbClient->execute(`INSERT INTO flight_crew_requirements (flight_id, role, required_count, assigned_count) VALUES (${flightId}, 'CAPTAIN', ${rCaptains}, 0)`);
        _ = check dbClient->execute(`INSERT INTO flight_crew_requirements (flight_id, role, required_count, assigned_count) VALUES (${flightId}, 'FIRST_OFFICER', ${rFirstOfficers}, 0)`);
        _ = check dbClient->execute(`INSERT INTO flight_crew_requirements (flight_id, role, required_count, assigned_count) VALUES (${flightId}, 'CABIN_CREW_LEAD', ${rCCLeads}, 0)`);
        _ = check dbClient->execute(`INSERT INTO flight_crew_requirements (flight_id, role, required_count, assigned_count) VALUES (${flightId}, 'CABIN_CREW', ${rCC}, 0)`);

        log:printInfo(string `Flight ${flightId} created with seat inventory and crew requirements`);

        sql:ParameterizedQuery selectQuery = `SELECT flight_id, airline, flight_number, origin, destination,
            scheduled_departure, scheduled_arrival, actual_departure, actual_arrival,
            aircraft_type, gate, status, passenger_count,
            seats_first, seats_business, seats_premium_economy, seats_economy,
            required_captains, required_first_officers, required_cabin_crew_leads, required_cabin_crew
            FROM flights WHERE flight_id = ${flightId}`;
        return check dbClient->queryRow(selectQuery);
    }

    // PUT /disruption/flights/{id}/status — Change flight status (UNSCHEDULED → AVAILABLE → SCHEDULED etc.)
    resource function put flights/[string id]/status(@http:Payload StatusChangeRequest req) returns Flight|http:NotFound|error {
        log:printInfo(string `Changing flight ${id} status to ${req.new_status}`);

        sql:ParameterizedQuery updateQuery;
        if req.gate is string {
            updateQuery = `UPDATE flights SET status = ${req.new_status}, gate = ${req.gate} WHERE flight_id = ${id}`;
        } else {
            updateQuery = `UPDATE flights SET status = ${req.new_status} WHERE flight_id = ${id}`;
        }
        sql:ExecutionResult execResult = check dbClient->execute(updateQuery);
        if execResult.affectedRowCount == 0 {
            return http:NOT_FOUND;
        }

        sql:ParameterizedQuery selectQuery = `SELECT flight_id, airline, flight_number, origin, destination,
            scheduled_departure, scheduled_arrival, actual_departure, actual_arrival,
            aircraft_type, gate, status, passenger_count,
            seats_first, seats_business, seats_premium_economy, seats_economy,
            required_captains, required_first_officers, required_cabin_crew_leads, required_cabin_crew
            FROM flights WHERE flight_id = ${id}`;
        Flight result = check dbClient->queryRow(selectQuery);
        return result;
    }

    // PUT /disruption/flights/{id}/delay — Report a delay (triggers disruption)
    resource function put flights/[string id]/delay(@http:Payload DelayReport delayReport) returns Disruption|error {
        log:printInfo(string `Reporting delay for flight ${id}: ${delayReport.delayMinutes} minutes`);

        // Update flight status
        sql:ParameterizedQuery updateQuery = `UPDATE flights SET status = 'DELAYED' WHERE flight_id = ${id}`;
        _ = check dbClient->execute(updateQuery);

        // Determine severity based on delay duration
        string severity = "LOW";
        if delayReport.delayMinutes >= 180 {
            severity = "CRITICAL";
        } else if delayReport.delayMinutes >= 120 {
            severity = "HIGH";
        } else if delayReport.delayMinutes >= 60 {
            severity = "MEDIUM";
        }

        // Create disruption record
        string disruptionId = uuid:createType1AsString();
        time:Utc now = time:utcNow();
        time:Civil civil = time:utcToCivil(now);
        string detectedAt = string `${civil.year}-${civil.month < 10 ? "0" : ""}${civil.month}-${civil.day < 10 ? "0" : ""}${civil.day} ${civil.hour < 10 ? "0" : ""}${civil.hour}:${civil.minute < 10 ? "0" : ""}${civil.minute}:${<int>civil.second < 10 ? "0" : ""}${<int>civil.second}`;

        sql:ParameterizedQuery insertQuery = `INSERT INTO disruptions 
            (disruption_id, flight_id, disruption_type, delay_minutes, reason, severity, status, detected_at)
            VALUES (${disruptionId}, ${id}, 'DELAY', ${delayReport.delayMinutes}, ${delayReport.reason}, 
                    ${severity}, 'DETECTED', ${detectedAt})`;
        _ = check dbClient->execute(insertQuery);

        log:printInfo(string `Disruption detected: ${disruptionId} | Severity: ${severity}`);

        sql:ParameterizedQuery selectQuery = `SELECT disruption_id, flight_id, disruption_type, delay_minutes, 
            reason, severity, status, detected_at, resolved_at FROM disruptions WHERE disruption_id = ${disruptionId}`;
        return check dbClient->queryRow(selectQuery);
    }

    // PUT /disruption/{disruptionId}/resolve — Mark disruption as resolved
    resource function put [string disruptionId]/resolve() returns json|error {
        log:printInfo("Resolving disruption: " + disruptionId);
        time:Utc now = time:utcNow();
        time:Civil civil = time:utcToCivil(now);
        string resolvedAt = string `${civil.year}-${civil.month < 10 ? "0" : ""}${civil.month}-${civil.day < 10 ? "0" : ""}${civil.day} ${civil.hour < 10 ? "0" : ""}${civil.hour}:${civil.minute < 10 ? "0" : ""}${civil.minute}:${<int>civil.second < 10 ? "0" : ""}${<int>civil.second}`;
        sql:ParameterizedQuery query = `UPDATE disruptions 
            SET status = 'RESOLVED', resolved_at = ${resolvedAt} 
            WHERE disruption_id = ${disruptionId}`;
        _ = check dbClient->execute(query);
        return {"status": "resolved", "disruption_id": disruptionId, "resolved_at": resolvedAt};
    }
}
