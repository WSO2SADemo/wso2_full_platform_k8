// Initialization logic for ADR Admin Agent
// All tools are discovered exclusively via MCP (APIM MCP Gateway) — no hardcoded tools.

import ballerina/log;

function init() {
    log:printInfo(string `ADR Admin Agent initialized — model=${aillmModel}`);

    // Initialize MCP client (tool discovery via APIM MCP Gateway) — REQUIRED
    if mcpServerUrl.length() > 0 {
        error? mcpResult = initializeMcpClient();
        if mcpResult is error {
            log:printError("MCP initialization failed — agent will have NO tools available", mcpResult);
        }
    } else {
        log:printError("mcpServerUrl not configured — agent will have NO tools available");
    }

    // Initialize OBO flow if agent credentials are configured
    if agentId.length() > 0 && agentSecret.length() > 0 && appClientId.length() > 0 && isBaseUrl.length() > 0 {
        oboEnabled = true;
        log:printInfo(string `OBO flow enabled — agentId=${agentId}, IS=${isBaseUrl}`);
        string|error agentTokenResult = acquireAgentToken();
        if agentTokenResult is error {
            log:printError("Failed to pre-acquire agent token (will retry on first request)", agentTokenResult);
        } else {
            log:printInfo("Agent token pre-acquired successfully");
        }
    } else {
        log:printInfo("OBO flow disabled — agent credentials not configured");
    }
}
