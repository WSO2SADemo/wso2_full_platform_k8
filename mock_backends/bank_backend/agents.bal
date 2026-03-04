// import ballerina/ai;
// import ballerina/mcp;
// import ballerina/log;
// import ballerina/io;

// isolated class AiMcpbasetoolkit {
//     *ai:McpBaseToolKit;
//     private final mcp:StreamableHttpClient mcpClient;
//     private final readonly & ai:ToolConfig[] tools;

//     public isolated function init(string serverUrl, mcp:Implementation info = {name: "MCP", version: "1.0.0"},
//             *mcp:StreamableHttpClientTransportConfig config) returns ai:Error? {
//         do {
//             self.mcpClient = check new mcp:StreamableHttpClient(serverUrl, config);
//             self.tools = check ai:getPermittedMcpToolConfigs(self.mcpClient, info, self.callTool).cloneReadOnly();
//         } on fail error e {
//             log:printError("Error initializing MCP toolkit: " , e);
//             io:println(e.stackTrace());
//             return error ai:Error("Failed to initialize MCP toolkit", e);
//         }
//     }

//     public isolated function getTools() returns ai:ToolConfig[] => self.tools;

//     @ai:AgentTool
//     public isolated function callTool(mcp:CallToolParams params) returns mcp:CallToolResult|error {
//         return self.mcpClient->callTool(params);
//     }
// }
