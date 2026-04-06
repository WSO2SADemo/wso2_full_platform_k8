// insurance_agent — OBO (On-Behalf-Of) Flow
// Adapted from FlightDelayDemo/Common/NativeCustomerServiceAgent/obo_flow.bal.
// Implements the WSO2 IS Agentic AI OBO flow per IETF draft-oauth-ai-agents-on-behalf-of-user.
// The agent authenticates itself, then obtains a delegated OBO token with user consent.

import ballerina/crypto;
import ballerina/http;
import ballerina/log;
import ballerina/regex;
import ballerina/time;
import ballerina/uuid;

// ── OBO Record Types ────────────────────────────────────────────────────────

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

// ── OBO State ───────────────────────────────────────────────────────────────

string? cachedAgentToken = ();
decimal agentTokenExpiry = 0;
map<OBOPendingAuth> pendingOBOAuths = {};
map<CachedOBOToken> sessionOBOTokens = {};
boolean oboEnabled = false;
// currentOBOToken: set in obo_chat before agent.run(); read by submitClaim via lock.
isolated string? currentOBOToken = ();
// oboConsentRequired: set true by submitClaim (via lock) when no OBO token is present.
// obo_chat checks this after agent.run() and returns a consent URL if true.
isolated boolean oboConsentRequired = false;

// ── IS HTTP Client ──────────────────────────────────────────────────────────

function getIsClient() returns http:Client|error {
    return new (oboIsBaseUrl,
        secureSocket = {cert: {path: truststorePath, password: truststorePassword}, verifyHostName: false}
    );
}

// ── PKCE Helpers ────────────────────────────────────────────────────────────

function generateCodeVerifier() returns string {
    string id1 = uuid:createType4AsString();
    string id2 = uuid:createType4AsString();
    string raw = regex:replaceAll(id1 + id2, "-", "");
    return raw.substring(0, 43);
}

function generateCodeChallenge(string verifier) returns string {
    byte[] hash = crypto:hashSha256(verifier.toBytes());
    string b64Str = hash.toBase64();
    string result = regex:replaceAll(b64Str, "\\+", "-");
    result = regex:replaceAll(result, "/", "_");
    result = regex:replaceAll(result, "=", "");
    return result;
}

// ── Agent Token Acquisition ─────────────────────────────────────────────────
// 3-step PKCE flow: authorize → authn → token exchange

function acquireAgentToken() returns string|error {
    if cachedAgentToken is string {
        decimal now = <decimal>time:utcNow()[0];
        if now < agentTokenExpiry - 30d {
            return <string>cachedAgentToken;
        }
    }

    http:Client isClient = check getIsClient();

    string agentCodeVerifier = generateCodeVerifier();
    string agentCodeChallenge = generateCodeChallenge(agentCodeVerifier);

    // Step 1: Authorize with response_mode=direct + PKCE
    // Client auth method is "code and client credentials" — Basic Auth required on all IS endpoints
    string clientCredentials = (agentAppClientId + ":" + agentAppClientSecret).toBytes().toBase64();
    string authBody = string `response_type=code&client_id=${agentAppClientId}&scope=openid&redirect_uri=${oboCallbackUrl}&response_mode=direct&code_challenge=${agentCodeChallenge}&code_challenge_method=S256`;
    http:Request authReq = new;
    authReq.setTextPayload(authBody, contentType = "application/x-www-form-urlencoded");
    authReq.setHeader("Authorization", string `Basic ${clientCredentials}`);
    http:Response authResp = check isClient->post("/oauth2/authorize", authReq);
    json authJson = check authResp.getJsonPayload();

    json|error flowIdField = authJson.flowId;
    if flowIdField is error {
        string respStr = authJson.toJsonString();
        string preview = respStr.length() > 300 ? respStr.substring(0, 300) : respStr;
        return error(string `IS /oauth2/authorize did not return flowId (agentAppClientId=${agentAppClientId}). Response: ${preview}`);
    }
    string flowId = flowIdField.toString();

    // Step 2: Authenticate with agent credentials (BasicAuthenticator)
    json authnPayload = {
        "flowId": flowId,
        "selectedAuthenticator": {
            "authenticatorId": "QmFzaWNBdXRoZW50aWNhdG9yOkxPQ0FM",
            "params": {"username": agentID, "password": agentSecret}
        }
    };
    http:Request authnReq = new;
    authnReq.setJsonPayload(authnPayload);
    http:Response authnResp = check isClient->post("/oauth2/authn", authnReq);
    json authnJson = check authnResp.getJsonPayload();
    json authData = check authnJson.authData;
    string authCode = (check authData.code).toString();

    // Step 3: Exchange code for agent access token
    string tokenBody = string `grant_type=authorization_code&code=${authCode}&redirect_uri=${oboCallbackUrl}&client_id=${agentAppClientId}&code_verifier=${agentCodeVerifier}`;
    http:Request tokenReq = new;
    tokenReq.setTextPayload(tokenBody, contentType = "application/x-www-form-urlencoded");
    tokenReq.setHeader("Authorization", string `Basic ${clientCredentials}`);
    http:Response tokenResp = check isClient->post("/oauth2/token", tokenReq);
    json tokenJson = check tokenResp.getJsonPayload();
    string accessToken = (check tokenJson.access_token).toString();
    int|error expiresIn = (check tokenJson.expires_in).ensureType(int);

    cachedAgentToken = accessToken;
    agentTokenExpiry = <decimal>time:utcNow()[0] + <decimal>(expiresIn is int ? expiresIn : 3600);
    log:printInfo(string `Insurance OBO: agent token acquired successfully — token: ${accessToken}`);

    return accessToken;
}

