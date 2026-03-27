// Admin Agent for ADR — Agent Loop & HTTP Service
// Provides natural language interface for querying recovery plans and triggering recovery operations.
// Routes LLM calls through WSO2 APIM AI Gateway using OBO Bearer token (preferred) or ApiKey fallback.
//
// Related files:
//   mcp_client.bal          — MCP tool discovery & execution via APIM MCP Gateway
//   apim_ollama_provider.bal — Custom LLM provider (Ollama via APIM with OBO auth)
//   obo_flow.bal            — On-Behalf-Of delegated identity flow (WSO2 IS integration)

import ballerina/ai;
import ballerina/http;
import ballerina/jwt;
import ballerina/log;
import ballerina/uuid;

// ── Configuration ──────────────────────────────────────────────────────────
configurable string aillmModel = "llama3.2:1b";
configurable string aillmServiceUrl = "http://localhost:11434";

// MCP (Model Context Protocol) configuration
configurable string mcpServerUrl = "";
configurable string mcpApiKey = "";

// Legacy APIM gateway token (kept for backward compatibility with existing configs)
configurable string aiGatewayToken = "";

// JWKS endpoint for JWT validation (from WSO2 IS/Asgardeo)
configurable string jwksUrl = "https://localhost:9444/oauth2/jwks";

// Allowed groups for agent access (from JWT 'groups' claim).
configurable string[] allowedGroups = ["adr_admins"];

// WSO2 Identity Server — AI Agent On-Behalf-Of (OBO) flow configuration
configurable string agentId = "";
configurable string agentSecret = "";
configurable string appClientId = "";
configurable string isBaseUrl = "";
configurable string isPublicUrl = "";

// ── AI Model Provider (LLM via APIM AI Gateway) ───────────────────────────
final ApimOllamaProvider ollamaModel = check new ApimOllamaProvider(
    aillmModel,
    aillmServiceUrl,
    apiKey = aiGatewayToken,
    timeout = 120,
    secureSocket = aillmServiceUrl.startsWith("https") ? {enable: false} : ()
);


// ── Types ──────────────────────────────────────────────────────────────────
// Types used for communicating with the ADR Orchestrator REST API


type ChatRequest record {|
    string message;
    string? session_id = ();
|};

type ChatResponse record {|
    string response;
    string? function_called = ();
    json? function_result = ();
    string? consent_url = ();
    string? session_id = ();
    string? agent_token = ();
    string? obo_token = ();
|};

// ── System prompt (built dynamically from MCP-discovered tools) ────────────
// All tools are discovered via MCP — no hardcoded tool definitions.
// The system prompt is set from MCP_SYSTEM_PROMPT in mcp_client.bal.

// ── Tool execution (MCP only) ──────────────────────────────────────────────

function executeTool(string name, json arguments) returns json {
    log:printInfo(string `Executing tool via MCP: ${name}`);
    return executeMcpTool(name, arguments);
}

// ── Admin Agent Service ────────────────────────────────────────────────────
listener http:Listener aiListener = new (9095, timeout = 300);

