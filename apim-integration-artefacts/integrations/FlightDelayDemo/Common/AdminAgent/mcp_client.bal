// MCP (Model Context Protocol) Client — Tool Discovery & Execution
// Connects to an MCP server (optionally via APIM MCP Gateway) to dynamically
// discover available tools at startup, then proxies tool calls at runtime.
//
// Security flow:
//   Agent → APIM MCP Gateway (OBO Bearer token or ApiKey fallback) → MCP Server (backend)
//   Agent identity validated by WSO2 IS via On-Behalf-Of delegated identity flow
//   At startup (tool discovery): uses agent token (client_credentials)
//   At runtime (tool calls): uses per-request OBO Bearer token (delegated user identity)

import ballerina/ai;
import ballerina/http;
import ballerina/log;

// ── MCP Client State ───────────────────────────────────────────────────────
// When MCP is enabled, tools are discovered dynamically from the MCP server
boolean mcpEnabled = false;
ai:ChatCompletionFunctions[] mcpToolFunctions = [];
http:Client? mcpClientRef = ();
string[] mcpToolNames = [];

// MCP auth headers — base headers populated from mcpApiKey config at init time
map<string|string[]> mcpAuthHeaders = {};

// Per-request OBO Bearer token for MCP tool calls via APIM
// Set before each tool execution from the user's delegated OBO token.
string? mcpOboToken = ();

// ── System prompt (used by agent loop in admin_agent.bal) ──────────────────────
const string MCP_SYSTEM_PROMPT = string `You are an AI assistant for an Autonomous Disruption Recovery (ADR) system for airlines.
You help operations staff manage flight disruptions through natural language.

You have access to a comprehensive set of tools discovered via MCP (Model Context Protocol) that span:
- Recovery Operations: trigger_recovery, get_recovery_plan, list_recovery_plans
- Disruption Detection: get_all_flights, get_flight_details, get_flight_seats, assess_disruption, get_active_delays, report_flight_delay
- Crew Management: get_crew_assignments, get_available_crew, check_crew_compliance, reassign_crew
- Passenger Management: get_passenger_bookings, get_alternative_flights, rebook_passenger, notify_passenger, process_compensation
- Logistics: get_available_gates, assign_gate, redirect_catering, notify_ground_handling

Use the appropriate tool for each request. For complex disruptions, use trigger_recovery for automated end-to-end recovery.
For specific queries, use the granular tools (e.g., get_flight_details for flight info, get_active_delays for delay status).

Be concise, professional, and action-oriented. Always confirm what action you're taking.`;

// ── MCP Client Initialization ──────────────────────────────────────────────

// Set the per-request OBO Bearer token for MCP tool calls.
// Call this before tool execution to pass the user's delegated identity to APIM.
function setMcpOboToken(string? token) {
    mcpOboToken = token;
}

// Build auth headers for a request — prefer OBO Bearer token, then ApiKey fallback.
// Always includes MCP Streamable HTTP transport headers.
function getMcpRequestHeaders() returns map<string|string[]> {
    // MCP Streamable HTTP transport requires both application/json and text/event-stream
    map<string|string[]> headers = {
        "Accept": "application/json, text/event-stream",
        "Content-Type": "application/json"
    };
    string? oboToken = mcpOboToken;
    if oboToken is string && oboToken.length() > 0 {
        headers["Authorization"] = "Bearer " + oboToken;
        return headers;
    }
    // Merge static auth headers (Internal-Key etc.)
    foreach [string, string|string[]] [k, v] in mcpAuthHeaders.entries() {
        headers[k] = v;
    }
    return headers;
}

