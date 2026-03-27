// MCP (Model Context Protocol) Client — Multi-Server Tool Discovery & Execution
// Connects to MULTIPLE MCP servers (via APIM MCP Gateway) to dynamically
// discover available tools at startup, then routes tool calls to the correct server.
//
// Why multiple servers: APIM's generate-from-api only registers ONE source REST API
// per MCP server. To compose tools from DisruptionDetectionAPI + PassengerServiceAPI,
// we create two MCP servers and merge their tool lists here.
//
// Uses raw HTTP + JSON-RPC instead of ballerina/mcp library to support
// protocol version 2025-06-18 required by the APIM MCP Gateway.

import ballerina/ai;
import ballerina/http;
import ballerina/log;
import ballerina/time;

// ── Per-MCP-Server Connection State ────────────────────────────────────────
// Each MCP server has its own HTTP client and session.
type McpConnection record {|
    string url;
    http:Client httpClient;
    string sessionId;
    string[] toolNames;
|};

// ── Aggregated MCP Client State ────────────────────────────────────────────
boolean mcpEnabled = false;
ai:ChatCompletionFunctions[] mcpToolFunctions = [];
string[] mcpToolNames = [];

// Map: tool name → MCP connection (for routing tool calls to the correct server)
map<McpConnection> toolToConnection = {};

// List of active MCP connections
McpConnection[] mcpConnections = [];

// App-level OAuth2 Bearer token for MCP gateway auth (client_credentials grant)
string mcpAppToken = "";
decimal mcpAppTokenExpiry = 0;

// Per-request OBO Bearer token for MCP tool calls through APIM gateway
string? mcpOboToken = ();

// Set OBO Bearer token for next MCP tool call(s)
function setMcpOboToken(string? token) {
    mcpOboToken = token;
}

// Known tool names for fallback text parsing (updated dynamically when MCP is enabled)
string[] KNOWN_TOOL_NAMES = [];

// MCP protocol version supported by APIM MCP Gateway
const string MCP_PROTOCOL_VERSION = "2025-06-18";

// JSON-RPC request ID counter
int mcpRequestId = 0;

function nextRequestId() returns int {
    mcpRequestId += 1;
    return mcpRequestId;
}

// Build headers map for MCP requests with OAuth2 Bearer auth.
// Always uses app-level OAuth2 token (from mcpOauthConsumerKey/Secret) for APIM MCP Gateway.
// The OBO token is for IS identity verification only — it does NOT carry APIM subscription
// context, so APIM returns 403 "API Subscription validation failed" if we use it here.
// IMPORTANT: APIM MCP Gateway requires Bearer-only for tools/call (source APIs
// only accept OAuth2). Internal-Key causes 900901 conflict when combined with Bearer.
function buildMcpHeaders(string sessionId = "") returns map<string|string[]> {
    map<string|string[]> headers = {"Content-Type": "application/json"};
    // Always use app-level OAuth2 token for APIM MCP Gateway (subscription-validated)
    if mcpAppToken != "" {
        headers["Authorization"] = "Bearer " + mcpAppToken;
        log:printInfo("MCP request: using app OAuth2 Bearer token");
    }
    if sessionId != "" {
        headers["Mcp-Session-Id"] = sessionId;
    }
    return headers;
}

// ── Acquire App-Level OAuth2 Token (client_credentials grant) ──────────────
// Obtains and caches a Bearer token from WSO2 IS using the MCP OAuth credentials.
// Called at startup (configureMcpAuth) and refreshed automatically before tool calls.

