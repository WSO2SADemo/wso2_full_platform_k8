// OBO (On-Behalf-Of) Flow — Delegated User-Agent Identity
// Implements the WSO2 IS 7.2.0 Agentic AI OBO flow per IETF draft-oauth-ai-agents-on-behalf-of-user.
// The AI agent authenticates itself, then obtains a delegated OBO token with user consent,
// allowing the agent to act on behalf of the user with proper authorization.

import ballerina/crypto;
import ballerina/http;
import ballerina/log;
import ballerina/regex;
import ballerina/time;
import ballerina/uuid;

// ── OBO Types ──────────────────────────────────────────────────────────────

type OBOPendingAuth record {|
    string codeVerifier;
    string sessionId;
    decimal createdAt;
|};

type CachedOBOToken record {|
    string accessToken;
    decimal expiresAt;
    string? userSub;
|};

// ── OBO State ──────────────────────────────────────────────────────────────

// Agent's own access token (obtained via Agent Authentication API)
string? cachedAgentToken = ();
decimal agentTokenExpiry = 0;

// Pending OBO authorization flows keyed by state parameter
map<OBOPendingAuth> pendingOBOAuths = {};

// Cached OBO tokens keyed by session ID
map<CachedOBOToken> sessionOBOTokens = {};

// Whether OBO is enabled (agent credentials configured)
boolean oboEnabled = false;

// Agent callback URL for OBO flow redirects
string agentCallbackUrl = "http://localhost:9095/ai/callback";

// Currently active OBO token for the request being processed
string? currentOBOToken = ();

// ── IS HTTP Client ─────────────────────────────────────────────────────────

// Lazy IS HTTP client reference
http:Client? isClientRef = ();

// Get or create IS HTTP client (handles self-signed certs)
function getIsClient() returns http:Client|error {
    http:Client? existing = isClientRef;
    if existing is http:Client {
        return existing;
    }
    http:Client newClient = check new (isBaseUrl,
        secureSocket = isBaseUrl.startsWith("https") ? {enable: false} : ()
    );
    isClientRef = newClient;
    return newClient;
}

// ── PKCE Helpers ───────────────────────────────────────────────────────────

// Generate a PKCE code verifier (43 chars of unreserved characters)
function generateCodeVerifier() returns string {
    string id1 = uuid:createType4AsString();
    string id2 = uuid:createType4AsString();
    string raw = regex:replaceAll(id1 + id2, "-", "");
    return raw.substring(0, 43);
}

// Generate a PKCE code challenge: BASE64URL(SHA256(verifier))
function generateCodeChallenge(string verifier) returns string {
    byte[] hash = crypto:hashSha256(verifier.toBytes());
    string b64Str = hash.toBase64();
    string result = regex:replaceAll(b64Str, "\\+", "-");
    result = regex:replaceAll(result, "/", "_");
    result = regex:replaceAll(result, "=", "");
    return result;
}

// ── Agent Token Acquisition ────────────────────────────────────────────────

// Acquire agent's own access token via IS Agent Authentication API (3-step flow)
//   1. POST /oauth2/authorize (response_mode=direct) → flowId
//   2. POST /oauth2/authn (BasicAuthenticator with agent ID/secret) → authorization code
//   3. POST /oauth2/token (authorization_code grant) → agent access_token
function acquireAgentToken() returns string|error {
    // Return cached token if still valid (30s buffer before expiry)
    if cachedAgentToken is string {
        decimal now = <decimal>time:utcNow()[0];
        if now < agentTokenExpiry - 30d {
            return <string>cachedAgentToken;
        }
    }

    http:Client isClient = check getIsClient();

    // Generate PKCE pair for the agent auth flow (PKCE is mandatory on this app)
    string agentCodeVerifier = generateCodeVerifier();
    string agentCodeChallenge = generateCodeChallenge(agentCodeVerifier);

    // Step 1: Authorize with response_mode=direct + PKCE
    string authBody = string `response_type=code&client_id=${appClientId}&scope=openid&redirect_uri=${agentCallbackUrl}&response_mode=direct&code_challenge=${agentCodeChallenge}&code_challenge_method=S256`;
    http:Request authReq = new;
    authReq.setTextPayload(authBody, contentType = "application/x-www-form-urlencoded");
    http:Response authResp = check isClient->post("/oauth2/authorize", authReq);
    json authJson = check authResp.getJsonPayload();

    // Validate response — IS may return an error (e.g., invalid_client) instead of a flow
    json|error flowIdField = authJson.flowId;
    if flowIdField is error {
        string respStr = authJson.toJsonString();
        string preview = respStr.length() > 300 ? respStr.substring(0, 300) : respStr;
        return error(string `IS /oauth2/authorize did not return flowId (appClientId=${appClientId}). Response: ${preview}`);
    }
    string flowId = flowIdField.toString();
    log:printDebug(string `OBO agent auth step 1: flowId=${flowId}`);

    // Step 2: Authenticate with agent credentials via BasicAuthenticator
    json authnPayload = {
        "flowId": flowId,
        "selectedAuthenticator": {
            "authenticatorId": "QmFzaWNBdXRoZW50aWNhdG9yOkxPQ0FM",
            "params": {
                "username": agentId,
                "password": agentSecret
            }
        }
    };
    http:Request authnReq = new;
    authnReq.setJsonPayload(authnPayload);
    http:Response authnResp = check isClient->post("/oauth2/authn", authnReq);
    json authnJson = check authnResp.getJsonPayload();
    // The auth code is nested inside authData when flowStatus=SUCCESS_COMPLETED
    json authData = check authnJson.authData;
    string authCode = (check authData.code).toString();
    log:printDebug("OBO agent auth step 2: got authorization code");

    // Step 3: Exchange code for agent token (include code_verifier for PKCE)
    string tokenBody = string `grant_type=authorization_code&code=${authCode}&redirect_uri=${agentCallbackUrl}&client_id=${appClientId}&code_verifier=${agentCodeVerifier}`;
    http:Request tokenReq = new;
    tokenReq.setTextPayload(tokenBody, contentType = "application/x-www-form-urlencoded");
    http:Response tokenResp = check isClient->post("/oauth2/token", tokenReq);
    json tokenJson = check tokenResp.getJsonPayload();
    string accessToken = (check tokenJson.access_token).toString();
    int|error expiresIn = (check tokenJson.expires_in).ensureType(int);

    // Cache the agent token
    cachedAgentToken = accessToken;
    agentTokenExpiry = <decimal>time:utcNow()[0] + <decimal>(expiresIn is int ? expiresIn : 3600);
    log:printInfo("OBO agent token acquired successfully");

    return accessToken;
}

