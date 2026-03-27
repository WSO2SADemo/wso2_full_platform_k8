// NativeCustomerServiceAgent — OBO (On-Behalf-Of) Flow
// Implements the WSO2 IS Agentic AI OBO flow per IETF draft-oauth-ai-agents-on-behalf-of-user.
// The agent authenticates itself, then obtains a delegated OBO token with user consent.
//
// Adapted from CustomerServiceAgent's obo_flow.bal.

import ballerina/crypto;
import ballerina/http;
import ballerina/log;
import ballerina/regex;
import ballerina/time;
import ballerina/uuid;

// ── OBO State ──────────────────────────────────────────────────────────────

string? cachedAgentToken = ();
decimal agentTokenExpiry = 0;
map<OBOPendingAuth> pendingOBOAuths = {};
map<CachedOBOToken> sessionOBOTokens = {};
boolean oboEnabled = false;
string agentCallbackUrl = "http://localhost:9098/cs/callback";
string? currentOBOToken = ();

// ── PKCE Helpers ───────────────────────────────────────────────────────────

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

// ── Agent Token Acquisition ────────────────────────────────────────────────

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
    string authBody = string `response_type=code&client_id=${appClientId}&scope=openid&redirect_uri=${agentCallbackUrl}&response_mode=direct&code_challenge=${agentCodeChallenge}&code_challenge_method=S256`;
    http:Request authReq = new;
    authReq.setTextPayload(authBody, contentType = "application/x-www-form-urlencoded");
    http:Response authResp = check isClient->post("/oauth2/authorize", authReq);
    json authJson = check authResp.getJsonPayload();

    json|error flowIdField = authJson.flowId;
    if flowIdField is error {
        string respStr = authJson.toJsonString();
        string preview = respStr.length() > 300 ? respStr.substring(0, 300) : respStr;
        return error(string `IS /oauth2/authorize did not return flowId (appClientId=${appClientId}). Response: ${preview}`);
    }
    string flowId = flowIdField.toString();

    // Step 2: Authenticate with agent credentials
    json authnPayload = {
        "flowId": flowId,
        "selectedAuthenticator": {
            "authenticatorId": "QmFzaWNBdXRoZW50aWNhdG9yOkxPQ0FM",
            "params": {"username": agentId, "password": agentSecret}
        }
    };
    http:Request authnReq = new;
    authnReq.setJsonPayload(authnPayload);
    http:Response authnResp = check isClient->post("/oauth2/authn", authnReq);
    json authnJson = check authnResp.getJsonPayload();
    json authData = check authnJson.authData;
    string authCode = (check authData.code).toString();

    // Step 3: Exchange code for agent token
    string tokenBody = string `grant_type=authorization_code&code=${authCode}&redirect_uri=${agentCallbackUrl}&client_id=${appClientId}&code_verifier=${agentCodeVerifier}`;
    http:Request tokenReq = new;
    tokenReq.setTextPayload(tokenBody, contentType = "application/x-www-form-urlencoded");
    http:Response tokenResp = check isClient->post("/oauth2/token", tokenReq);
    json tokenJson = check tokenResp.getJsonPayload();
    string accessToken = (check tokenJson.access_token).toString();
    int|error expiresIn = (check tokenJson.expires_in).ensureType(int);

    cachedAgentToken = accessToken;
    agentTokenExpiry = <decimal>time:utcNow()[0] + <decimal>(expiresIn is int ? expiresIn : 3600);
    log:printInfo("NativeCS Agent OBO agent token acquired successfully");

    return accessToken;
}

// ── OBO Authorization URL ──────────────────────────────────────────────────

function generateOBOAuthUrl(string sessionId) returns string|error {
    string codeVerifier = generateCodeVerifier();
    string codeChallenge = generateCodeChallenge(codeVerifier);
    string state = uuid:createType4AsString();

    pendingOBOAuths[state] = {
        codeVerifier: codeVerifier,
        sessionId: sessionId,
        createdAt: <decimal>time:utcNow()[0]
    };

    string browserIsUrl = isPublicUrl.length() > 0 ? isPublicUrl : isBaseUrl;
    string authUrl = string `${browserIsUrl}/oauth2/authorize?response_type=code&client_id=${appClientId}&redirect_uri=${agentCallbackUrl}&scope=openid adr:flights:read adr:passenger:read adr:logistics:read&state=${state}&code_challenge=${codeChallenge}&code_challenge_method=S256&requested_actor=${agentId}&resource=https%3A%2F%2Fadr.wso2.com%2Fapi`;
    log:printInfo(string `NativeCS Agent OBO consent URL generated for session ${sessionId}`);
    return authUrl;
}

// ── OBO Token Exchange ─────────────────────────────────────────────────────

function exchangeOBOToken(string code, string state) returns error? {
    OBOPendingAuth? pending = pendingOBOAuths[state];
    if pending is () {
        return error("No pending OBO authorization found for state: " + state);
    }

    string agentToken = check acquireAgentToken();
    http:Client isClient = check getIsClient();

    string tokenBody = string `grant_type=authorization_code&code=${code}&redirect_uri=${agentCallbackUrl}&client_id=${appClientId}&code_verifier=${pending.codeVerifier}&actor_token=${agentToken}&actor_token_type=urn:ietf:params:oauth:token-type:jwt&resource=https%3A%2F%2Fadr.wso2.com%2Fapi`;
    http:Request tokenReq = new;
    tokenReq.setTextPayload(tokenBody, contentType = "application/x-www-form-urlencoded");

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
    log:printInfo(string `NativeCS Agent OBO token acquired for session ${pending.sessionId}, user: ${userSub ?: "unknown"}`);
}

// ── OBO Token Retrieval ────────────────────────────────────────────────────

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
