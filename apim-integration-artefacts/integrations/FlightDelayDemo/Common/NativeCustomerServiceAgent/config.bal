// NativeCustomerServiceAgent — Configuration
// All configurable variables for the service.

// ── MCP Server Configuration ───────────────────────────────────────────────
// MCP Server URLs — two MCP servers (one per source API) via APIM gateway.
// APIM's generate-from-api only registers one source API per MCP server,
// so we use two servers: DisruptionMCP (4 tools) + PassengerMCP (10 tools).
configurable string mcpServerUrl = "";    // DisruptionMCP (flights, disruptions)
configurable string mcpServerUrl2 = "";   // PassengerMCP (bookings, passengers, rebook)

// MCP API Key — legacy, kept for backward compat (OAuth2 Bearer is now used instead)
configurable string mcpApiKey = "";

// OAuth2 credentials for MCP gateway auth (client_credentials grant for Bearer token)
configurable string mcpOauthConsumerKey = "";
configurable string mcpOauthConsumerSecret = "";

// ── JWT / Access Control ───────────────────────────────────────────────────
// JWKS endpoint for JWT validation (from WSO2 IS)
configurable string jwksUrl = "https://localhost:9444/oauth2/jwks";

// Allowed groups for CS Agent access (from JWT 'groups' claim)
configurable string[] allowedGroups = ["adr_operators"];

// ── WSO2 Identity Server — OBO Flow ────────────────────────────────────────
configurable string agentId = "";
configurable string agentSecret = "";
configurable string appClientId = "";
configurable string isBaseUrl = "";
configurable string isPublicUrl = "";

// ── Service Configuration ──────────────────────────────────────────────────
configurable int servicePort = 9098;

// ── Legacy LLM config keys — kept so existing Config.toml files don't break ──
configurable string aillmModel = "";
configurable string aillmServiceUrl = "";
configurable string aiGatewayToken = "";
