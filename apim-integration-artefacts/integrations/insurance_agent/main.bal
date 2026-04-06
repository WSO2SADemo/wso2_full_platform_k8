import ballerina/ai;
import ballerina/http;
import ballerina/io;
import ballerina/log;

// import ballerinax/wso2.apim.catalog as _;
// import ballerinax/moesif as _;

listener http:Listener insurance_agentListener = new (port = 9090);

service /insurance_agent on insurance_agentListener {
    private final ai:Agent privilege_insurance_agent;
    private final ai:Agent insurance_agent;

    function init() returns error? {
        log:printInfo("Initializing Insurance Agent Service");
        // http:Response|error customerHealth = customerBackend->get("/health");
        // if customerHealth is error {
        //     log:printWarn("Insurance customer backend health check failed", 'error = customerHealth);
        // } else {
        //     log:printInfo("Insurance customer backend health check passed", statusCode = customerHealth.statusCode);
        // }

        // http:Response|error agentHealth = agentBackend->get("/insurance/agent/health");
        // if agentHealth is error {
        //     log:printWarn("Insurance agent backend health check failed", 'error = agentHealth);
        // } else {
        //     log:printInfo("Insurance agent backend health check passed", statusCode = agentHealth.statusCode);
        // }

        // self.privilege_insurance_agent = check new (
        //     systemPrompt = {role: string ``, instructions: string ``}, model = mistralModelprovider, tools = [aiInsuraceCustomerMcpbasetoolkit, aiInsuranceAgentMcpbasetoolkit], credential = {id: privilegedAgentID, secret: privilegedAgentSecret}
        // );
        self.insurance_agent = check new (
            systemPrompt = {role: string ``, instructions: string ``}, credential = {id: agentID, secret: agentSecret}, model = mistralModelprovider, tools = [aiInsuraceCustomerMcpbasetoolkit, aiInsuranceAgentMcpbasetoolkit, getPolicyInfoFromVectorDB]
        );
        // self.insurance_agent = check new (
        //     systemPrompt = {role: string ``, instructions: string ``}, credential = {id: agentID, secret: agentSecret}, model = mistralModelprovider, tools = [aiInsuraceCustomerMcpbasetoolkit, aiInsuranceAgentMcpbasetoolkit]
        // );
    }

    resource function get health() returns http:Ok {
        io:println("Health check received at /insurance_agent/health");
        return {body: {status: "UP"}};
    }

    resource function post chat(@http:Payload ai:ChatReqMessage request) returns ai:ChatRespMessage|error {
        string stringResult = check self.insurance_agent.run(request.message, request.sessionId);
        return {message: stringResult};
    }

    // resource function post privilege_chat(@http:Payload ai:ChatReqMessage request) returns ai:ChatRespMessage|error {
    //     string stringResult = check self.privilege_insurance_agent.run(request.message, request.sessionId);
    //     return {message: stringResult};
    // }

}
