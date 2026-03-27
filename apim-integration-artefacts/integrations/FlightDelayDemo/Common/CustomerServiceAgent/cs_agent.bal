// Customer Service Copilot — MCP-Direct Service (No LLM)
// Routes user requests directly to MCP tools discovered from APIM CustomerServiceMCP gateway.
// All tool calls are authorized with OBO (On-Behalf-Of) delegated tokens.
//
// Related files:
//   mcp_client.bal — MCP tool discovery & execution (dynamic tool loading)
//   obo_flow.bal   — On-Behalf-Of delegated identity flow (WSO2 IS integration)

import ballerina/http;
import ballerina/jwt;
import ballerina/log;
import ballerina/uuid;

// ── Configuration ──────────────────────────────────────────────────────────

// MCP Server URLs — two MCP servers (one per source API) via APIM gateway.
// APIM's generate-from-api only registers one source API per MCP server,
// so we use two servers: DisruptionMCP (4 tools) + PassengerMCP (10 tools).
configurable string mcpServerUrl = "";   // DisruptionMCP (flights, disruptions)
configurable string mcpServerUrl2 = "";  // PassengerMCP (bookings, passengers, rebook)

// MCP API Key — legacy, kept for backward compat (OAuth2 Bearer is now used instead)
configurable string mcpApiKey = "";

// OAuth2 credentials for MCP gateway auth (client_credentials grant for Bearer token)
// These are the CustomerServiceCopilot app's OAuth keys from APIM key manager (IS)
configurable string mcpOauthConsumerKey = "";
configurable string mcpOauthConsumerSecret = "";

// JWKS endpoint for JWT validation (from WSO2 IS)
configurable string jwksUrl = "https://localhost:9444/oauth2/jwks";

// Allowed groups for CS Copilot access (from JWT 'groups' claim).
// Only adr_operators can use this agent — admins should use the Admin Recovery Agent.
configurable string[] allowedGroups = ["adr_operators"];

// WSO2 Identity Server — AI Agent On-Behalf-Of (OBO) flow configuration
configurable string agentId = "";
configurable string agentSecret = "";
configurable string appClientId = "";
configurable string isBaseUrl = "";
configurable string isPublicUrl = "";

// Legacy LLM config keys — kept so existing Config.toml files don't cause startup errors
configurable string aillmModel = "";
configurable string aillmServiceUrl = "";
configurable string aiGatewayToken = "";

// ── Chat request / response types ──────────────────────────────────────────
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

// ── Tool routing — maps user intent keywords to MCP tool names + arg extraction ─

type ToolRoute record {|
    string toolName;
    string[] keywords;         // any of these in the message triggers this tool
    string? argName;           // if set, extract a value from the message into this arg
    string? argPattern;        // regex-ish pattern hint (not used at runtime — doc only)
|};

// Routes are evaluated top-to-bottom; first match wins.
// These are built dynamically at startup from discovered MCP tools.
ToolRoute[] toolRoutes = [];

// Build default routes based on discovered tool names
function buildToolRoutes() {
    ToolRoute[] routes = [];
    foreach string name in mcpToolNames {
        // Build keyword list from tool name (camelCase → words)
        string lower = name.toLowerAscii();
        string[] kws = [lower, name];

        // Map well-known tool names to natural-language keywords
        if lower == "getflights" || lower == "getallflights" {
            kws = ["flights", "flight status", "all flights", "flight list", "delayed flights", "getflights"];
        } else if lower == "getflightbyid" {
            kws = ["flight id", "flight details", "specific flight", "getflightbyid"];
        } else if lower == "getactivedisruptions" {
            kws = ["disruption", "disruptions", "delays", "delay", "cancelled", "getactivedisruptions"];
        } else if lower == "getpassengerbyid" {
            kws = ["passenger", "traveler", "pax", "getpassengerbyid"];
        } else if lower == "getbookingsbypassenger" || lower == "getbookingsbyflight" {
            kws = ["booking", "bookings", "reservation", "reservations", name.toLowerAscii()];
        } else if lower == "getalternativeflights" {
            kws = ["alternative", "alternatives", "rebook option", "rebooking option", "getalternativeflights"];
        } else if lower == "evaluaterebook" {
            kws = ["evaluate", "recommend", "rebooking recommendation", "evaluaterebook"];
        } else if lower == "rebookpassenger" {
            kws = ["rebook", "rebooking", "change flight", "rebookpassenger"];
        } else if lower == "processcompensation" {
            kws = ["compensation", "compensate", "refund", "processcompensation"];
        } else if lower == "notifypassenger" {
            kws = ["notify", "notification", "send message", "notifypassenger"];
        }

        // Determine argument extraction based on tool name
        string? argName = ();
        if lower.includes("byid") || lower.includes("passenger") {
            argName = "id";
        } else if lower.includes("byflight") {
            argName = "flightId";
        }

        routes.push({toolName: name, keywords: kws, argName: argName, argPattern: ()});
    }
    toolRoutes = routes;
}