@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowMethods: ["GET", "POST", "OPTIONS"],
        allowHeaders: ["Content-Type", "Authorization"],
        exposeHeaders: ["Content-Type"],
        maxAge: 84900
    }
}
service /ai on aiListener {

    // POST /ai/chat — Natural language interface for recovery operations
    resource function post chat(http:Request req, @http:Payload ChatRequest request) returns ChatResponse|http:Forbidden|http:Unauthorized|error {
        // ── JWT validation ──────────────────────────────────────────────────
        string|error authHeaderResult = req.getHeader("authorization");
        string? authHeader = authHeaderResult is string ? authHeaderResult : ();
        if authHeader is () || !authHeader.toLowerAscii().startsWith("bearer ") {
            return <http:Unauthorized>{body: {response: "Access Denied: Missing or invalid Authorization header."}};
        }
        string jwtToken = authHeader.substring(7).trim();
        map<anydata>|error claimsOrErr = validateJwtAndRoles(jwtToken);
        if claimsOrErr is error {
            return <http:Forbidden>{body: {response: "Access Denied: " + claimsOrErr.message()}};
        }
        map<anydata> claims = <map<anydata>>claimsOrErr;

        string userSub = "unknown";
        if claims.hasKey("sub") {
            any subVal = claims["sub"];
            if subVal is string { userSub = subVal; }
        }
        log:printInfo(string `Admin Agent received: ${request.message} from user: ${userSub}`);
        currentOBOToken = ();

        // ── OBO flow ────────────────────────────────────────────────────────
        string sessionId = request.session_id ?: uuid:createType4AsString();

        if oboEnabled {
            string? oboToken = getSessionOBOToken(sessionId);
            if oboToken is () {
                string|error consentUrl = generateOBOAuthUrl(sessionId);
                if consentUrl is error {
                    log:printError("Failed to generate OBO consent URL", consentUrl);
                } else {
                    log:printInfo(string `OBO consent required for session ${sessionId}`);
                    return {
                        response: "I need your authorization to proceed. Please click the button below to authorize me to act on your behalf.",
                        consent_url: consentUrl,
                        session_id: sessionId,
                        agent_token: cachedAgentToken
                    };
                }
            } else {
                currentOBOToken = oboToken;
            }
        }

        // All tools are discovered exclusively via MCP (APIM MCP Gateway)
        if !mcpEnabled || mcpToolFunctions.length() == 0 {
            return {
                response: "MCP tool discovery is not available. Please check the MCP server connection.",
                session_id: sessionId,
                agent_token: cachedAgentToken
            };
        }

        // Pass OBO token to LLM provider and MCP client for APIM authentication
        ollamaModel.setAuthToken(currentOBOToken);
        setMcpOboToken(currentOBOToken);

        // ── Agent loop ──────────────────────────────────────────────────────
        ai:ChatMessage[] messages = [
            <ai:ChatSystemMessage>{role: ai:SYSTEM, content: MCP_SYSTEM_PROMPT},
            <ai:ChatUserMessage>{role: ai:USER, content: request.message}
        ];

        string? lastFunctionCalled = ();
        json? lastFunctionResult = ();
        int maxIterations = 10;

        foreach int i in 0 ..< maxIterations {
            ai:ChatAssistantMessage response = check ollamaModel->chat(messages, mcpToolFunctions);
            string content = response.content ?: "";
            messages.push(response);

            // Path 1: Typed tool calls from ModelProvider
            ai:FunctionCall[]? toolCalls = response.toolCalls;
            if toolCalls is ai:FunctionCall[] && toolCalls.length() > 0 {
                foreach ai:FunctionCall tc in toolCalls {
                    log:printInfo(string `Tool call: ${tc.name}`);
                    json toolResult = executeTool(tc.name, tc.arguments ?: {});
                    lastFunctionCalled = tc.name;
                    lastFunctionResult = toolResult;
                    messages.push(<ai:ChatFunctionMessage>{
                        role: "function",
                        name: tc.name,
                        content: toolResult.toJsonString()
                    });
                }
                continue;
            }

            // Path 2: Final text response
            if lastFunctionCalled is string {
                log:printInfo(string `Final response after tool execution (iteration ${i + 1})`);
            }
            return {
                response: content,
                function_called: lastFunctionCalled,
                function_result: lastFunctionResult,
                session_id: sessionId,
                agent_token: cachedAgentToken,
                obo_token: currentOBOToken
            };
        }

        return {
            response: "I completed the maximum number of steps. Please check the results.",
            function_called: lastFunctionCalled,
            function_result: lastFunctionResult,
            session_id: sessionId,
            agent_token: cachedAgentToken,
            obo_token: currentOBOToken
        };
    }

    // GET /ai/callback — OBO flow callback (IS redirects here after user consent)
    resource function get callback(http:Request req, string? code = (), string? state = ()) returns http:Response|error {
        log:printInfo(string `OBO callback received: code=${code ?: "null"}, state=${state ?: "null"}`);

        http:Response resp = new;
        if code is () || state is () {
            resp.statusCode = 400;
            resp.setPayload("<html><body><h2>Authorization Failed</h2><p>Missing code or state parameter.</p></body></html>");
            resp.setHeader("Content-Type", "text/html");
            return resp;
        }

        error? result = exchangeOBOToken(code, state);
        if result is error {
            log:printError("OBO token exchange failed", result);
            resp.statusCode = 500;
            resp.setPayload(string `<html><body><h2>Authorization Failed</h2><p>${result.message()}</p></body></html>`);
            resp.setHeader("Content-Type", "text/html");
            return resp;
        }

        resp.setPayload("<html><body><h2>Authorization Successful</h2><p>You have authorized the AI agent to act on your behalf.</p><p>This window will close automatically...</p><script>if(window.opener){window.opener.postMessage({type:'obo_authorized'},'*');}setTimeout(function(){window.close();},1500);</script></body></html>");
        resp.setHeader("Content-Type", "text/html");
        return resp;
    }

    // GET /ai/health — Health check
    resource function get health() returns json {
        return {
            status: "running",
            model: aillmModel,
            llm_routing: aillmServiceUrl,
            tool_discovery: string `APIM MCP Proxy (${mcpToolNames.length()} tools)`,
            mcp_enabled: mcpEnabled,
            mcp_proxy: mcpServerUrl,
            mcp_tools: mcpToolNames,
            obo_enabled: oboEnabled,
            obo_sessions: sessionOBOTokens.length()
        };
    }
}

