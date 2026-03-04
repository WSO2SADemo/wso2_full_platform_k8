import ballerina/http;
import ballerina/ai;
// import ballerinax/wso2.apim.catalog as _;
// import ballerinax/moesif as _;


listener http:Listener insurance_agentListener = new (port = 9090);

service /insurance_agent on insurance_agentListener {
    private final ai:Agent insurance_agentAgent;

    function init() returns error? {
        self.insurance_agentAgent = check new (
            systemPrompt = {role: string ``, instructions: string ``}, model = insurance_agentModel, tools = [aiInsuraceCustomerMcpbasetoolkit]
            // systemPrompt = {role: string ``, instructions: string ``}, model = insurance_agentModel, tools = [aiInsuranceAgentMcpbasetoolkit, aiInsuraceCustomerMcpbasetoolkit]

        );
    }

    resource function post chat(@http:Payload ai:ChatReqMessage request) returns ai:ChatRespMessage|error {
        string stringResult = check self.insurance_agentAgent.run(request.message, request.sessionId);
        return {message: stringResult};
    }
}
