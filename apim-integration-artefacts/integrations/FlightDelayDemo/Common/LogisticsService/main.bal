// Autonomous Disruption Recovery — Logistics Service
// Manages gate assignments, catering redirection, and ground handling coordination.
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

service /logistics on new http:Listener(9093) {

    // ========================================================================
    // GET /logistics/gates/available/{airport} — Find available gates
    // ========================================================================
    resource function get gates/available/[string airport](string? gate_type) returns Gate[]|error {
        log:printInfo("Finding available gates at: " + airport);

        sql:ParameterizedQuery query;
        if gate_type is string {
            query = `SELECT gate_id, airport, terminal, gate_type, status, assigned_flight_id 
                FROM gates WHERE airport = ${airport} AND status = 'AVAILABLE' AND gate_type = ${gate_type}`;
        } else {
            query = `SELECT gate_id, airport, terminal, gate_type, status, assigned_flight_id 
                FROM gates WHERE airport = ${airport} AND status = 'AVAILABLE'`;
        }

        stream<Gate, sql:Error?> resultStream = dbClient->query(query);
        Gate[] gates = [];
        check from Gate gate in resultStream
            do {
                gates.push(gate);
            };
        return gates;
    }

    // ========================================================================
    // POST /logistics/gates/assign — Assign a gate to a flight
    // ========================================================================
    resource function post gates/assign(@http:Payload GateAssignRequest request) returns GateAssignResult|error {
        log:printInfo(string `Assigning gate ${request.gate_id} to flight ${request.flight_id}`);

        // Release old gate if flight had one
        sql:ParameterizedQuery releaseQuery = `UPDATE gates SET status = 'AVAILABLE', assigned_flight_id = NULL 
            WHERE assigned_flight_id = ${request.flight_id}`;
        _ = check dbClient->execute(releaseQuery);

        // Assign new gate
        sql:ParameterizedQuery assignQuery = `UPDATE gates SET status = 'OCCUPIED', assigned_flight_id = ${request.flight_id} 
            WHERE gate_id = ${request.gate_id} AND status = 'AVAILABLE'`;
        sql:ExecutionResult result = check dbClient->execute(assignQuery);

        if result.affectedRowCount == 0 {
            return error("Gate " + request.gate_id + " is not available for assignment");
        }

        // Update flight gate
        sql:ParameterizedQuery updateFlightQuery = `UPDATE flights SET gate = ${request.gate_id} WHERE flight_id = ${request.flight_id}`;
        _ = check dbClient->execute(updateFlightQuery);

        // Get gate details
        sql:ParameterizedQuery gateQuery = `SELECT gate_id, airport, terminal, gate_type, status, assigned_flight_id 
            FROM gates WHERE gate_id = ${request.gate_id}`;
        Gate gate = check dbClient->queryRow(gateQuery);

        string message = string `Gate ${request.gate_id} (Terminal ${gate.terminal}, ${gate.gate_type}) assigned to flight ${request.flight_id}`;
        log:printInfo(message);

        return {
            gate_id: gate.gate_id,
            flight_id: request.flight_id,
            terminal: gate.terminal,
            gate_type: gate.gate_type,
            status: "ASSIGNED",
            message: message
        };
    }

    // ========================================================================
    // POST /logistics/catering/redirect — Redirect catering to new gate/flight
    // ========================================================================
    resource function post catering/redirect(@http:Payload CateringRedirectRequest request) returns CateringRedirectResult|error {
        log:printInfo(string `Redirecting catering for flight ${request.flight_id} to gate ${request.new_gate}`);

        string redirectNote = " | Redirected to gate " + request.new_gate;
        sql:ParameterizedQuery updateQuery = `UPDATE catering_orders 
            SET delivery_gate = ${request.new_gate}, status = 'REDIRECTED', 
                notes = CONCAT(IFNULL(notes, ''), ${redirectNote})
            WHERE flight_id = ${request.flight_id} AND status IN ('PREPARING', 'READY')`;
        sql:ExecutionResult result = check dbClient->execute(updateQuery);

        int ordersRedirected = <int>result.affectedRowCount;
        string message = string `${ordersRedirected} catering order(s) for flight ${request.flight_id} redirected to gate ${request.new_gate}`;
        log:printInfo(message);

        return {
            flight_id: request.flight_id,
            new_gate: request.new_gate,
            orders_redirected: ordersRedirected,
            status: "REDIRECTED",
            message: message
        };
    }

    // ========================================================================
    // POST /logistics/ground-handling/notify — Create ground handling task
    // ========================================================================
    resource function post ground\-handling/notify(@http:Payload GroundHandlingNotifyRequest request) returns GroundHandlingNotifyResult|error {
        log:printInfo(string `Creating ground handling task for flight ${request.flight_id}: ${request.task_type}`);

        string taskId = uuid:createType1AsString();
        sql:ParameterizedQuery insertQuery = `INSERT INTO ground_handling_tasks 
            (task_id, flight_id, task_type, assigned_team, status, gate, notes)
            VALUES (${taskId}, ${request.flight_id}, ${request.task_type}, ${request.assigned_team}, 
                    'PENDING', ${request.gate}, ${request.notes})`;
        _ = check dbClient->execute(insertQuery);

        string message = string `Ground handling task created: ${request.task_type} for flight ${request.flight_id}` +
            (request.assigned_team is string ? string ` assigned to ${request.assigned_team ?: ""}` : " (unassigned)");
        log:printInfo(message);

        return {
            task_id: taskId,
            flight_id: request.flight_id,
            task_type: request.task_type,
            assigned_team: request.assigned_team,
            status: "PENDING",
            message: message
        };
    }

    // ========================================================================
    // GET /logistics/resources/{airport} — Get airport resource overview
    // ========================================================================
    resource function get resources/[string airport]() returns AirportResources|error {
        log:printInfo("Fetching resource overview for airport: " + airport);

        // Gates summary
        sql:ParameterizedQuery totalGatesQuery = `SELECT COUNT(*) as count FROM gates WHERE airport = ${airport}`;
        record {|int count;|} totalResult = check dbClient->queryRow(totalGatesQuery);

        sql:ParameterizedQuery availableGatesQuery = `SELECT COUNT(*) as count FROM gates WHERE airport = ${airport} AND status = 'AVAILABLE'`;
        record {|int count;|} availableResult = check dbClient->queryRow(availableGatesQuery);

        sql:ParameterizedQuery occupiedGatesQuery = `SELECT COUNT(*) as count FROM gates WHERE airport = ${airport} AND status = 'OCCUPIED'`;
        record {|int count;|} occupiedResult = check dbClient->queryRow(occupiedGatesQuery);

        sql:ParameterizedQuery maintenanceGatesQuery = `SELECT COUNT(*) as count FROM gates WHERE airport = ${airport} AND status = 'MAINTENANCE'`;
        record {|int count;|} maintenanceResult = check dbClient->queryRow(maintenanceGatesQuery);

        // Active catering orders
        sql:ParameterizedQuery cateringQuery = `SELECT COUNT(*) as count FROM catering_orders co 
            JOIN flights f ON co.flight_id = f.flight_id 
            WHERE f.origin = ${airport} AND co.status IN ('PREPARING', 'READY')`;
        record {|int count;|} cateringResult = check dbClient->queryRow(cateringQuery);

        // Pending ground tasks
        sql:ParameterizedQuery groundQuery = `SELECT COUNT(*) as count FROM ground_handling_tasks ght 
            JOIN flights f ON ght.flight_id = f.flight_id 
            WHERE f.origin = ${airport} AND ght.status IN ('PENDING', 'IN_PROGRESS')`;
        record {|int count;|} groundResult = check dbClient->queryRow(groundQuery);

        return {
            airport: airport,
            total_gates: totalResult.count,
            available_gates: availableResult.count,
            occupied_gates: occupiedResult.count,
            maintenance_gates: maintenanceResult.count,
            active_catering_orders: cateringResult.count,
            pending_ground_tasks: groundResult.count
        };
    }

    // ========================================================================
    // GET /logistics/catering/{flightId} — Get catering orders for a flight
    // ========================================================================
    resource function get catering/[string flightId]() returns CateringOrder[]|error {
        log:printInfo("Fetching catering orders for flight: " + flightId);
        sql:ParameterizedQuery query = `SELECT order_id, flight_id, meal_count, special_meals, 
            status, delivery_gate, notes FROM catering_orders WHERE flight_id = ${flightId}`;
        stream<CateringOrder, sql:Error?> resultStream = dbClient->query(query);
        CateringOrder[] orders = [];
        check from CateringOrder cateringOrder in resultStream
            do {
                orders.push(cateringOrder);
            };
        return orders;
    }

    // ========================================================================
    // GET /logistics/ground-tasks/{flightId} — Get ground handling tasks
    // ========================================================================
    resource function get ground\-tasks/[string flightId]() returns GroundHandlingTask[]|error {
        log:printInfo("Fetching ground handling tasks for flight: " + flightId);
        sql:ParameterizedQuery query = `SELECT task_id, flight_id, task_type, assigned_team, 
            status, gate, notes FROM ground_handling_tasks WHERE flight_id = ${flightId}`;
        stream<GroundHandlingTask, sql:Error?> resultStream = dbClient->query(query);
        GroundHandlingTask[] tasks = [];
        check from GroundHandlingTask task in resultStream
            do {
                tasks.push(task);
            };
        return tasks;
    }
}
