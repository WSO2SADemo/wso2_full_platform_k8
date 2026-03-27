// Autonomous Disruption Recovery — Crew Service
// Manages crew assignments, duty hour compliance, and crew reassignment.
// Separated into: Data APIs | Reasoning APIs | Action APIs (for future AI/MCP integration)

import ballerina/http;
import ballerina/log;
import ballerina/sql;
import ballerina/uuid;
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

service /crew on new http:Listener(9091) {

    // =====================================================================
    // DATA APIs — Pure read operations (future: MCP tools for LLM context)
    // =====================================================================

    // GET /crew/members — List all crew members
    resource function get members() returns CrewMember[]|error {
        log:printInfo("Fetching all crew members");
        sql:ParameterizedQuery query = `SELECT crew_id, first_name, last_name, role, base_airport,
            duty_hours_today, max_duty_hours, status, phone, email, certification 
            FROM crew_members`;
        stream<CrewMember, sql:Error?> resultStream = dbClient->query(query);
        CrewMember[] members = [];
        check from CrewMember member in resultStream
            do {
                members.push(member);
            };
        return members;
    }

    // GET /crew/members/{id} — Get crew member details
    resource function get members/[string id]() returns CrewMember|http:NotFound|error {
        log:printInfo("Fetching crew member: " + id);
        sql:ParameterizedQuery query = `SELECT crew_id, first_name, last_name, role, base_airport,
            duty_hours_today, max_duty_hours, status, phone, email, certification 
            FROM crew_members WHERE crew_id = ${id}`;
        CrewMember|sql:Error result = dbClient->queryRow(query);
        if result is sql:NoRowsError {
            return http:NOT_FOUND;
        }
        return result;
    }

    // GET /crew/assignments/{flightId} — Get crew assigned to a flight
    resource function get assignments/[string flightId]() returns CrewAssignment[]|error {
        log:printInfo("Fetching crew assignments for flight: " + flightId);
        sql:ParameterizedQuery query = `SELECT assignment_id, crew_id, flight_id, role, 
            duty_start, duty_end, status 
            FROM crew_assignments WHERE flight_id = ${flightId} AND status != 'REASSIGNED'`;
        stream<CrewAssignment, sql:Error?> resultStream = dbClient->query(query);
        CrewAssignment[] assignments = [];
        check from CrewAssignment assignment in resultStream
            do {
                assignments.push(assignment);
            };
        return assignments;
    }

    // GET /crew/requirements/{flightId} — Get crew requirements for a flight
    resource function get requirements/[string flightId]() returns CrewRequirementSummary|http:NotFound|error {
        log:printInfo("Fetching crew requirements for flight: " + flightId);
        sql:ParameterizedQuery query = `SELECT id, flight_id, role, required_count, assigned_count 
            FROM flight_crew_requirements WHERE flight_id = ${flightId}`;
        stream<FlightCrewRequirement, sql:Error?> resultStream = dbClient->query(query);
        FlightCrewRequirement[] reqs = [];
        int totalReq = 0;
        int totalAssigned = 0;
        check from FlightCrewRequirement r in resultStream
            do {
                reqs.push(r);
                totalReq += r.required_count;
                totalAssigned += r.assigned_count;
            };
        if reqs.length() == 0 {
            return http:NOT_FOUND;
        }
        return {
            flight_id: flightId,
            requirements: reqs,
            fully_staffed: totalAssigned >= totalReq,
            total_required: totalReq,
            total_assigned: totalAssigned,
            gaps: totalReq - totalAssigned
        };
    }

    // GET /crew/available — Find available crew members (optionally by airport & role)
    resource function get available(string? airport, string? role) returns CrewMember[]|error {
        log:printInfo("Finding available crew members");

        sql:ParameterizedQuery query;
        if airport is string && role is string {
            query = `SELECT crew_id, first_name, last_name, role, base_airport,
                duty_hours_today, max_duty_hours, status, phone, email, certification 
                FROM crew_members WHERE status = 'AVAILABLE' AND base_airport = ${airport} AND role = ${role}`;
        } else if airport is string {
            query = `SELECT crew_id, first_name, last_name, role, base_airport,
                duty_hours_today, max_duty_hours, status, phone, email, certification 
                FROM crew_members WHERE status = 'AVAILABLE' AND base_airport = ${airport}`;
        } else if role is string {
            query = `SELECT crew_id, first_name, last_name, role, base_airport,
                duty_hours_today, max_duty_hours, status, phone, email, certification 
                FROM crew_members WHERE status = 'AVAILABLE' AND role = ${role}`;
        } else {
            query = `SELECT crew_id, first_name, last_name, role, base_airport,
                duty_hours_today, max_duty_hours, status, phone, email, certification 
                FROM crew_members WHERE status = 'AVAILABLE'`;
        }

        stream<CrewMember, sql:Error?> resultStream = dbClient->query(query);
        CrewMember[] members = [];
        check from CrewMember member in resultStream
            do {
                members.push(member);
            };
        return members;
    }

    // =====================================================================
    // REASONING APIs — Decision/evaluation logic (future: replaceable by LLM)
    // =====================================================================

    // POST /crew/check-compliance — Check duty hour compliance
    resource function post check\-compliance(@http:Payload ComplianceCheckRequest request) returns ComplianceCheckResult|error {
        log:printInfo(string `Checking compliance for crew ${request.crew_id} on flight ${request.flight_id}`);

        sql:ParameterizedQuery query = `SELECT crew_id, first_name, last_name, role, base_airport,
            duty_hours_today, max_duty_hours, status, phone, email, certification 
            FROM crew_members WHERE crew_id = ${request.crew_id}`;
        CrewMember member = check dbClient->queryRow(query);

        decimal projectedTotal = member.duty_hours_today + request.additional_hours;
        boolean compliant = projectedTotal <= member.max_duty_hours;

        string message;
        if compliant {
            message = string `COMPLIANT: ${member.first_name} ${member.last_name} can operate flight ${request.flight_id}. ` +
                string `Projected duty hours: ${projectedTotal}/${member.max_duty_hours}`;
        } else {
            message = string `NON-COMPLIANT: ${member.first_name} ${member.last_name} CANNOT operate flight ${request.flight_id}. ` +
                string `Would exceed legal duty limit: ${projectedTotal}/${member.max_duty_hours} hours. ` +
                string `Crew member must rest. Find alternative crew.`;
        }

        log:printInfo(message);

        return {
            crew_id: member.crew_id,
            crew_name: member.first_name + " " + member.last_name,
            flight_id: request.flight_id,
            compliant: compliant,
            current_duty_hours: member.duty_hours_today,
            max_duty_hours: member.max_duty_hours,
            requested_additional_hours: request.additional_hours,
            projected_total: projectedTotal,
            message: message
        };
    }

    // GET /crew/evaluate/{flightId} — Evaluate crew fitness for a flight (finds best candidates)
    resource function get evaluate/[string flightId](string? airport) returns CrewFitnessEvaluation|error {
        log:printInfo(string `Evaluating crew fitness for flight ${flightId}`);

        string baseAirport = airport ?: "LHR";

        // Get requirements
        sql:ParameterizedQuery reqQuery = `SELECT id, flight_id, role, required_count, assigned_count 
            FROM flight_crew_requirements WHERE flight_id = ${flightId}`;
        stream<FlightCrewRequirement, sql:Error?> reqStream = dbClient->query(reqQuery);
        FlightCrewRequirement[] reqs = [];
        check from FlightCrewRequirement r in reqStream
            do {
                reqs.push(r);
            };

        // Find all available crew at the airport
        sql:ParameterizedQuery crewQuery = `SELECT crew_id, first_name, last_name, role, base_airport,
            duty_hours_today, max_duty_hours, status, phone, email, certification 
            FROM crew_members WHERE status = 'AVAILABLE' AND base_airport = ${baseAirport}`;
        stream<CrewMember, sql:Error?> crewStream = dbClient->query(crewQuery);
        CrewMember[] availCrew = [];
        check from CrewMember m in crewStream
            do {
                availCrew.push(m);
            };

        CrewCandidate[] candidates = [];
        string[] gaps = [];

        // For each unfulfilled requirement, find candidates
        foreach FlightCrewRequirement req in reqs {
            int neededMore = req.required_count - req.assigned_count;
            if neededMore <= 0 {
                continue;
            }

            int found = 0;
            foreach CrewMember m in availCrew {
                if m.role == req.role {
                    decimal hoursRemaining = m.max_duty_hours - m.duty_hours_today;
                    boolean compliant = hoursRemaining >= 4.0d; // Minimum 4 hours for a flight
                    string fitness = "LOW";
                    if hoursRemaining >= 10.0d {
                        fitness = "HIGH";
                    } else if hoursRemaining >= 6.0d {
                        fitness = "MEDIUM";
                    }
                    candidates.push({
                        crew_id: m.crew_id,
                        name: m.first_name + " " + m.last_name,
                        role: m.role,
                        duty_hours_remaining: hoursRemaining,
                        compliant: compliant,
                        fitness_score: fitness
                    });
                    if compliant {
                        found += 1;
                    }
                }
            }

            if found < neededMore {
                gaps.push(string `Need ${neededMore} ${req.role}(s) but only ${found} compliant available`);
            }
        }

        string recommendation;
        if gaps.length() == 0 {
            recommendation = "Sufficient crew available for all roles. Ready for assignment.";
        } else {
            recommendation = string `Crew gaps detected: ${gaps.length()} role(s) need additional crew. Consider standby crew or schedule changes.`;
        }

        return {
            flight_id: flightId,
            candidates: candidates,
            gaps: gaps,
            recommendation: recommendation
        };
    }

    // =====================================================================
    // ACTION APIs — State-changing operations (future: MCP tools for LLM)
    // =====================================================================

    // POST /crew/members — Register a crew member
    resource function post members(@http:Payload CrewMemberInput member) returns CrewMember|error {
        log:printInfo("Registering crew member: " + member.first_name + " " + member.last_name);
        string crewId = member.crew_id ?: "CRW" + uuid:createType1AsString().substring(0, 6);

        sql:ParameterizedQuery query = `INSERT INTO crew_members 
            (crew_id, first_name, last_name, role, base_airport, duty_hours_today, max_duty_hours, 
             status, phone, email, certification)
            VALUES (${crewId}, ${member.first_name}, ${member.last_name}, ${member.role}, 
                    ${member.base_airport}, ${member.duty_hours_today ?: 0.0}, 
                    ${member.max_duty_hours ?: 14.0}, ${member.status ?: "AVAILABLE"},
                    ${member.phone}, ${member.email}, ${member.certification})`;
        _ = check dbClient->execute(query);

        sql:ParameterizedQuery selectQuery = `SELECT crew_id, first_name, last_name, role, base_airport,
            duty_hours_today, max_duty_hours, status, phone, email, certification 
            FROM crew_members WHERE crew_id = ${crewId}`;
        return check dbClient->queryRow(selectQuery);
    }

    // POST /crew/assign — Assign a crew member to a flight (updates requirements tracker)
    resource function post assign(@http:Payload AssignCrewRequest request) returns AssignCrewResult|error {
        log:printInfo(string `Assigning crew ${request.crew_id} to flight ${request.flight_id} as ${request.role}`);

        // Get crew member
        sql:ParameterizedQuery crewQuery = `SELECT crew_id, first_name, last_name, role, base_airport,
            duty_hours_today, max_duty_hours, status, phone, email, certification 
            FROM crew_members WHERE crew_id = ${request.crew_id}`;
        CrewMember member = check dbClient->queryRow(crewQuery);

        // Create assignment
        string assignmentId = uuid:createType1AsString();
        sql:ParameterizedQuery insertQuery = `INSERT INTO crew_assignments 
            (assignment_id, crew_id, flight_id, role, duty_start, duty_end, status)
            VALUES (${assignmentId}, ${request.crew_id}, ${request.flight_id}, ${request.role}, 
                    ${request.duty_start}, ${request.duty_end}, 'ASSIGNED')`;
        _ = check dbClient->execute(insertQuery);

        // Update crew member status to ON_DUTY
        _ = check dbClient->execute(`UPDATE crew_members SET status = 'ON_DUTY' WHERE crew_id = ${request.crew_id}`);

        // Update flight_crew_requirements assigned_count
        _ = check dbClient->execute(`UPDATE flight_crew_requirements SET assigned_count = assigned_count + 1 
            WHERE flight_id = ${request.flight_id} AND role = ${request.role}`);

        string crewName = member.first_name + " " + member.last_name;
        return {
            assignment_id: assignmentId,
            crew_id: request.crew_id,
            crew_name: crewName,
            flight_id: request.flight_id,
            role: request.role,
            status: "ASSIGNED",
            message: string `${crewName} assigned to flight ${request.flight_id} as ${request.role}`
        };
    }

    // POST /crew/reassign — Reassign crew to a different flight
    resource function post reassign(@http:Payload ReassignRequest request) returns ReassignResult|error {
        log:printInfo(string `Reassigning crew ${request.crew_id} from ${request.from_flight_id} to ${request.to_flight_id}`);

        // Get crew member info
        sql:ParameterizedQuery crewQuery = `SELECT crew_id, first_name, last_name, role, base_airport,
            duty_hours_today, max_duty_hours, status, phone, email, certification 
            FROM crew_members WHERE crew_id = ${request.crew_id}`;
        CrewMember member = check dbClient->queryRow(crewQuery);

        // Mark old assignment as REASSIGNED
        sql:ParameterizedQuery updateOldQuery = `UPDATE crew_assignments SET status = 'REASSIGNED' 
            WHERE crew_id = ${request.crew_id} AND flight_id = ${request.from_flight_id} AND status = 'ASSIGNED'`;
        _ = check dbClient->execute(updateOldQuery);

        // Update old flight crew requirements (decrease assigned_count)
        _ = check dbClient->execute(`UPDATE flight_crew_requirements SET assigned_count = GREATEST(assigned_count - 1, 0) 
            WHERE flight_id = ${request.from_flight_id} AND role = ${request.role}`);

        // Create new assignment
        string newAssignmentId = uuid:createType1AsString();
        sql:ParameterizedQuery insertQuery = `INSERT INTO crew_assignments 
            (assignment_id, crew_id, flight_id, role, status)
            VALUES (${newAssignmentId}, ${request.crew_id}, ${request.to_flight_id}, ${request.role}, 'ASSIGNED')`;
        _ = check dbClient->execute(insertQuery);

        // Update new flight crew requirements (increase assigned_count)
        _ = check dbClient->execute(`UPDATE flight_crew_requirements SET assigned_count = assigned_count + 1 
            WHERE flight_id = ${request.to_flight_id} AND role = ${request.role}`);

        string message = string `Crew member ${member.first_name} ${member.last_name} reassigned from flight ` +
            string `${request.from_flight_id} to ${request.to_flight_id} as ${request.role}`;
        log:printInfo(message);

        return {
            crew_id: member.crew_id,
            crew_name: member.first_name + " " + member.last_name,
            from_flight_id: request.from_flight_id,
            to_flight_id: request.to_flight_id,
            new_assignment_id: newAssignmentId,
            status: "REASSIGNED",
            message: message
        };
    }
}