// Match a user message to a tool route
function matchToolRoute(string message) returns [ToolRoute, map<json>]? {
    string lower = message.toLowerAscii();
    foreach ToolRoute route in toolRoutes {
        foreach string kw in route.keywords {
            if lower.includes(kw.toLowerAscii()) {
                map<json> args = {};
                // Try to extract argument value from the message
                if route.argName is string {
                    string? extracted = extractArgValue(message);
                    if extracted is string {
                        args[<string>route.argName] = extracted;
                    }
                }
                return [route, args];
            }
        }
    }
    return ();
}

// Extract an ID-like value from a message (e.g. "P001", "FL001", "B001")
function extractArgValue(string message) returns string? {
    // Look for patterns like P001, FL001, B001, etc.
    string[] words = split(message);
    foreach string word in words {
        string w = word.trim();
        // Match ID patterns: uppercase letter(s) followed by digits
        if w.length() >= 2 && w.length() <= 10 {
            boolean hasLetter = false;
            boolean hasDigit = false;
            foreach string:Char c in w {
                if c >= "A" && c <= "Z" {
                    hasLetter = true;
                } else if c >= "0" && c <= "9" {
                    hasDigit = true;
                }
            }
            if hasLetter && hasDigit {
                return w;
            }
        }
    }
    return ();
}

// Simple string split by spaces
function split(string s) returns string[] {
    string[] result = [];
    string current = "";
    foreach string:Char c in s {
        if c == " " || c == "," || c == "." || c == "?" || c == "!" {
            if current.length() > 0 {
                result.push(current);
                current = "";
            }
        } else {
            current = current + c;
        }
    }
    if current.length() > 0 {
        result.push(current);
    }
    return result;
}

// ── CS Agent Service ───────────────────────────────────────────────────────
listener http:Listener csAgentListener = new (9097, timeout = 300);

