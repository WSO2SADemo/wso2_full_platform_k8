// insurance_agent — OBO Chat Service
// A new service mounted on the same listener as the main insurance_agent service.
// Uses the standard agent (agentID/agentSecret) for getPolicy and getClaims.
// For submitClaim, an OBO delegated token (user-consented) is injected instead of the agent's own token.
//
// Endpoints:
//   POST /insurance_obo/obo_chat     — OBO-aware chat; returns consent_url on first call
//   GET  /insurance_obo/obo_callback — IS redirects here after user consents
//   GET  /insurance_obo/health       — Health check

import ballerina/ai;
import ballerina/http;
import ballerina/log;
import ballerina/mcp;

// ── OBO-aware Customer MCP Toolkit ──────────────────────────────────────────
// Same as AiInsuraceCustomerMcpbasetoolkit (agents.bal) but submitClaim uses
// the session OBO token (set in currentOBOToken) instead of ctx.getAccessToken().
// getPolicy and getClaims are unchanged — they still use ctx.getAccessToken() with ordinary scope.

isolated class AiInsuranceOboCustomerMcpbasetoolkit {
    *ai:McpBaseToolKit;
    private final mcp:StreamableHttpClient mcpClient;
    private final readonly & ai:ToolConfig[] tools;

    public isolated function init(string serverUrl, mcp:Implementation info = {name: "MCP", version: "1.0.0"},
            *ai:StreamableHttpClientTransportConfig config) returns ai:Error? {
        final map<ai:FunctionTool> permittedTools = {
            "submitClaim": self.submitClaim,
            "getPolicy": self.getPolicy,
            "getClaims": self.getClaims
        };
        do {
            ai:StreamableHttpClientTransportConfig {auth, ...configs} = config;
            mcp:StreamableHttpClientTransportConfig mcpConfig = {...configs};
            ai:AgentIdAuthConfig? agentIdAuth = ();
            if auth is http:ClientAuthConfig {
                mcpConfig.auth = auth;
                auth = ();
            } else {
                agentIdAuth = auth;
            }
            self.mcpClient = check new mcp:StreamableHttpClient(serverUrl, mcpConfig);
            self.tools = check ai:getPermittedMcpToolConfigs(self.mcpClient, info, permittedTools, agentIdAuth).cloneReadOnly();
            log:printInfo("AiInsuranceOboCustomerMcpbasetoolkit initialized");
        } on fail error e {
            log:printError("Error initializing AiInsuranceOboCustomerMcpbasetoolkit", e);
            return error ai:Error("Failed to initialize OBO MCP toolkit", e);
        }
    }

    public isolated function getTools() returns ai:ToolConfig[] => self.tools;

    // submitClaim: uses the OBO delegated token.
    // If no OBO token is available, sets oboConsentRequired flag (read by obo_chat after agent.run())
    // so consent is only triggered when submitClaim is actually needed — not for read-only queries.
    @ai:AgentTool
    public isolated function submitClaim(ai:Context ctx, mcp:CallToolParams params) returns mcp:CallToolResult|error {
        string? oboToken;
        lock {
            oboToken = currentOBOToken;
        }
        if oboToken is () {
            lock {
                oboConsentRequired = true;
            }
            return {
                content: [{'type: "text", text: "User authorization is required to submit claims. Awaiting user consent."}],
                isError: true
            };
        }
        log:printInfo(string `Insurance OBO: submitClaim executing with OBO token for tool: ${params.name}`);
        return self.mcpClient->callTool(params, headers = {"Authorization": string `Bearer ${oboToken}`});
    }

    // getPolicy: uses agent's own token (ordinary scope) — same as base toolkit
    @ai:AgentTool {auth: {scopes: ["ordinary_customer_agent_scope"]}}
    public isolated function getPolicy(ai:Context ctx, mcp:CallToolParams params) returns mcp:CallToolResult|error {
        return self.mcpClient->callTool(params, headers = {"Authorization": string `Bearer ${check ctx.getAccessToken(params.name)}`});
    }

    // getClaims: uses agent's own token (ordinary scope) — same as base toolkit
    @ai:AgentTool {auth: {scopes: ["ordinary_customer_agent_scope"]}}
    public isolated function getClaims(ai:Context ctx, mcp:CallToolParams params) returns mcp:CallToolResult|error {
        return self.mcpClient->callTool(params, headers = {"Authorization": string `Bearer ${check ctx.getAccessToken(params.name)}`});
    }
}

// ── Response type with optional OBO consent URL ─────────────────────────────

type OBOChatResponse record {|
    string message;
    string? consent_url = ();
    string? session_id = ();
    string? obo_token = ();
    string? agent_token = ();
|};

// ── OBO Chat Service ────────────────────────────────────────────────────────

@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowMethods: ["GET", "POST", "OPTIONS"],
        allowHeaders: ["Content-Type", "Authorization"],
        exposeHeaders: ["Content-Type"],
        maxAge: 84900
    }
}
service /insurance_obo on insurance_agentListener {
    private final ai:Agent obo_insurance_agent;

    function init() returns error? {
        // Initialize OBO flow if agent credentials are configured
        if agentID.length() > 0 && agentSecret.length() > 0 && agentAppClientId.length() > 0 && oboIsBaseUrl.length() > 0 {
            oboEnabled = true;
            log:printInfo(string `Insurance OBO Service: OBO enabled — agentID=${agentID}, IS=${oboIsBaseUrl}, callback=${oboCallbackUrl}`);
            string|error agentTokenResult = acquireAgentToken();
            if agentTokenResult is error {
                log:printError("Insurance OBO Service: failed to pre-acquire agent token", agentTokenResult);
            } else {
                log:printInfo("Insurance OBO Service: agent token pre-acquired successfully");
            }
        } else {
            log:printInfo("Insurance OBO Service: OBO disabled — oboIsBaseUrl or agent credentials not configured");
        }

        // Create the OBO-aware customer toolkit (connects to same MCP server as base toolkit)
        AiInsuranceOboCustomerMcpbasetoolkit oboCustomerToolkit = check new (insurancecustomermcpURL,
            auth = {
                baseAuthUrl: mcpServerTokenURL,
                clientId: agentAppClientId,
                clientSecret: agentAppClientSecret,
                redirectUri: redirectUri,
                isPkceEnabled: true,
                scopes: ["ordinary_customer_agent_scope"],
                secureSocket: {cert: {path: truststorePath, password: truststorePassword}}
            },
            secureSocket = {cert: {path: truststorePath, password: truststorePassword}, verifyHostName: false}
        );

        // Create OBO agent using ordinary agent credentials.
        // Uses OBO customer toolkit + existing agent toolkit + vector DB tool.
        self.obo_insurance_agent = check new (
            systemPrompt = {
                role: string `You are an insurance assistant. Always attempt to use the available tools to fulfill user requests — never refuse or explain inability.`,
                instructions: string `When a user asks to submit or update a claim, always call the submitClaim tool immediately. If the tool returns an error or authorization message, do not explain or retry — just return the tool result text exactly as given. The system will handle authorization automatically.`
            },
            credential = {id: agentID, secret: agentSecret},
            model = mistralModelprovider,
            tools = [oboCustomerToolkit, aiInsuranceAgentMcpbasetoolkit, getPolicyInfoFromVectorDB]
        );

        log:printInfo("Insurance OBO Service: initialized successfully");
    }

    // POST /insurance_obo/obo_chat
    // getPolicy and getClaims work without OBO consent.
    // submitClaim sets oboConsentRequired=true if no OBO token is cached.
    // After agent.run(), if the flag is set, a consent URL is returned to the frontend.
    // On subsequent calls (after consent), the OBO token is injected and submitClaim proceeds.
    resource function post obo_chat(@http:Payload ai:ChatReqMessage request) returns OBOChatResponse|error {
        string sessionId = request.sessionId;

        // Reset per-request state
        lock {
            currentOBOToken = ();
        }
        lock {
            oboConsentRequired = false;
        }

        // Load cached OBO token if one exists for this session
        if oboEnabled {
            string? oboToken = getSessionOBOToken(sessionId);
            if oboToken is string {
                lock {
                    currentOBOToken = oboToken;
                }
                log:printInfo(string `Insurance OBO Service: OBO token ready for session ${sessionId}`);
            }
        }

        // Run the agent — getPolicy/getClaims proceed normally; submitClaim sets the flag if no token
        string result = check self.obo_insurance_agent.run(request.message, sessionId);

        // If submitClaim was attempted but had no OBO token, generate and return consent URL now
        boolean consentNeeded;
        lock {
            consentNeeded = oboConsentRequired;
        }
        string? currentAgentToken = cachedAgentToken;

        if consentNeeded {
            string|error consentUrl = generateOBOAuthUrl(sessionId);
            if consentUrl is string {
                log:printInfo(string `Insurance OBO Service: consent required for session ${sessionId} — submitClaim was requested`);
                return {
                    message: "I need your authorization to submit claims on your behalf. Please click the authorization link, then resend your request.",
                    consent_url: consentUrl,
                    session_id: sessionId,
                    agent_token: currentAgentToken
                };
            }
            log:printError("Insurance OBO Service: failed to generate consent URL", <error>consentUrl);
        }

        string? activeOboToken = ();
        lock {
            activeOboToken = currentOBOToken;
        }
        return {message: result, session_id: sessionId, obo_token: activeOboToken, agent_token: currentAgentToken};
    }

    // GET /insurance_obo/obo_callback
    // IS redirects here after the user approves the consent screen.
    // Exchanges the authorization code + agent token for a delegated OBO JWT,
    // then closes the popup and notifies the opener window via postMessage.
    resource function get obo_callback(string? code = (), string? state = ()) returns http:Response|error {
        log:printInfo(string `Insurance OBO Service: callback received — code=${code ?: "null"}, state=${state ?: "null"}`);

        http:Response resp = new;
        if code is () || state is () {
            resp.statusCode = 400;
            resp.setPayload("<html><body><h2>Authorization Failed</h2><p>Missing code or state parameter.</p></body></html>");
            resp.setHeader("Content-Type", "text/html");
            return resp;
        }

        error? result = exchangeOBOToken(code, state);
        if result is error {
            log:printError("Insurance OBO Service: OBO token exchange failed", result);
            resp.statusCode = 500;
            resp.setPayload(string `<html><body><h2>Authorization Failed</h2><p>${result.message()}</p></body></html>`);
            resp.setHeader("Content-Type", "text/html");
            return resp;
        }

        resp.setPayload("<html><body><h2>Authorization Successful</h2><p>You have authorized the Insurance Agent to act on your behalf.</p><p>This window will close automatically...</p><script>if(window.opener){window.opener.postMessage({type:'obo_authorized'},'*');}setTimeout(function(){window.close();},1500);</script></body></html>");
        resp.setHeader("Content-Type", "text/html");
        return resp;
    }

    resource function get health() returns json {
        return {
            status: "UP",
            'service: "insurance_obo",
            obo_enabled: oboEnabled,
            obo_sessions: sessionOBOTokens.length()
        };
    }
}