// ── JWT Validation ─────────────────────────────────────────────────────────
function validateJwtAndRoles(string jwtToken) returns map<anydata>|error {
    [jwt:Header, jwt:Payload]|jwt:Error decoded = jwt:decode(jwtToken);
    if decoded is jwt:Error {
        return error("Invalid JWT: " + decoded.message());
    }
    [jwt:Header, jwt:Payload] [_, payload] = decoded;
    map<anydata> claims = <map<anydata>>payload;

    string[] userGroups = [];
    if claims.hasKey("groups") {
        any groupsVal = claims["groups"];
        if groupsVal is string[] { userGroups = groupsVal; }
        else if groupsVal is string { userGroups = [groupsVal]; }
    } else if claims.hasKey("role") {
        any roleVal = claims["role"];
        if roleVal is string[] { userGroups = roleVal; }
        else if roleVal is string { userGroups = [roleVal]; }
    }

    // Fetch from IS userinfo if groups not in JWT
    if userGroups.length() == 0 && isBaseUrl.length() > 0 {
        string[]|error fetchedGroups = fetchUserGroups(jwtToken);
        if fetchedGroups is string[] { userGroups = fetchedGroups; }
    }

    // Group-based access control
    if allowedGroups.length() > 0 {
        boolean hasAccess = false;
        foreach string allowed in allowedGroups {
            foreach string userGroup in userGroups {
                if userGroup.toLowerAscii() == allowed.toLowerAscii() {
                    hasAccess = true;
                    break;
                }
            }
            if hasAccess { break; }
        }
        if !hasAccess {
            string userSub = "unknown";
            if claims.hasKey("sub") {
                any subVal = claims["sub"];
                if subVal is string { userSub = subVal; }
            }
            return error(string `Insufficient permissions. Requires membership in: ${allowedGroups.toString()}`);
        }
    }
    return claims;
}

function fetchUserGroups(string accessToken) returns string[]|error {
    http:Client isClient = check getIsClient();
    map<string|string[]> headers = {"Authorization": "Bearer " + accessToken};
    json|http:ClientError resp = isClient->get("/oauth2/userinfo", headers);
    if resp is http:ClientError {
        return error("Userinfo call failed: " + resp.message());
    }
    json|error groupsResult = resp.groups;
    if groupsResult is error { return []; }
    json groupsJson = groupsResult;
    if groupsJson is json[] {
        return from json g in groupsJson select g.toString();
    } else if groupsJson is string {
        return [groupsJson];
    }
    return [];
}