function acquireMcpAppToken() returns string|error {
    // Return cached token if still valid (with 60s buffer)
    if mcpAppToken != "" {
        decimal now = <decimal>time:utcNow()[0];
        if now < mcpAppTokenExpiry - 60d {
            return mcpAppToken;
        }
        log:printInfo("MCP app OAuth2 token expired or expiring — refreshing");
    }

    if mcpOauthConsumerKey == "" || mcpOauthConsumerSecret == "" {
        return error("MCP OAuth credentials not configured (mcpOauthConsumerKey/mcpOauthConsumerSecret)");
    }

    // Use the shared IS HTTP client (from obo_flow.bal)
    http:Client isClient = check getIsClient();

    string tokenBody = "grant_type=client_credentials";
    http:Request tokenReq = new;
    tokenReq.setTextPayload(tokenBody, contentType = "application/x-www-form-urlencoded");

    // Basic auth: base64(consumerKey:consumerSecret)
    string credentials = mcpOauthConsumerKey + ":" + mcpOauthConsumerSecret;
    string encodedCredentials = credentials.toBytes().toBase64();
    tokenReq.setHeader("Authorization", "Basic " + encodedCredentials);

    http:Response tokenResp = check isClient->post("/oauth2/token", tokenReq);
    json tokenJson = check tokenResp.getJsonPayload();

    json|error accessTokenField = tokenJson.access_token;
    if accessTokenField is error || accessTokenField == () {
        string respStr = tokenJson.toJsonString();
        return error(string `OAuth2 token response missing access_token: ${respStr.length() > 300 ? respStr.substring(0, 300) : respStr}`);
    }

    string accessToken = accessTokenField.toString();
    json|error expiresField = tokenJson.expires_in;
    int expiresIn = 3600; // Default 1 hour
    if expiresField is json && expiresField != () {
        int|error parsed = expiresField.ensureType();
        if parsed is int {
            expiresIn = parsed;
        }
    }

    mcpAppToken = accessToken;
    decimal now = <decimal>time:utcNow()[0];
    mcpAppTokenExpiry = now + <decimal>expiresIn;

    log:printInfo(string `MCP OAuth2 app token acquired (length=${accessToken.length()}, expires in ${expiresIn}s)`);
    return mcpAppToken;
}

// ── Configure Auth (called once before initializing any MCP server) ────────
// Acquires an OAuth2 Bearer token via client_credentials grant from WSO2 IS.
// This token is used for ALL MCP gateway requests (initialize, tools/list, tools/call).

function configureMcpAuth() {
    string|error token = acquireMcpAppToken();
    if token is error {
        log:printError("Failed to acquire MCP OAuth2 app token — MCP tool calls may fail", token);
    } else {
        log:printInfo(string `MCP Gateway auth: OAuth2 Bearer configured (token length=${token.length()})`);
    }
}

// ── Initialize a Single MCP Server Connection ──────────────────────────────
// Connects to one MCP server URL, performs handshake, discovers tools.
// Returns the list of discovered tool definitions + connection state.

