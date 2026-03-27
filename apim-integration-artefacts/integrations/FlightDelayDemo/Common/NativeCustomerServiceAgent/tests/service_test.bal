// NativeCustomerServiceAgent — Integration Tests
// Tests the service endpoints: health check, chat (with/without auth), and error handling.
//
// Run with: bal test
// These tests start the service and validate HTTP endpoints.

import ballerina/http;
import ballerina/test;

// Test client pointing to the NativeCustomerServiceAgent service
final http:Client testClient = check new (string `http://localhost:${servicePort}/cs`);

// ── Health Check Tests ─────────────────────────────────────────────────────

@test:Config {}
function testHealthEndpoint() returns error? {
    json response = check testClient->get("/health");

    // Validate response structure
    test:assertTrue(response.status is json, "Health response should have 'status' field");
    test:assertEquals(response.status, "running", "Service status should be 'running'");
    test:assertEquals(response.agent, "Native Customer Service Agent", "Agent name should match");

    // Validate mode indicates AI Agent
    string mode = (check response.mode).toString();
    test:assertTrue(mode.includes("AI Agent"), "Mode should indicate AI Agent");

    // Validate MCP tool count field exists (actual count depends on MCP server availability)
    test:assertTrue(response.mcp_tools is json, "Should have 'mcp_tools' field");
    test:assertTrue(response.agent_initialized is json, "Should have 'agent_initialized' field");
}

// ── Authentication Tests ───────────────────────────────────────────────────

@test:Config {}
function testChatWithoutAuth() returns error? {
    ChatRequest payload = {message: "Show me all flights"};

    http:Response response = check testClient->post("/chat", payload);

    // Should return 401 Unauthorized without auth header
    test:assertEquals(response.statusCode, 401, "Should return 401 without Authorization header");
}

@test:Config {}
function testChatWithInvalidAuth() returns error? {
    ChatRequest payload = {message: "Show me all flights"};

    http:Request req = new;
    req.setJsonPayload(payload.toJson());
    req.setHeader("Authorization", "Bearer invalid_token_here");
    req.setHeader("Content-Type", "application/json");

    http:Response response = check testClient->post("/chat", req);

    // Should return 403 Forbidden with invalid JWT
    // (JWT decode will fail, resulting in forbidden)
    int statusCode = response.statusCode;
    test:assertTrue(statusCode == 403 || statusCode == 401,
        string `Should return 401 or 403 with invalid JWT, got ${statusCode}`);
}

// ── Chat Endpoint Structure Tests ──────────────────────────────────────────

@test:Config {}
function testHealthResponseFields() returns error? {
    json response = check testClient->get("/health");

    // Validate all expected fields exist
    test:assertTrue(response.status is json, "Should have 'status' field");
    test:assertTrue(response.agent is json, "Should have 'agent' field");
    test:assertTrue(response.mode is json, "Should have 'mode' field");
    test:assertTrue(response.tool_discovery is json, "Should have 'tool_discovery' field");
    test:assertTrue(response.mcp_enabled is json, "Should have 'mcp_enabled' field");
    test:assertTrue(response.mcp_servers is json, "Should have 'mcp_servers' field");
    test:assertTrue(response.mcp_tools is json, "Should have 'mcp_tools' field");
    test:assertTrue(response.agent_initialized is json, "Should have 'agent_initialized' field");
    test:assertTrue(response.obo_enabled is json, "Should have 'obo_enabled' field");
    test:assertTrue(response.obo_sessions is json, "Should have 'obo_sessions' field");
}

// ── OBO Callback Tests ─────────────────────────────────────────────────────

@test:Config {}
function testCallbackWithoutParams() returns error? {
    http:Response response = check testClient->get("/callback");

    // Should return 400 when code/state are missing
    test:assertEquals(response.statusCode, 400, "Callback without params should return 400");

    string body = check response.getTextPayload();
    test:assertTrue(body.includes("Authorization Failed"), "Should indicate authorization failure");
}

@test:Config {}
function testCallbackWithInvalidState() returns error? {
    http:Response response = check testClient->get("/callback?code=test_code&state=invalid_state");

    // Should return 500 when state doesn't match any pending OBO auth
    test:assertEquals(response.statusCode, 500, "Callback with invalid state should return 500");

    string body = check response.getTextPayload();
    test:assertTrue(body.includes("Authorization Failed") || body.includes("No pending"),
        "Should indicate no pending authorization found");
}

// ── Utility Function Tests ─────────────────────────────────────────────────

@test:Config {}
function testSplitWords() {
    string[] result = splitWords("hello world, test? yes!");
    test:assertEquals(result.length(), 4, "Should split into 4 words");
    test:assertEquals(result[0], "hello");
    test:assertEquals(result[1], "world");
    test:assertEquals(result[2], "test");
    test:assertEquals(result[3], "yes");
}

@test:Config {}
function testSplitWordsEmpty() {
    string[] result = splitWords("");
    test:assertEquals(result.length(), 0, "Empty string should produce empty array");
}

@test:Config {}
function testExtractIdFromText() {
    // Should extract flight-style IDs
    string? flightId = extractIdFromText("What about flight FL001?");
    test:assertEquals(flightId, "FL001", "Should extract FL001");

    // Should extract passenger-style IDs
    string? passengerId = extractIdFromText("Look up passenger P002");
    test:assertEquals(passengerId, "P002", "Should extract P002");

    // Should extract booking-style IDs
    string? bookingId = extractIdFromText("Check booking B003 please");
    test:assertEquals(bookingId, "B003", "Should extract B003");

    // Should return nil for no ID
    string? noId = extractIdFromText("show me all flights");
    test:assertEquals(noId, (), "Should return nil when no ID present");
}

@test:Config {}
function testFormatToolResult() {
    // Test flight formatting
    json flightData = {"flight_id": "FL001", "status": "DELAYED"};
    string result = formatToolResult("getFlights", flightData);
    test:assertTrue(result.includes("Flight Status"), "Should use 'Flight Status' label for getFlights");

    // Test error formatting
    json errorData = {"error": "Tool not found"};
    string errorResult = formatToolResult("unknownTool", errorData);
    test:assertTrue(errorResult.includes("Error"), "Should include 'Error' for error results");
}

@test:Config {}
function testFormatToolResultLabels() {
    json data = {"test": true};

    test:assertTrue(formatToolResult("getActiveDisruptions", data).includes("Active Disruptions"));
    test:assertTrue(formatToolResult("getPassengerById", data).includes("Passenger Details"));
    test:assertTrue(formatToolResult("getBookingsByFlight", data).includes("Booking Information"));
    test:assertTrue(formatToolResult("getAlternativeFlights", data).includes("Alternative Flights"));
    test:assertTrue(formatToolResult("rebookPassenger", data).includes("Rebooking Result"));
    test:assertTrue(formatToolResult("processCompensation", data).includes("Compensation"));
    test:assertTrue(formatToolResult("notifyPassenger", data).includes("Notification"));
}
