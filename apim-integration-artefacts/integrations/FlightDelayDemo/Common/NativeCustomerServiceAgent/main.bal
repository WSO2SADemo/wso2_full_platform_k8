// NativeCustomerServiceAgent — Main Service
// AI Agent-powered Customer Service with native MCP tool discovery.
// Uses ballerina/ai:Agent with ai:McpToolKit for LLM-driven tool selection and execution.
//
// Differences from CustomerServiceAgent (MCP-direct, no LLM):
//   - Uses ai:Agent for natural language understanding and tool orchestration
//   - LLM selects and invokes the right tools based on user intent
//   - No keyword-based routing — the LLM decides which tool to call
//   - MCP tools are discovered at startup via ai:McpToolKit and injected as BaseToolKit

import ballerina/ai;
import ballerina/http;
import ballerina/jwt;
import ballerina/log;
import ballerina/uuid;

// ── AI Agent (module-level, set during init) ───────────────────────────────
ai:Agent? csAgent = ();

// ── HTTP Listener ──────────────────────────────────────────────────────────
listener http:Listener nativeCsListener = new (servicePort, timeout = 300);

// CORS configuration for browser-based dashboard access
@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowMethods: ["GET", "POST", "OPTIONS"],
        allowHeaders: ["Content-Type", "Authorization"],
        exposeHeaders: ["Content-Type"],
        maxAge: 84900
    }
}
service /cs on nativeCsListener {

    function init() {
        log:printInfo("NativeCS Agent initializing — AI Agent mode with MCP tools");

        // ── Step 1: Create MCP Toolkits (discover tools from APIM MCP servers) ──
        ai:McpToolKit[] mcpToolKits = createAllMcpToolKits();

        // ── Step 2: Initialize OBO flow if agent credentials are configured ──
        if agentId.length() > 0 && agentSecret.length() > 0 && appClientId.length() > 0 && isBaseUrl.length() > 0 {
            oboEnabled = true;
            agentCallbackUrl = string `http://localhost:${servicePort}/cs/callback`;
            log:printInfo(string `OBO flow enabled — agentId=${agentId}, IS=${isBaseUrl}`);
            string|error agentTokenResult = acquireAgentToken();
            if agentTokenResult is error {
                log:printError("Failed to pre-acquire agent token", agentTokenResult);
            } else {
                log:printInfo("Agent token pre-acquired successfully");
            }
        } else {
            log:printInfo("OBO flow disabled — agent credentials not configured");
        }

        // ── Step 3: Select system prompt based on MCP availability ───────────
        string promptText = mcpToolKits.length() > 0
            ? CS_AGENT_MCP_SYSTEM_PROMPT
            : CS_AGENT_SYSTEM_PROMPT;

        ai:SystemPrompt systemPrompt = {
            role: "Customer Service Agent",
            instructions: promptText
        };

        // ── Step 4: Build tools array from MCP toolkits ──────────────────────
        // McpToolKit implements McpBaseToolKit → BaseToolKit, so it can be passed
        // directly to ai:Agent as a tool source. The agent discovers all MCP tools
        // from each toolkit and makes them available for LLM tool selection.
        (ai:BaseToolKit|ai:ToolConfig|ai:FunctionTool)[] tools = [];
        foreach ai:McpToolKit toolkit in mcpToolKits {
            tools.push(toolkit);
        }

        // ── Step 5: Create the AI Agent ──────────────────────────────────────
        ai:Agent|error agent = new (
            systemPrompt = systemPrompt,
            model = NativeCustomerServiceAgentModel,
            tools = tools,
            verbose = true
        );

        if agent is error {
            log:printError("Failed to create AI Agent", agent);
        } else {
            csAgent = agent;
            log:printInfo(string `NativeCS Agent ready — AI-powered with ${mcpToolCount} MCP tools from ${mcpServerCount} server(s)`);
        }
    }

    // ── POST /cs/chat — AI Agent-powered customer service chat ─────────────
    resource function post chat(http:Request req, @http:Payload ChatRequest request)
            returns ChatResponse|http:Forbidden|http:Unauthorized|error {

        // ── JWT validation and group-based access control ──────────────────
        string|error authHeaderResult = req.getHeader("authorization");
        string? authHeader = authHeaderResult is string ? authHeaderResult : ();
        if authHeader is () || !authHeader.toLowerAscii().startsWith("bearer ") {
            log:printWarn("Missing or invalid Authorization header");
            return <http:Unauthorized>{body: {response: "Access Denied: Missing or invalid Authorization header."}};
        }
        string jwtToken = authHeader.substring(7).trim();
        map<anydata>|error claimsOrErr = validateJwtAndRoles(jwtToken);
        if claimsOrErr is error {
            log:printWarn("JWT validation failed: " + claimsOrErr.message());
            return <http:Forbidden>{body: {response: "Access Denied: " + claimsOrErr.message()}};
        }
        map<anydata> claims = <map<anydata>>claimsOrErr;

        string userSub = "unknown";
        if claims.hasKey("sub") {
            any subVal = claims["sub"];
            if subVal is string {
                userSub = subVal;
            }
        }
        log:printInfo(string `NativeCS Agent received: "${request.message}" from user: ${userSub}`);

        // Reset OBO token for this request
        currentOBOToken = ();

        // ── OBO: Generate or retrieve session ID ───────────────────────────
        string sessionId = request.session_id ?: uuid:createType4AsString();

        // ── OBO: Check if delegated token is available for this session ────
        if oboEnabled {
            string? oboToken = getSessionOBOToken(sessionId);
            if oboToken is () {
                // No OBO token — redirect user to consent page
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

        // ── Check agent availability ───────────────────────────────────────
        ai:Agent? agent = csAgent;
        if agent is () {
            return {
                response: "The AI Agent is not initialized. Please check the server configuration and MCP connectivity.",
                session_id: sessionId
            };
        }

        // ── Run the AI Agent ───────────────────────────────────────────────
        // The agent uses the LLM to understand the user's intent, select the
        // appropriate MCP tool(s), execute them, and compose a response.
        string|ai:Error result = agent.run(request.message, sessionId = sessionId);
        if result is ai:Error {
            log:printError("AI Agent execution failed", result);
            return {
                response: "I encountered an error while processing your request: " + result.message(),
                session_id: sessionId,
                agent_token: cachedAgentToken,
                obo_token: currentOBOToken
            };
        }

        log:printInfo(string `NativeCS Agent response for session ${sessionId}: ${result.length() > 200 ? result.substring(0, 200) + "..." : result}`);

        return {
            response: result,
            session_id: sessionId,
            agent_token: cachedAgentToken,
            obo_token: currentOBOToken
        };
    }

    // ── GET /cs/callback — OBO flow callback ───────────────────────────────
    resource function get callback(string? code = (), string? state = ()) returns http:Response|error {
        log:printInfo(string `NativeCS Agent OBO callback: code=${code ?: "null"}, state=${state ?: "null"}`);

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

        resp.setPayload("<html><body><h2>Authorization Successful</h2><p>You have authorized the Customer Service Agent to act on your behalf.</p><p>This window will close automatically...</p><script>if(window.opener){window.opener.postMessage({type:'obo_authorized'},'*');}setTimeout(function(){window.close();},1500);</script></body></html>");
        resp.setHeader("Content-Type", "text/html");
        return resp;
    }

    // ── GET /cs/health — Health check endpoint ─────────────────────────────
    resource function get health() returns json {
        string toolMode = mcpEnabled
            ? string `AI Agent with MCP (${mcpToolCount} tools from ${mcpServerCount} server(s))`
            : "AI Agent (no MCP tools)";
        return {
            status: "running",
            agent: "Native Customer Service Agent",
            mode: "AI Agent with LLM",
            tool_discovery: toolMode,
            mcp_enabled: mcpEnabled,
            mcp_servers: mcpServerCount,
            mcp_tools: mcpToolCount,
            agent_initialized: csAgent is ai:Agent,
            obo_enabled: oboEnabled,
            obo_sessions: sessionOBOTokens.length()
        };
    }
}

// ── JWT Validation & Group Access Control ──────────────────────────────────

function validateJwtAndRoles(string jwtToken) returns map<anydata>|error {
    // Decode JWT (no signature verification — JWKS validation can be added)
    [jwt:Header, jwt:Payload]|jwt:Error decoded = jwt:decode(jwtToken);
    if decoded is jwt:Error {
        return error("Invalid JWT: " + decoded.message());
    }
    [jwt:Header, jwt:Payload] [_, payload] = decoded;
    map<anydata> claims = <map<anydata>>payload;

    // Extract user groups from JWT claims
    string[] userGroups = [];
    if claims.hasKey("groups") {
        any groupsVal = claims["groups"];
        if groupsVal is string[] {
            userGroups = groupsVal;
        } else if groupsVal is string {
            userGroups = [groupsVal];
        }
    } else if claims.hasKey("role") {
        any roleVal = claims["role"];
        if roleVal is string[] {
            userGroups = roleVal;
        } else if roleVal is string {
            userGroups = [roleVal];
        }
    }

    // If groups not found in JWT, try IS userinfo endpoint
    if userGroups.length() == 0 && isBaseUrl.length() > 0 {
        string[]|error fetchedGroups = fetchUserGroups(jwtToken);
        if fetchedGroups is string[] {
            userGroups = fetchedGroups;
        } else {
            log:printWarn("Could not fetch user groups from IS userinfo: " + fetchedGroups.message());
        }
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
            if hasAccess {
                break;
            }
        }
        if !hasAccess {
            string userSub = "unknown";
            if claims.hasKey("sub") {
                any subVal = claims["sub"];
                if subVal is string {
                    userSub = subVal;
                }
            }
            log:printWarn(string `Access denied for user '${userSub}' — groups ${userGroups.toString()} not in allowed: ${allowedGroups.toString()}`);
            return error(string `Insufficient permissions. This agent requires membership in one of: ${allowedGroups.toString()}`);
        }
    }

    return claims;
}

// Fetch user groups from IS /oauth2/userinfo endpoint
function fetchUserGroups(string accessToken) returns string[]|error {
    http:Client isClient = check getIsClient();

    map<string|string[]> headers = {"Authorization": "Bearer " + accessToken};
    json|http:ClientError resp = isClient->get("/oauth2/userinfo", headers);
    if resp is http:ClientError {
        log:printWarn("Userinfo call failed: " + resp.message());
    } else {
        json|error groupsResult = resp.groups;
        if groupsResult is json && groupsResult != () {
            json groupsJson = groupsResult;
            if groupsJson is json[] {
                string[] groups = [];
                foreach json g in groupsJson {
                    groups.push(g.toString());
                }
                if groups.length() > 0 {
                    log:printInfo(string `Fetched groups from IS userinfo: ${groups.toString()}`);
                    return groups;
                }
            } else if groupsJson is string {
                return [groupsJson];
            }
        }

        // Fallback: SCIM — look up user's groups by sub from userinfo
        json|error subResult = resp.sub;
        if subResult is json && subResult.toString().length() > 0 {
            string userId = subResult.toString();
            string[]|error scimGroups = fetchUserGroupsBySCIM(userId);
            if scimGroups is string[] && scimGroups.length() > 0 {
                return scimGroups;
            }
        }
    }
    return [];
}

// Fetch user groups from IS SCIM2 API — fallback when userinfo doesn't return groups
function fetchUserGroupsBySCIM(string userId) returns string[]|error {
    http:Client isClient = check getIsClient();
    string scimUrl = string `/scim2/Users/${userId}`;
    map<string|string[]> headers = {"Authorization": "Basic YWRtaW46YWRtaW4="};
    json|http:ClientError resp = isClient->get(scimUrl, headers);
    if resp is http:ClientError {
        return error("SCIM user lookup failed: " + resp.message());
    }

    json|error groupsField = resp.groups;
    if groupsField is error || groupsField == () {
        return [];
    }

    json[] groupsList = <json[]>groupsField;
    string[] groups = [];
    foreach json g in groupsList {
        json|error displayName = g.display;
        if displayName is json && displayName != () {
            groups.push(displayName.toString());
        }
    }
    log:printInfo(string `Fetched groups from SCIM for user ${userId}: ${groups.toString()}`);
    return groups;
}