// CORS configuration for browser-based dashboard access (direct invocation)
@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowMethods: ["GET", "POST", "OPTIONS"],
        allowHeaders: ["Content-Type", "Authorization"],
        exposeHeaders: ["Content-Type"],
        maxAge: 84900
    }
}
service /cs on csAgentListener {

    function init() {
        log:printInfo("CS Copilot initializing — MCP-direct mode (no LLM)");

        // Initialize MCP clients — connects to multiple MCP servers via APIM gateway
        // Two servers: DisruptionMCP (4 tools) + PassengerMCP (10 tools)
        string[] mcpUrls = [];
        if mcpServerUrl.length() > 0 {
            mcpUrls.push(mcpServerUrl);
        }
        if mcpServerUrl2.length() > 0 {
            mcpUrls.push(mcpServerUrl2);
        }
        if mcpUrls.length() > 0 {
            error? mcpResult = initializeAllMcpClients(mcpUrls);
            if mcpResult is error {
                log:printError("Failed to initialize MCP clients", mcpResult);
            } else {
                log:printInfo(string `MCP integration active — ${mcpToolFunctions.length()} tools from ${mcpConnections.length()} server(s)`);
                // Build keyword→tool routing table from discovered tools
                buildToolRoutes();
                log:printInfo(string `Tool routes built for ${toolRoutes.length()} tools`);
            }
        } else {
            log:printInfo("MCP not configured — no server URLs provided");
        }

        // Initialize OBO flow if agent credentials are configured
        if agentId.length() > 0 && agentSecret.length() > 0 && appClientId.length() > 0 && isBaseUrl.length() > 0 {
            oboEnabled = true;
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
    }

    // POST /cs/chat — MCP-direct customer service interface
    resource function post chat(http:Request req, @http:Payload ChatRequest request) returns ChatResponse|http:Forbidden|http:Unauthorized|error {
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
        log:printInfo(string `CS Agent received: ${request.message} from user: ${userSub}`);

        // Reset OBO token for this request
        currentOBOToken = ();

        // OBO: Generate or retrieve session ID
        string sessionId = request.session_id ?: uuid:createType4AsString();

        // OBO: Check if delegated token is available for this session
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

        // Set OBO Bearer token for MCP tool calls through APIM gateway
        if currentOBOToken is string {
            setMcpOboToken(currentOBOToken);
            log:printInfo(string `MCP calls: using OBO Bearer token (length=${(<string>currentOBOToken).length()})`);
        }

        // ── MCP-direct tool routing (no LLM) ──────────────────────────────
        if !mcpEnabled || mcpToolNames.length() == 0 {
            return {
                response: "No MCP tools available. The CustomerServiceMCP server may not be connected.",
                session_id: sessionId,
                agent_token: cachedAgentToken,
                obo_token: currentOBOToken
            };
        }

        // Match the user message to a tool
        [ToolRoute, map<json>]? matched = matchToolRoute(request.message);

        if matched is () {
            // No tool matched — list available tools
            string toolList = "";
            foreach int i in 0 ..< mcpToolNames.length() {
                toolList = toolList + "\n• **" + mcpToolNames[i] + "**";
                // Add description from mcpToolFunctions if available
                if i < mcpToolFunctions.length() {
                    string? desc = mcpToolFunctions[i].description;
                    if desc is string && desc.length() > 0 {
                        toolList = toolList + " — " + desc;
                    }
                }
            }
            return {
                response: string `I couldn't match your request to a specific tool. Here are the available operations:${toolList}\n\nTry asking about specific flights, passengers, bookings, disruptions, or rebooking options.`,
                session_id: sessionId,
                agent_token: cachedAgentToken,
                obo_token: currentOBOToken
            };
        }

        [ToolRoute, map<json>] matchResult = matched;
        ToolRoute route = matchResult[0];
        map<json> args = matchResult[1];
        log:printInfo(string `Tool routed: ${route.toolName} with args: ${args.toJsonString()}`);

        // Execute the matched MCP tool
        json toolResult = executeMcpTool(route.toolName, args);
        log:printInfo(string `Tool ${route.toolName} executed successfully`);

        // Format the response
        string responseText = formatToolResult(route.toolName, toolResult);

        return {
            response: responseText,
            function_called: route.toolName,
            function_result: toolResult,
            session_id: sessionId,
            agent_token: cachedAgentToken,
            obo_token: currentOBOToken
        };
    }

    // GET /cs/callback — OBO flow callback
    resource function get callback(string? code = (), string? state = ()) returns http:Response|error {
        log:printInfo(string `CS Agent OBO callback: code=${code ?: "null"}, state=${state ?: "null"}`);

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

        resp.setPayload("<html><body><h2>Authorization Successful</h2><p>You have authorized the Customer Service Copilot to act on your behalf.</p><p>This window will close automatically...</p><script>if(window.opener){window.opener.postMessage({type:'obo_authorized'},'*');}setTimeout(function(){window.close();},1500);</script></body></html>");
        resp.setHeader("Content-Type", "text/html");
        return resp;
    }

    // GET /cs/health — Health check
    resource function get health() returns json {
        string toolMode = mcpEnabled
            ? string `MCP-direct (${mcpToolFunctions.length()} tools from ${mcpConnections.length()} MCP server(s))`
            : "no tools";
        return {
            status: "running",
            agent: "Customer Service Copilot",
            mode: "MCP-direct (no LLM)",
            tool_discovery: toolMode,
            mcp_enabled: mcpEnabled,
            mcp_servers: mcpConnections.length(),
            obo_enabled: oboEnabled,
            obo_sessions: sessionOBOTokens.length()
        };
    }
}

// ── Tool result formatting ────────────────────────────────────────────────
function formatToolResult(string toolName, json result) returns string {
    // Check for error
    json|error errField = result.'error;
    if errField is string {
        return string `Error executing ${toolName}: ${errField}`;
    }

    string lower = toolName.toLowerAscii();

    // ── Flights list ──────────────────────────────────────────────────────
    if lower == "getflights" || lower == "getallflights" {
        return formatFlightsList(result);
    }

    // ── Single flight details ─────────────────────────────────────────────
    if lower == "getflightbyid" {
        return formatSingleFlight(result);
    }

    // ── Active disruptions ────────────────────────────────────────────────
    if lower == "getactivedisruptions" {
        return formatDisruptions(result);
    }

    // ── Passenger details ─────────────────────────────────────────────────
    if lower == "getpassengerbyid" {
        return formatPassenger(result);
    }

    // ── Bookings ──────────────────────────────────────────────────────────
    if lower.includes("booking") {
        return formatBookings(result);
    }

    // ── Alternative flights ───────────────────────────────────────────────
    if lower.includes("alternative") {
        return formatAlternatives(result);
    }

    // ── Rebook result ─────────────────────────────────────────────────────
    if lower == "rebookpassenger" {
        return formatRebookResult(result);
    }

    // ── Evaluate rebook ───────────────────────────────────────────────────
    if lower == "evaluaterebook" {
        return formatEvaluateRebook(result);
    }

    // ── Compensation ──────────────────────────────────────────────────────
    if lower.includes("compensation") {
        return formatCompensation(result);
    }

    // ── Notification ──────────────────────────────────────────────────────
    if lower.includes("notify") {
        return formatNotification(result);
    }

    // ── Passenger history ─────────────────────────────────────────────────
    if lower.includes("history") {
        return formatPassengerHistory(result);
    }

    // ── Flight seats ──────────────────────────────────────────────────────
    if lower.includes("seat") {
        return formatFlightSeats(result);
    }

    // Fallback: generic
    string resultStr = result.toJsonString();
    if resultStr.length() > 3000 {
        resultStr = resultStr.substring(0, 3000) + "... (truncated)";
    }
    return string `**${toolName}** result:\n\n${resultStr}`;
}

// ── Individual formatters ─────────────────────────────────────────────────

function formatFlightsList(json result) returns string {
    json[]|error arr = result.ensureType();
    if arr is error {
        return "No flight data available.";
    }
    string output = string `**✈️ Flight Status Overview** — ${arr.length()} flights found\n\n`;
    foreach json f in arr {
        string flightId = getStr(f, "flight_id");
        string flightNum = getStr(f, "flight_number");
        string airline = getStr(f, "airline");
        string origin = getStr(f, "origin");
        string dest = getStr(f, "destination");
        string status = getStr(f, "status");
        string gate = getStr(f, "gate");
        int pax = getInt(f, "passenger_count");
        string statusIcon = status == "DELAYED" ? "🔴" : (status == "CANCELLED" ? "⛔" : (status == "AVAILABLE" ? "🟢" : "🟡"));
        output += string `${statusIcon} **${flightNum}** (${flightId}) — ${airline}
   ${origin} → ${dest} | Gate: ${gate} | Status: **${status}** | Passengers: ${pax}
`;
    }
    return output;
}

function formatSingleFlight(json result) returns string {
    string flightId = getStr(result, "flight_id");
    string flightNum = getStr(result, "flight_number");
    string airline = getStr(result, "airline");
    string origin = getStr(result, "origin");
    string dest = getStr(result, "destination");
    string status = getStr(result, "status");
    string gate = getStr(result, "gate");
    string aircraft = getStr(result, "aircraft_type");
    string schedDep = getStr(result, "scheduled_departure");
    string schedArr = getStr(result, "scheduled_arrival");
    int pax = getInt(result, "passenger_count");

    return string `**✈️ Flight ${flightNum}** (${flightId}) — ${airline}

📍 Route: ${origin} → ${dest}
🕐 Departure: ${schedDep}
🕐 Arrival: ${schedArr}
🛫 Status: **${status}**
🚪 Gate: ${gate}
🛩️ Aircraft: ${aircraft}
👥 Passengers: ${pax}
💺 Seats — First: ${getInt(result, "seats_first")}, Business: ${getInt(result, "seats_business")}, Premium Economy: ${getInt(result, "seats_premium_economy")}, Economy: ${getInt(result, "seats_economy")}`;
}

function formatDisruptions(json result) returns string {
    json[]|error arr = result.ensureType();
    if arr is error {
        return "No active disruptions found. ✅";
    }
    if arr.length() == 0 {
        return "**✅ No Active Disruptions** — All flights are operating normally.";
    }
    string output = string `**⚠️ Active Disruptions** — ${arr.length()} disruption(s)\n\n`;
    foreach json d in arr {
        string flightId = getStr(d, "flight_id");
        string dtype = getStr(d, "disruption_type");
        int delayMin = getInt(d, "delay_minutes");
        string severity = getStr(d, "severity");
        string reason = getStr(d, "reason");
        string status = getStr(d, "status");
        string sevIcon = severity == "HIGH" ? "🔴" : (severity == "MEDIUM" ? "🟠" : "🟡");
        output += string `${sevIcon} **${flightId}** — ${dtype}
   Delay: ${delayMin} min | Severity: **${severity}** | Reason: ${reason} | Status: ${status}
`;
    }
    return output;
}

function formatPassenger(json result) returns string {
    // Check if this is a "not found" message
    json|error msgField = result.message;
    if msgField is string {
        return string `**👤 Passenger Not Found**\n\n${msgField}`;
    }

    string paxId = getStr(result, "passenger_id");
    string firstName = getStr(result, "first_name");
    string lastName = getStr(result, "last_name");
    string email = getStr(result, "email");
    string phone = getStr(result, "phone");
    string tier = getStr(result, "loyalty_tier");
    int points = getInt(result, "loyalty_points");
    string needs = getStr(result, "special_needs");

    string tierIcon = tier == "PLATINUM" ? "💎" : (tier == "GOLD" ? "🥇" : (tier == "SILVER" ? "🥈" : "🎫"));

    string output = string `**👤 Passenger: ${firstName} ${lastName}** (${paxId})

${tierIcon} Loyalty: **${tier}** — ${points} points
📧 Email: ${email}
📱 Phone: ${phone}`;
    if needs != "" && needs != "null" {
        output += string `
♿ Special Needs: ${needs}`;
    }
    return output;
}

function formatBookings(json result) returns string {
    json[]|error arr = result.ensureType();
    if arr is error {
        return "No booking data available.";
    }
    if arr.length() == 0 {
        return "**📋 No Bookings Found** — No bookings match the query.";
    }
    string output = string `**📋 Bookings** — ${arr.length()} booking(s)\n\n`;
    foreach json b in arr {
        string bookingId = getStr(b, "booking_id");
        string paxId = getStr(b, "passenger_id");
        string firstName = getStr(b, "first_name");
        string lastName = getStr(b, "last_name");
        string flightId = getStr(b, "flight_id");
        string seat = getStr(b, "seat_number");
        string cls = getStr(b, "booking_class");
        string status = getStr(b, "status");
        string tier = getStr(b, "loyalty_tier");
        string name = (firstName != "" && lastName != "") ? string `${firstName} ${lastName}` : paxId;
        output += string `• **${bookingId}** — ${name} (${tier})
   Flight: ${flightId} | Seat: ${seat} | Class: ${cls} | Status: ${status}
`;
    }
    return output;
}

function formatAlternatives(json result) returns string {
    json[]|error arr = result.ensureType();
    if arr is error {
        return "No alternative flights available.";
    }
    if arr.length() == 0 {
        return "**🔍 No Alternative Flights** — No alternatives found for this route.";
    }
    string output = string `**🔍 Alternative Flights** — ${arr.length()} option(s)\n\n`;
    foreach json f in arr {
        string flightId = getStr(f, "flight_id");
        string flightNum = getStr(f, "flight_number");
        string origin = getStr(f, "origin");
        string dest = getStr(f, "destination");
        string schedDep = getStr(f, "scheduled_departure");
        string status = getStr(f, "status");

        // Handle both simple and detailed alternative formats
        json|error seatClasses = f.seat_classes;
        if seatClasses is json[] {
            int totalAvail = getInt(f, "total_available_seats");
            string seatInfo = "";
            foreach json sc in seatClasses {
                string scName = getStr(sc, "seat_class");
                int avail = getInt(sc, "available_seats");
                if avail > 0 {
                    seatInfo += string `${scName}: ${avail} `;
                }
            }
            output += string `✈️ **${flightNum}** (${flightId}) — ${origin} → ${dest}
   Departure: ${schedDep} | Status: ${status} | Available: ${totalAvail} seats (${seatInfo.trim()})
`;
        } else {
            int availSeats = getInt(f, "available_seats");
            output += string `✈️ **${flightNum}** (${flightId}) — ${origin} → ${dest}
   Departure: ${schedDep} | Status: ${status} | Available seats: ${availSeats}
`;
        }
    }
    return output;
}

function formatRebookResult(json result) returns string {
    string paxName = getStr(result, "passenger_name");
    string paxId = getStr(result, "passenger_id");
    string origFlight = getStr(result, "original_flight_id");
    string newFlight = getStr(result, "new_flight_id");
    string newBooking = getStr(result, "new_booking_id");
    string cls = getStr(result, "booking_class");
    string tier = getStr(result, "loyalty_tier");
    string status = getStr(result, "status");
    string msg = getStr(result, "message");
    json|error seatConfirmed = result.seat_confirmed;
    string seatStatus = (seatConfirmed is boolean && seatConfirmed) ? "✅ Confirmed" : "⚠️ Waitlisted";

    return string `**🔄 Rebooking Complete**

👤 Passenger: ${paxName} (${paxId}) — ${tier}
❌ Original flight: ${origFlight}
✈️ New flight: ${newFlight}
🎫 New booking: ${newBooking}
💺 Class: ${cls} | Seat: ${seatStatus}
📊 Status: **${status}**
💬 ${msg}`;
}

function formatEvaluateRebook(json result) returns string {
    string paxName = getStr(result, "passenger_name");
    string paxId = getStr(result, "passenger_id");
    string tier = getStr(result, "loyalty_tier");
    string origFlight = getStr(result, "original_flight_id");
    string recommendation = getStr(result, "recommendation");
    string compReason = getStr(result, "compensation_reason");

    string output = string `**📊 Rebooking Evaluation** for ${paxName} (${paxId})

🎫 Loyalty: ${tier} | Original flight: ${origFlight}
💡 Recommendation: ${recommendation}
`;

    json|error compNeeded = result.compensation_needed;
    if compNeeded is boolean && compNeeded {
        output += string `💰 Compensation needed: ${compReason}
`;
    }

    json|error options = result.options;
    if options is json[] && options.length() > 0 {
        output += "\n**Available Options:**\n";
        foreach json opt in options {
            string fId = getStr(opt, "flight_id");
            string fNum = getStr(opt, "flight_number");
            string dep = getStr(opt, "scheduled_departure");
            string recClass = getStr(opt, "recommended_class");
            int availInClass = getInt(opt, "available_in_class");
            string priority = getStr(opt, "priority_score");
            output += string `• **${fNum}** (${fId}) — Departs: ${dep} | Class: ${recClass} (${availInClass} seats) | Priority: ${priority}
`;
        }
    }
    return output;
}

function formatCompensation(json result) returns string {
    string paxName = getStr(result, "passenger_name");
    string paxId = getStr(result, "passenger_id");
    string tier = getStr(result, "loyalty_tier");
    string flightId = getStr(result, "flight_id");
    string reasoning = getStr(result, "reasoning");

    json|error totalField = result.total_value;
    string totalVal = "0.00";
    if totalField is decimal {
        totalVal = totalField.toString();
    } else if totalField is int|float {
        totalVal = totalField.toString();
    } else if totalField is json {
        totalVal = totalField.toString();
    }

    string output = string `**💰 Compensation Processed**

👤 ${paxName} (${paxId}) — ${tier}
✈️ Flight: ${flightId}
💵 Total compensation: **$${totalVal}**
📝 Reasoning: ${reasoning}
`;

    json|error comps = result.compensations;
    if comps is json[] && comps.length() > 0 {
        output += "\n**Breakdown:**\n";
        foreach json c in comps {
            string cType = getStr(c, "compensation_type");
            string desc = getStr(c, "description");
            json|error amtField = c.amount;
            string amt = amtField is json ? amtField.toString() : "0";
            string currency = getStr(c, "currency");
            output += string `• ${cType}: ${currency} ${amt} — ${desc}
`;
        }
    }
    return output;
}

function formatNotification(json result) returns string {
    string paxName = getStr(result, "passenger_name");
    string paxId = getStr(result, "passenger_id");
    string nType = getStr(result, "notification_type");
    string status = getStr(result, "status");
    string msg = getStr(result, "message");
    string nId = getStr(result, "notification_id");

    return string `**📨 Notification Sent**

👤 To: ${paxName} (${paxId})
📧 Type: ${nType}
📊 Status: **${status}**
💬 Message: ${msg}
🔖 ID: ${nId}`;
}

function formatPassengerHistory(json result) returns string {
    json[]|error arr = result.ensureType();
    if arr is error {
        return "No history records found.";
    }
    if arr.length() == 0 {
        return "**📜 No History** — No flight history found for this passenger.";
    }
    string output = string `**📜 Passenger Flight History** — ${arr.length()} record(s)\n\n`;
    foreach json h in arr {
        string action = getStr(h, "action");
        string flightId = getStr(h, "flight_id");
        string bookingId = getStr(h, "booking_id");
        string seatClass = getStr(h, "seat_class");
        string seatNum = getStr(h, "seat_number");
        string notes = getStr(h, "notes");
        string createdAt = getStr(h, "created_at");
        output += string `• **${action}** — Flight: ${flightId} | Booking: ${bookingId} | ${seatClass} ${seatNum} | ${createdAt}`;
        if notes != "" && notes != "null" {
            output += string ` — ${notes}`;
        }
        output += "\n";
    }
    return output;
}

function formatFlightSeats(json result) returns string {
    string flightId = getStr(result, "flight_id");
    int totalCap = getInt(result, "total_capacity");
    int totalBooked = getInt(result, "total_booked");
    int totalAvail = getInt(result, "total_available");

    string output = string `**💺 Seat Availability — Flight ${flightId}**

Total capacity: ${totalCap} | Booked: ${totalBooked} | Available: **${totalAvail}**

`;

    json|error classes = result.classes;
    if classes is json[] {
        foreach json c in classes {
            string cls = getStr(c, "seat_class");
            int total = getInt(c, "total_seats");
            int booked = getInt(c, "booked_seats");
            int avail = getInt(c, "available_seats");
            string bar = avail > 0 ? "🟢" : "🔴";
            output += string `${bar} **${cls}**: ${avail} available (${booked}/${total} booked)
`;
        }
    }
    return output;
}

// ── JSON field extraction helpers ─────────────────────────────────────────

function getStr(json obj, string key) returns string {
    map<json>|error m = obj.ensureType();
    if m is error {
        return "";
    }
    json? val = m[key];
    if val is () {
        return "";
    }
    string s = val.toString();
    return s == "null" ? "" : s;
}

function getInt(json obj, string key) returns int {
    map<json>|error m = obj.ensureType();
    if m is error {
        return 0;
    }
    json? val = m[key];
    if val is () {
        return 0;
    }
    int|error i = val.ensureType();
    if i is int {
        return i;
    }
    return 0;
}

// ── Helper function for JWT validation ────────────────────────────────────
function validateJwtAndRoles(string jwtToken) returns map<anydata>|error {
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

    // If groups not found in JWT, fetch from IS userinfo endpoint
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

    // Try 1: userinfo endpoint (works when app has groups claim configured)
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

        // Try 2: SCIM — look up user's groups by sub (user ID) from userinfo
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

// Fetch user groups from IS SCIM2 API — used when userinfo doesn't return groups
function fetchUserGroupsBySCIM(string userId) returns string[]|error {
    http:Client isClient = check getIsClient();
    string scimUrl = string `/scim2/Users/${userId}`;
    // Use admin auth for SCIM (demo environment)
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
