// Custom AI Model Provider — routes LLM calls through WSO2 APIM AI Gateway
// Implements ai:ModelProvider with Ollama-compatible /api/chat format
// Authenticates using OBO Bearer token (preferred) or ApiKey fallback.

import ballerina/ai;
import ballerina/http;
import ballerina/log;

# AI Model Provider that calls Ollama (directly or via APIM AI Gateway).
# Prefers OBO Bearer token for APIM auth; falls back to ApiKey if no Bearer token is set.
isolated client class ApimOllamaProvider {

    private final http:Client httpClient;
    private final string modelType;
    private final string apiKey;
    // Per-request Bearer token (set via setAuthToken before each chat call)
    private string? authToken = ();

    # Initializes the provider.
    #
    # + modelType - Ollama model name (e.g. "llama3.2:1b")
    # + serviceUrl - Base URL of Ollama or APIM AI Gateway (e.g. "https://apim:8246/ollama/1.0.0")
    # + apiKey - APIM API Key (empty string = no auth, direct Ollama)
    # + timeout - HTTP timeout in seconds (default 120 for LLM inference)
    # + secureSocket - SSL config for HTTPS (use {enable: false} for self-signed certs)
    # + return - Error if HTTP client creation fails
    isolated function init(string modelType, string serviceUrl, string apiKey = "",
            decimal timeout = 120, http:ClientSecureSocket? secureSocket = ()) returns error? {
        self.httpClient = check new (serviceUrl,
            timeout = timeout,
            secureSocket = secureSocket
        );
        self.modelType = modelType;
        self.apiKey = apiKey;
    }

    # Sets a per-request Bearer token (OBO token) for APIM authentication.
    # Call this before each `chat` invocation. Pass `()` to clear.
    #
    # + token - OAuth2 Bearer token (OBO delegated token) or nil to clear
    isolated function setAuthToken(string? token) {
        lock {
            self.authToken = token;
        }
    }

    # Sends a chat request to the Ollama model (via APIM if configured).
    #
    # + messages - Chat messages or a single user message
    # + tools - Tool definitions for function calling
    # + stop - Stop sequence (unused by Ollama, included for interface compat)
    # + return - Assistant response with optional tool calls, or error
    isolated remote function chat(ai:ChatMessage[]|ai:ChatUserMessage messages,
            ai:ChatCompletionFunctions[] tools = [],
            string? stop = ()) returns ai:ChatAssistantMessage|ai:Error {

        // Convert typed messages to Ollama JSON format
        json[] ollamaMessages = self.convertMessages(messages);

        // Build Ollama /api/chat request payload
        map<json> payload = {
            "model": self.modelType,
            "messages": ollamaMessages,
            "stream": false
        };
        if tools.length() > 0 {
            json[] ollamaTools = from ai:ChatCompletionFunctions t in tools
                select <json>{
                    "type": "function",
                    "function": {
                        "name": t.name,
                        "description": t.description,
                        "parameters": t.parameters ?: {}
                    }
                };
            payload["tools"] = ollamaTools;
        }

        // Call /api/chat — prefer OBO Bearer token, then ApiKey, then no auth
        json|http:ClientError resp;
        string? bearerToken;
        lock {
            bearerToken = self.authToken;
        }
        if bearerToken is string && bearerToken.length() > 0 {
            log:printInfo("LLM call: using OBO Bearer token (length=" + bearerToken.length().toString() + ")");
            resp = self.httpClient->post("/api/chat", payload, {"Authorization": "Bearer " + bearerToken});
        } else if self.apiKey.length() > 0 {
            log:printInfo("LLM call: using ApiKey fallback (length=" + self.apiKey.length().toString() + ")");
            resp = self.httpClient->post("/api/chat", payload, {"ApiKey": self.apiKey});
        } else {
            log:printInfo("LLM call: No auth configured, calling directly");
            resp = self.httpClient->post("/api/chat", payload);
        }
        if resp is http:ClientError {
            log:printError("LLM call failed", 'error = resp);
            return error ai:Error("Error calling LLM service", resp);
        }
        log:printInfo("LLM call succeeded");

        // Parse Ollama response into typed ChatAssistantMessage
        return self.parseResponse(resp);
    }

    // ── Message conversion: ai:ChatMessage[] → Ollama JSON format ──────────

    private isolated function convertMessages(ai:ChatMessage[]|ai:ChatUserMessage messages)
            returns json[] {
        json[] result = [];
        if messages is ai:ChatUserMessage {
            result.push({"role": "user", "content": self.contentToString(messages.content)});
            return result;
        }
        foreach ai:ChatMessage msg in messages {
            if msg is ai:ChatSystemMessage {
                result.push({"role": "system", "content": self.contentToString(msg.content)});
            } else if msg is ai:ChatUserMessage {
                result.push({"role": "user", "content": self.contentToString(msg.content)});
            } else if msg is ai:ChatAssistantMessage {
                map<json> assistantMsg = {"role": "assistant", "content": msg.content ?: ""};
                ai:FunctionCall[]? toolCalls = msg.toolCalls;
                if toolCalls is ai:FunctionCall[] && toolCalls.length() > 0 {
                    json[] ollamaToolCalls = from ai:FunctionCall tc in toolCalls
                        select <json>{
                            "function": {
                                "name": tc.name,
                                "arguments": tc.arguments ?: {}
                            }
                        };
                    assistantMsg["tool_calls"] = ollamaToolCalls;
                }
                result.push(assistantMsg);
            } else if msg is ai:ChatFunctionMessage {
                result.push({"role": "tool", "content": msg.content ?: ""});
            }
        }
        return result;
    }

    // ── Response parsing: Ollama JSON → ai:ChatAssistantMessage ────────────

    private isolated function parseResponse(json resp) returns ai:ChatAssistantMessage|ai:Error {
        json|error messageResult = resp.message;
        if messageResult is error {
            return error ai:Error("Invalid Ollama response: missing 'message' field", messageResult);
        }
        json messageJson = messageResult;

        string content = "";
        json|error contentResult = messageJson.content;
        if contentResult is json && !(contentResult is ()) {
            content = contentResult.toString();
        }

        // Check for tool_calls in response
        json|error toolCallsResult = messageJson.tool_calls;
        if toolCallsResult is json[] && toolCallsResult.length() > 0 {
            ai:FunctionCall[] toolCalls = [];
            foreach json tc in toolCallsResult {
                json|error fnResult = tc.'function;
                if fnResult is error {
                    continue;
                }
                string fnName = "";
                json|error nameResult = fnResult.name;
                if nameResult is json && !(nameResult is ()) {
                    fnName = nameResult.toString();
                }
                map<json> fnArgs = {};
                json|error argsResult = fnResult.arguments;
                if argsResult is map<json> {
                    fnArgs = argsResult;
                }
                toolCalls.push({name: fnName, arguments: fnArgs});
            }
            if toolCalls.length() > 0 {
                return {role: ai:ASSISTANT, toolCalls};
            }
        }

        return {role: ai:ASSISTANT, content};
    }

    // ── Utility ────────────────────────────────────────────────────────────

    private isolated function contentToString(string|ai:Prompt content) returns string {
        if content is string {
            return content;
        }
        // Handle Prompt (raw template) type — concatenate template parts
        string[] strings = content.strings;
        anydata[] insertions = content.insertions;
        string result = strings[0];
        foreach int i in 0 ..< insertions.length() {
            result += insertions[i].toString() + strings[i + 1];
        }
        return result;
    }
}