// ── OBO Authorization URL ───────────────────────────────────────────────────
// Generates a consent URL. The IS will redirect to oboCallbackUrl after the user approves.

function generateOBOAuthUrl(string sessionId) returns string|error {
    string codeVerifier = generateCodeVerifier();
    string codeChallenge = generateCodeChallenge(codeVerifier);
    string state = uuid:createType4AsString();

    pendingOBOAuths[state] = {
        codeVerifier: codeVerifier,
        sessionId: sessionId,
        createdAt: <decimal>time:utcNow()[0]
    };

    // Scopes: openid + ordinary_api_scope (getPolicy/getClaims) + privilege_api_scope (submitClaim)
    // requested_actor tells IS this is an agent-on-behalf-of-user request
    string authUrl = string `${oboIsBaseUrl}/oauth2/authorize?response_type=code&client_id=${agentAppClientId}&redirect_uri=${oboCallbackUrl}&scope=openid%20ordinary_customer_agent_scope%20privilege_customer_agent_scope&state=${state}&code_challenge=${codeChallenge}&code_challenge_method=S256&requested_actor=${agentID}`;
    log:printInfo(string `Insurance OBO: consent URL generated for session ${sessionId}`);
    return authUrl;
}

// ── OBO Token Exchange ──────────────────────────────────────────────────────
// Exchanges user authorization code + agent token for a delegated OBO JWT.

function exchangeOBOToken(string code, string state) returns error? {
    OBOPendingAuth? pending = pendingOBOAuths[state];
    if pending is () {
        return error("No pending OBO authorization found for state: " + state);
    }

    string agentToken = check acquireAgentToken();
    http:Client isClient = check getIsClient();

    string oboCredentials = (agentAppClientId + ":" + agentAppClientSecret).toBytes().toBase64();
    string tokenBody = string `grant_type=authorization_code&code=${code}&redirect_uri=${oboCallbackUrl}&client_id=${agentAppClientId}&code_verifier=${pending.codeVerifier}&actor_token=${agentToken}&actor_token_type=urn:ietf:params:oauth:token-type:jwt`;
    http:Request tokenReq = new;
    tokenReq.setTextPayload(tokenBody, contentType = "application/x-www-form-urlencoded");
    tokenReq.setHeader("Authorization", string `Basic ${oboCredentials}`);

    http:Response tokenResp = check isClient->post("/oauth2/token", tokenReq);
    json tokenJson = check tokenResp.getJsonPayload();

    map<json> tokenMap = check tokenJson.ensureType();
    if tokenMap.hasKey("error") {
        string errorMsg = tokenMap["error"].toString();
        string desc = tokenMap.hasKey("error_description") ? tokenMap["error_description"].toString() : "unknown error";
        return error(string `OBO token exchange failed: ${errorMsg} - ${desc}`);
    }

    string accessToken = (check tokenJson.access_token).toString();
    int|error expiresIn = (check tokenJson.expires_in).ensureType(int);

    string? userSub = ();
    json|error subField = tokenJson.sub;
    if subField is string {
        userSub = subField;
    }

    sessionOBOTokens[pending.sessionId] = {
        accessToken: accessToken,
        expiresAt: <decimal>time:utcNow()[0] + <decimal>(expiresIn is int ? expiresIn : 3600),
        userSub: userSub
    };

    _ = pendingOBOAuths.remove(state);
    log:printInfo(string `Insurance OBO: delegated token acquired for session ${pending.sessionId}, user: ${userSub ?: "unknown"}`);
}

// ── OBO Token Retrieval ─────────────────────────────────────────────────────
// Returns the cached OBO token for the session, or () if missing/expired.

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