// ── OBO Authorization URL ──────────────────────────────────────────────────

// Generate OBO authorization URL for user consent
// The user visits this URL, logs in, and approves the agent to act on their behalf
function generateOBOAuthUrl(string sessionId) returns string|error {
    string codeVerifier = generateCodeVerifier();
    string codeChallenge = generateCodeChallenge(codeVerifier);
    string state = uuid:createType4AsString();

    // Store pending auth keyed by state for callback processing
    pendingOBOAuths[state] = {
        codeVerifier: codeVerifier,
        sessionId: sessionId,
        createdAt: <decimal>time:utcNow()[0]
    };

    // Use the public (browser-facing) IS URL for consent — falls back to isBaseUrl if not set
    string browserIsUrl = isPublicUrl.length() > 0 ? isPublicUrl : isBaseUrl;
    // resource parameter (RFC 8707) tells IS to set aud claim to the API Resource identifier
    string authUrl = string `${browserIsUrl}/oauth2/authorize?response_type=code&client_id=${appClientId}&redirect_uri=${agentCallbackUrl}&scope=openid adr:flights:read adr:flights:write adr:recovery:manage adr:crew:read adr:passenger:read adr:logistics:read&state=${state}&code_challenge=${codeChallenge}&code_challenge_method=S256&requested_actor=${agentId}&resource=https%3A%2F%2Fadr.wso2.com%2Fapi`;
    log:printInfo(string `OBO consent URL generated for session ${sessionId}`);
    return authUrl;
}

// ── OBO Token Exchange ─────────────────────────────────────────────────────

// Exchange authorization code + agent token for OBO delegated token
function exchangeOBOToken(string code, string state) returns error? {
    OBOPendingAuth? pending = pendingOBOAuths[state];
    if pending is () {
        return error("No pending OBO authorization found for state: " + state);
    }

    string agentToken = check acquireAgentToken();
    http:Client isClient = check getIsClient();

    // Exchange code with actor_token (agent token) → OBO delegated JWT
    // resource parameter (RFC 8707) ensures the aud claim targets the API resource
    string tokenBody = string `grant_type=authorization_code&code=${code}&redirect_uri=${agentCallbackUrl}&client_id=${appClientId}&code_verifier=${pending.codeVerifier}&actor_token=${agentToken}&actor_token_type=urn:ietf:params:oauth:token-type:jwt&resource=https%3A%2F%2Fadr.wso2.com%2Fapi`;
    http:Request tokenReq = new;
    tokenReq.setTextPayload(tokenBody, contentType = "application/x-www-form-urlencoded");

    http:Response tokenResp = check isClient->post("/oauth2/token", tokenReq);
    json tokenJson = check tokenResp.getJsonPayload();

    // Check for error response (use map access since 'error' is a keyword)
    map<json> tokenMap = check tokenJson.ensureType();
    if tokenMap.hasKey("error") {
        string errorMsg = tokenMap["error"].toString();
        string desc = tokenMap.hasKey("error_description") ? tokenMap["error_description"].toString() : "unknown error";
        return error(string `OBO token exchange failed: ${errorMsg} - ${desc}`);
    }

    string accessToken = (check tokenJson.access_token).toString();
    int|error expiresIn = (check tokenJson.expires_in).ensureType(int);

    // Decode JWT payload to extract claims (act, sub, aut, etc.)
    string? userSub = ();

    // Try to extract user subject from token response
    json|error subField = tokenJson.sub;
    if subField is string {
        userSub = subField;
    }

    // Cache OBO token for this session
    sessionOBOTokens[pending.sessionId] = {
        accessToken: accessToken,
        expiresAt: <decimal>time:utcNow()[0] + <decimal>(expiresIn is int ? expiresIn : 3600),
        userSub: userSub
    };

    _ = pendingOBOAuths.remove(state);
    log:printInfo(string `OBO token acquired for session ${pending.sessionId}, user: ${userSub ?: "unknown"}`);
}

// ── OBO Token Retrieval ────────────────────────────────────────────────────

// Check if a valid (non-expired) OBO token exists for a session
function getSessionOBOToken(string sessionId) returns string? {
    CachedOBOToken? cached = sessionOBOTokens[sessionId];
    if cached is () {
        return ();
    }
    decimal now = <decimal>time:utcNow()[0];
    if now >= cached.expiresAt - 30d {
        _ = sessionOBOTokens.remove(sessionId);
        return ();
    }
    return cached.accessToken;
}
