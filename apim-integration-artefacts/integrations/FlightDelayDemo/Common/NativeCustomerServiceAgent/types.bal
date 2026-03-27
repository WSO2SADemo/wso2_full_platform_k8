// NativeCustomerServiceAgent — Type Definitions
// Shared types for OBO state and service request/response.

// ── OBO (On-Behalf-Of) Flow Types ──────────────────────────────────────────

// Tracks a pending OBO authorization (awaiting user consent callback).
type OBOPendingAuth record {|
    string codeVerifier;
    string sessionId;
    decimal createdAt;
|};

// Cached OBO token obtained after user consent.
type CachedOBOToken record {|
    string accessToken;
    decimal expiresAt;
    string? userSub;
|};

// ── Service Request/Response Types ─────────────────────────────────────────

// Chat request payload.
type ChatRequest record {|
    string message;
    string? session_id = ();
|};

// Chat response payload — extends standard ai:ChatRespMessage with auth fields.
type ChatResponse record {|
    string response;
    string? function_called = ();
    json? function_result = ();
    string? consent_url = ();
    string? session_id = ();
    string? agent_token = ();
    string? obo_token = ();
|};
