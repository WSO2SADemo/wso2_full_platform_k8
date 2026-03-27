// NativeCustomerServiceAgent — Connections
// AI model provider and shared HTTP clients.

import ballerina/ai;
import ballerina/http;

// ── AI Model Provider (WSO2 AI Gateway / Ballerina Copilot) ────────────────
final ai:Wso2ModelProvider NativeCustomerServiceAgentModel = check ai:getDefaultModelProvider();

// ── WSO2 Identity Server HTTP Client (shared for OBO + token endpoints) ────
http:Client? isClientRef = ();

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