function initializeSingleMcpServer(string serverUrl) returns [ai:ChatCompletionFunctions[], string[], McpConnection]|error {
    log:printInfo(string `Connecting to MCP server at ${serverUrl}...`);

    // Configure HTTP client
    http:ClientConfiguration clientConfig = {
        timeout: 30
    };
    if serverUrl.startsWith("https://") {
        clientConfig.secureSocket = {enable: false};
    }
    http:Client mcpCl = check new (serverUrl, clientConfig);
    string sessionId = "";

    // Step 1: Send initialize request (JSON-RPC)
    json initRequest = {
        "jsonrpc": "2.0",
        "id": nextRequestId(),
        "method": "initialize",
        "params": {
            "protocolVersion": MCP_PROTOCOL_VERSION,
            "capabilities": {},
            "clientInfo": {
                "name": "Customer Service Copilot",
                "version": "1.0.0"
            }
        }
    };

    http:Response initResp = check mcpCl->post("", initRequest, buildMcpHeaders());
    json initBody = check initResp.getJsonPayload();
    log:printInfo(string `MCP initialize response (${serverUrl}): ${initBody.toJsonString()}`);

    // Check for error
    json|error initError = initBody.'error;
    if initError is json && initError != () {
        return error(string `MCP initialize failed (${serverUrl}): ${initError.toJsonString()}`);
    }

    // Extract session ID from response header
    string|error sessionHeader = initResp.getHeader("Mcp-Session-Id");
    if sessionHeader is string {
        sessionId = sessionHeader;
        log:printInfo(string `MCP session ID (${serverUrl}): ${sessionId}`);
    }

    // Step 2: Send initialized notification
    json initializedNotification = {
        "jsonrpc": "2.0",
        "method": "notifications/initialized"
    };
    http:Response|error notifResp = mcpCl->post("", initializedNotification, buildMcpHeaders(sessionId));
    if notifResp is http:Response {
        log:printInfo(string `MCP initialized notification sent (${serverUrl}, status: ${notifResp.statusCode})`);
    }

    // Step 3: List tools
    json listToolsRequest = {
        "jsonrpc": "2.0",
        "id": nextRequestId(),
        "method": "tools/list",
        "params": {}
    };
    http:Response listResp = check mcpCl->post("", listToolsRequest, buildMcpHeaders(sessionId));
    json listBody = check listResp.getJsonPayload();
    string listBodyStr = listBody.toJsonString();
    int logLen = listBodyStr.length() < 500 ? listBodyStr.length() : 500;
    log:printInfo(string `MCP tools/list (${serverUrl}, ${listBodyStr.length()} chars): ${listBodyStr.substring(0, logLen)}`);

    // Check for error
    json|error listError = listBody.'error;
    if listError is json && listError != () {
        return error(string `MCP tools/list failed (${serverUrl}): ${listError.toJsonString()}`);
    }

    // Parse tools from result
    json toolsJson = check listBody.result.tools;
    json[] toolsArray = <json[]>toolsJson;

    ai:ChatCompletionFunctions[] tools = [];
    string[] toolNames = [];
    foreach json tool in toolsArray {
        string toolName = (check tool.name).toString();
        string toolDesc = "";
        json|error descField = tool.description;
        if descField is json && descField != () {
            toolDesc = descField.toString();
        }

        // Parse inputSchema
        map<json> parameters = {};
        json|error inputSchema = tool.inputSchema;
        if inputSchema is json && inputSchema != () {
            json|error schemaType = inputSchema.'type;
            if schemaType is json {
                parameters["type"] = schemaType;
            }
            json|error props = inputSchema.properties;
            if props is json && props != () {
                parameters["properties"] = props;
            }
            json|error req = inputSchema.required;
            if req is json && req != () {
                parameters["required"] = req;
            }
        }

        tools.push({
            name: toolName,
            description: toolDesc.length() > 0 ? toolDesc : toolName,
            parameters: parameters
        });
        toolNames.push(toolName);
    }

    McpConnection conn = {
        url: serverUrl,
        httpClient: mcpCl,
        sessionId: sessionId,
        toolNames: toolNames
    };

    log:printInfo(string `MCP server ${serverUrl} — discovered ${tools.length()} tools: ${", ".join(...toolNames)}`);
    return [tools, toolNames, conn];
}

// ── Initialize All MCP Servers ─────────────────────────────────────────────
// Called once at startup. Connects to all configured MCP server URLs,
// discovers tools from each, merges them into a single tool list, and builds
// a routing map (tool name → MCP connection) for execution.

function initializeAllMcpClients(string[] serverUrls) returns error? {
    configureMcpAuth();

    ai:ChatCompletionFunctions[] allTools = [];
    string[] allToolNames = [];

    foreach string url in serverUrls {
        if url.length() == 0 {
            continue;
        }
        [ai:ChatCompletionFunctions[], string[], McpConnection]|error result = initializeSingleMcpServer(url);
        if result is error {
            log:printError(string `Failed to initialize MCP server at ${url}`, result);
            continue;
        }
        [ai:ChatCompletionFunctions[], string[], McpConnection] [tools, names, conn] = result;
        mcpConnections.push(conn);
        foreach int i in 0 ..< names.length() {
            allTools.push(tools[i]);
            allToolNames.push(names[i]);
            toolToConnection[names[i]] = conn;
        }
    }

    if allToolNames.length() > 0 {
        mcpEnabled = true;
        mcpToolFunctions = allTools;
        mcpToolNames = allToolNames;
        KNOWN_TOOL_NAMES = allToolNames;
        log:printInfo(string `MCP multi-server initialized — ${allToolNames.length()} total tools from ${mcpConnections.length()} server(s): ${", ".join(...allToolNames)}`);
    } else {
        log:printWarn("No MCP tools discovered from any server");
    }
}