// Initialize MCP client connection and discover tools.
// Uses agent token (via aiGatewayToken/Internal-Key) for startup discovery.
// Runtime tool calls will use OBO Bearer token set via setMcpOboToken().
function initializeMcpClient() returns error? {
    if mcpServerUrl.length() == 0 {
        return error("MCP server URL not configured");
    }

    log:printInfo(string `Connecting to MCP server at ${mcpServerUrl}...`);

    // Build auth headers for APIM MCP Gateway (Internal-Key header for publisher-generated keys)
    if mcpApiKey != "" {
        mcpAuthHeaders = {"Internal-Key": mcpApiKey};
        log:printInfo("MCP Gateway auth: API key configured (APIM MCP Gateway secured)");
    } else {
        log:printInfo("MCP Gateway auth: No API key — direct MCP server connection (unsecured)");
    }

    // Configure HTTP client for MCP server
    http:ClientConfiguration clientConfig = {
        timeout: 30
    };
    if mcpServerUrl.startsWith("https://") {
        clientConfig.secureSocket = {enable: false};
    }

    http:Client mcpCl = check new (mcpServerUrl, clientConfig);

    // Initialize MCP session
    json initPayload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {
                "name": "ADR Admin Agent",
                "version": "1.0.0"
            }
        }
    };

    json initResponse = check mcpCl->post("/", initPayload, headers = getMcpRequestHeaders());

    // List available tools
    json listToolsPayload = {
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/list",
        "params": {}
    };

    json toolsResponse = check mcpCl->post("/", listToolsPayload, headers = getMcpRequestHeaders());

    // Parse tools from response
    json|error resultField = toolsResponse.result;
    if resultField is error {
        return error("Invalid MCP response: missing result field");
    }

    json|error toolsField = resultField.tools;
    if toolsField is error || !(toolsField is json[]) {
        return error("Invalid MCP response: missing or invalid tools array");
    }

    json[] toolsList = <json[]>toolsField;

    // Convert MCP tool definitions to ai:ChatCompletionFunctions format for the LLM
    ai:ChatCompletionFunctions[] tools = [];
    string[] toolNames = [];

    foreach json toolJson in toolsList {
        string toolName = (check toolJson.name).toString();
        string toolDesc = toolJson.description is json ? (check toolJson.description).toString() : toolName;
        json inputSchema = check toolJson.inputSchema;

        tools.push({
            name: toolName,
            description: toolDesc,
            parameters: <map<json>>inputSchema
        });
        toolNames.push(toolName);
    }

    mcpEnabled = true;
    mcpToolFunctions = tools;
    mcpClientRef = mcpCl;
    mcpToolNames = toolNames;

    log:printInfo(string `MCP client initialized — discovered ${tools.length()} tools: ${", ".join(...toolNames)}`);
}

// ── MCP Tool Execution ─────────────────────────────────────────────────────

// Execute a tool via MCP server
function executeMcpTool(string name, json arguments) returns json {
    http:Client? mcpCl = mcpClientRef;
    if mcpCl is () {
        return {"error": "MCP client not initialized"};
    }

    // Build MCP tool call request
    json callToolPayload = {
        "jsonrpc": "2.0",
        "id": 3,
        "method": "tools/call",
        "params": {
            "name": name,
            "arguments": arguments
        }
    };

    // Use OBO Bearer token (delegated user identity) if available, else fallback to static auth
    map<string|string[]> requestHeaders = getMcpRequestHeaders();
    json|http:ClientError result = mcpCl->post("/", callToolPayload, headers = requestHeaders);
    if result is http:ClientError {
        log:printError(string `MCP tool ${name} failed`, result);
        return {"error": result.message()};
    }

    // Extract result from MCP response
    json|error resultField = result.result;
    if resultField is error {
        return {"error": "Invalid MCP response: missing result field"};
    }

    // Extract content from result
    json|error contentField = resultField.content;
    if contentField is error || !(contentField is json[]) {
        return resultField;
    }

    json[] contentArray = <json[]>contentField;
    if contentArray.length() == 0 {
        return {"result": ""};
    }

    // Extract text from first content item
    json firstContent = contentArray[0];
    json|error textField = firstContent.text;
    if textField is json {
        string responseText = textField.toString();
        // Try to parse as JSON, otherwise return as text
        json|error parsed = responseText.fromJsonString();
        if parsed is json {
            return parsed;
        }
        return {"result": responseText};
    }

    return resultField;
}
