// NativeCustomerServiceAgent - MCP Toolkit Utilities
// Helper functions for creating ai:McpToolKit instances
// that connect to APIM MCP Gateway for tool discovery and execution.
//
// The native ai:McpToolKit handles the full MCP protocol lifecycle:
//   - Server connection and initialization
//   - Tool discovery (tools/list)
//   - Tool execution (tools/call)
//   - Auth via http:ClientConfiguration

import ballerina/ai;
import ballerina/http;
import ballerina/log;

// -- MCP State Tracking --
boolean mcpEnabled = false;
int mcpServerCount = 0;
int mcpToolCount = 0;

// Create an ai:McpToolKit for a given MCP server URL with appropriate auth.
// Returns nil if creation fails (logged as warning, not fatal).
function createMcpToolKit(string serverUrl) returns ai:McpToolKit|error {
    log:printInfo("Creating McpToolKit for "" +
"
    // Build auth config for APIM gateway (OAuth2 client_credentials)
    boolean hasAuth = mcpOauthConsumerKey.length() > 0 && mcpOauthConsumerSecret.length() > 0 && isBaseUrl.length() > 0;
    http:OAuth2ClientCredentialsGrantConfig oauth2Config = {
        tokenUrl: isBaseUrl + "/oauth2/token",
        clientId: mcpOauthConsumerKey,
        clientSecret: mcpOauthConsumerSecret
    };
    if hasAuth {
        log:printInfo("MCP auth: OAuth2 client_credentials configured"" +
    }"

    // Create the MCP toolkit with appropriate config
    ai:McpToolKit toolkit;
    if serverUrl.startsWith("https://") {
        if hasAuth {
            toolkit = check new (
                serverUrl,
                info = {name: "NativeCustomerServiceAgent", version: "1.0.0"},
                auth = oauth2Config,
                timeout = 30,
                secureSocket = {enable: false}
            );
        } else {
            toolkit = check new (
                serverUrl,
                info = {name: "NativeCustomerServiceAgent", version: "1.0.0"},
                timeout = 30,
                secureSocket = {enable: false}
            );
        }
    } else {
        if hasAuth {
            toolkit = check new (
                serverUrl,
                info = {name: "NativeCustomerServiceAgent", version: "1.0.0"},
                auth = oauth2Config,
                timeout = 30
            );
        } else {
            toolkit = check new (
                serverUrl,
                info = {name: "NativeCustomerServiceAgent", version: "1.0.0"},
                timeout = 30
            );
        }
    }

    ai:ToolConfig[] discoveredTools = toolkit.getTools();
    string[] toolNames = from ai:ToolConfig t in discoveredTools select t.name;
    log:printInfo(string `McpToolKit created - discovered ${discoveredTools.length()} tools`);
    if toolNames.length() > 0 {
        log:printInfo("Discovered tools: " + ", ".join(...toolNames));
    }

    mcpToolCount += discoveredTools.length();
    mcpServerCount += 1;
    mcpEnabled = true;

    return toolkit;
}

// Create McpToolKit instances for all configured MCP server URLs.
// Returns an array of successfully created toolkits (may be empty).
function createAllMcpToolKits() returns ai:McpToolKit[] {
    ai:McpToolKit[] toolkits = [];

    string[] urls = [];
    if mcpServerUrl.length() > 0 {
        urls.push(mcpServerUrl);
    }
    if mcpServerUrl2.length() > 0 {
        urls.push(mcpServerUrl2);
    }

    if urls.length() == 0 {
        log:printInfo("MCP not configured - no server URLs provided");
        return toolkits;
    }

    foreach string url in urls {
        ai:McpToolKit|error toolkit = createMcpToolKit(url);
        if toolkit is error {
            log:printError("Failed to create McpToolKit for " + url, toolkit);
        } else {
            toolkits.push(toolkit);
        }
    }

    if toolkits.length() > 0 {
        log:printInfo(string `MCP integration active - ${mcpToolCount} tools from ${mcpServerCount} server(s)`);
    } else {
        log:printWarn("No MCP toolkits could be created");
    }

    return toolkits;
}