// ── MCP Tool Execution ─────────────────────────────────────────────────────
// Routes the tool call to the correct MCP server based on the tool→connection map.

function executeMcpTool(string name, json arguments) returns json {
    McpConnection? conn = toolToConnection[name];
    if conn is () {
        log:printError(string `MCP tool ${name}: no server connection found (tool not in routing map)`);
        return {"error": string `Tool '${name}' not found in any MCP server`};
    }

    // Refresh app OAuth2 token if needed (before building headers)
    // Always refresh regardless of OBO token state — buildMcpHeaders uses mcpAppToken for APIM auth
    string|error refreshResult = acquireMcpAppToken();
    if refreshResult is error {
        log:printWarn(string `MCP tool ${name}: failed to refresh app token: ${refreshResult.message()}`);
    }

    http:Client mcpCl = conn.httpClient;

    map<json>|error argsMap = arguments.ensureType();
    map<json> args = {};
    if argsMap is map<json> {
        args = argsMap;
    }

    // Build JSON-RPC tools/call request
    json callRequest = {
        "jsonrpc": "2.0",
        "id": nextRequestId(),
        "method": "tools/call",
        "params": {
            "name": name,
            "arguments": args
        }
    };

    map<string|string[]> headers = buildMcpHeaders(conn.sessionId);

    log:printInfo(string `MCP tool ${name}: routing to ${conn.url}`);
    http:Response|error resp = mcpCl->post("", callRequest, headers);
    if resp is error {
        log:printError(string `MCP tool ${name} HTTP request failed (${conn.url})`, resp);
        return {"error": resp.message()};
    }

    int statusCode = resp.statusCode;
    json|error body = resp.getJsonPayload();
    if body is error {
        // Try to get text payload for debugging
        string|error textBody = resp.getTextPayload();
        string bodyStr = textBody is string ? textBody : "(unreadable)";
        log:printError(string `MCP tool ${name} failed to parse JSON response (HTTP ${statusCode}): ${bodyStr}`, body);
        return {"error": body.message()};
    }

    string bodyStr = body.toJsonString();
    log:printInfo(string `MCP tool ${name} raw response (HTTP ${statusCode}, ${bodyStr.length()} chars): ${bodyStr.length() > 2000 ? bodyStr.substring(0, 2000) + "..." : bodyStr}`);

    // Check for JSON-RPC error
    json|error rpcError = body.'error;
    if rpcError is json && rpcError != () {
        log:printError(string `MCP tool ${name} returned error: ${rpcError.toJsonString()}`);
        return {"error": rpcError.toJsonString()};
    }

    // Check for APIM gateway error (non-JSON-RPC format: {"code":"900902","message":"...","description":"..."})
    json|error apimCode = body.code;
    if apimCode is json && apimCode != () {
        json|error apimMsg = body.message;
        json|error apimDesc = body.description;
        string errDetail = string `APIM error ${apimCode.toString()}`;
        if apimMsg is json && apimMsg != () {
            errDetail += string `: ${apimMsg.toString()}`;
        }
        if apimDesc is json && apimDesc != () {
            errDetail += string ` — ${apimDesc.toString()}`;
        }
        log:printError(string `MCP tool ${name}: ${errDetail}`);
        return {"error": errDetail};
    }

    // Extract text content from result
    json|error resultJson = body.result;
    if resultJson is error {
        log:printError(string `MCP tool ${name}: No 'result' field in response body: ${bodyStr.length() > 500 ? bodyStr.substring(0, 500) + "..." : bodyStr}`);
        return {"error": "No result in MCP response"};
    }

    json|error contentJson = resultJson.content;
    if contentJson is error || contentJson == () {
        return resultJson;
    }

    json[] contentArray = <json[]>contentJson;
    string responseText = "";
    foreach json content in contentArray {
        json|error contentType = content.'type;
        if contentType is json && contentType.toString() == "text" {
            json|error textField = content.text;
            if textField is json {
                responseText += textField.toString();
            }
        }
    }

    json|error parsed = responseText.fromJsonString();
    if parsed is json {
        return parsed;
    }
    return {"result": responseText};
}
