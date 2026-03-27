import ballerina/ai;
import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerina/mcp;

isolated class AiInsuranceAgentMcpbasetoolkit {
    *ai:McpBaseToolKit;
    private final mcp:StreamableHttpClient mcpClient;
    private final readonly & ai:ToolConfig[] tools;

    // public isolated function init(string serverUrl, mcp:Implementation info = {name: "MCP", version: "1.0.0"},
    //         *mcp:StreamableHttpClientTransportConfig config) returns ai:Error? {
    //     do {
    //         self.mcpClient = check new mcp:StreamableHttpClient(serverUrl, config);
    //         self.tools = check ai:getPermittedMcpToolConfigs(self.mcpClient, info, self.callTool).cloneReadOnly();
    //     } on fail error e {
    //         return error ai:Error("Failed to initialize MCP toolkit", e);
    //     }
    // }

    public isolated function init(string serverUrl, mcp:Implementation info = {name: "MCP", version: "1.0.0"},
            *ai:StreamableHttpClientTransportConfig config) returns ai:Error? {
        do {
            ai:StreamableHttpClientTransportConfig {auth, ...configs} = config;
            mcp:StreamableHttpClientTransportConfig mcpConfig = {...configs};
            ai:AgentIdAuthConfig? agentIdAuth = ();
            if auth is http:ClientAuthConfig {
                mcpConfig.auth = auth;
                auth = ();
            } else {
                agentIdAuth = auth;
            }
            self.mcpClient = check new mcp:StreamableHttpClient(serverUrl, mcpConfig);
            // self.tools = check ai:getPermittedMcpToolConfigs(self.mcpClient, info, permittedTools, agentIdAuth).cloneReadOnly();
            self.tools = check ai:getPermittedMcpToolConfigs(self.mcpClient, info, self.callTool2, agentIdAuth).cloneReadOnly();
            io:println("AiInsuranceAgentMcpbasetoolkit initialized with tools:");
            io:println(self.tools);
        } on fail error e {
            log:printError("Error initializing MCP toolkit", e);
            return error ai:Error("Failed to initialize MCP toolkit", e);
        }

    }

    @ai:AgentTool {
        auth: {
            scopes: ["privilege_api_scope", "ordinary_api_scope"]
        }
    }
    public isolated function callTool2(ai:Context ctx, mcp:CallToolParams params) returns mcp:CallToolResult|error {
        // return self.mcpClient->callTool(params);
        io:println("Getting GET TOOLS acccess token: " + string ` ${check ctx.getAccessToken(params.name)}`);
        return self.mcpClient->callTool(params, headers = {"Authorization": string `Bearer ${check ctx.getAccessToken(params.name)}`});
    }

    public isolated function getTools() returns ai:ToolConfig[] => self.tools;

}

isolated class AiInsuraceCustomerMcpbasetoolkit {
    *ai:McpBaseToolKit;
    private final mcp:StreamableHttpClient mcpClient;
    private final readonly & ai:ToolConfig[] tools;

    public isolated function init(string serverUrl, mcp:Implementation info = {name: "MCP", version: "1.0.0"},
            *ai:StreamableHttpClientTransportConfig config) returns ai:Error? {
        final map<ai:FunctionTool> permittedTools = {
            "submitClaim": self.submitClaim,
            "getPolicy": self.getPolicy,
            "getClaims": self.getClaims
        };
        do {
            ai:StreamableHttpClientTransportConfig {auth, ...configs} = config;
            mcp:StreamableHttpClientTransportConfig mcpConfig = {...configs};
            ai:AgentIdAuthConfig? agentIdAuth = ();
            if auth is http:ClientAuthConfig {
                mcpConfig.auth = auth;
                auth = ();
            } else {
                agentIdAuth = auth;
            }
            self.mcpClient = check new mcp:StreamableHttpClient(serverUrl, mcpConfig);
            self.tools = check ai:getPermittedMcpToolConfigs(self.mcpClient, info, permittedTools, agentIdAuth).cloneReadOnly();
            io:println("AiInsuraceCustomerMcpbasetoolkit initialized with tools:");
            io:println(self.tools);
        } on fail error e {
            log:printError("Error initializing MCP toolkit", e);
            return error ai:Error("Failed to initialize MCP toolkit", e);
        }
    }

    public isolated function getTools() returns ai:ToolConfig[] => self.tools;

    @ai:AgentTool {
        auth: {
            scopes: ["privilege_customer_agent_scope"]
        }
    }
    public isolated function submitClaim(ai:Context ctx, mcp:CallToolParams params) returns mcp:CallToolResult|error {
        // return self.mcpClient->callTool(params);
        io:println("Getting SUBMIT acccess token: " + string ` ${check ctx.getAccessToken(params.name)}`);
        return self.mcpClient->callTool(params, headers = {"Authorization": string `Bearer ${check ctx.getAccessToken(params.name)}`});
    }

    @ai:AgentTool {
        auth: {
            scopes: ["ordinary_customer_agent_scope"]
        }
    }
    public isolated function getPolicy(ai:Context ctx, mcp:CallToolParams params) returns mcp:CallToolResult|error {
        io:println("Getting POLICY acccess token: " + string ` ${check ctx.getAccessToken(params.name)}`);
        return self.mcpClient->callTool(params, headers = {"Authorization": string `Bearer ${check ctx.getAccessToken(params.name)}`});
    }

    @ai:AgentTool {
        auth: {
            scopes: ["ordinary_customer_agent_scope"]
        }
    }
    public isolated function getClaims(ai:Context ctx, mcp:CallToolParams params) returns mcp:CallToolResult|error {
        io:println("Getting CLAIM acccess token: " + string ` ${check ctx.getAccessToken(params.name)}`);
        return self.mcpClient->callTool(params, headers = {"Authorization": string `Bearer ${check ctx.getAccessToken(params.name)}`});
    }
}

final ai:Agent aiAgent = check new (
    systemPrompt = {role: string ``, instructions: string ``}, model = mistralModelprovider
);

@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function getPolicyInfoFromVectorDB(string query) returns string|error {
    string|error result = queryVectorDBInformation(query);
    return result;
}
