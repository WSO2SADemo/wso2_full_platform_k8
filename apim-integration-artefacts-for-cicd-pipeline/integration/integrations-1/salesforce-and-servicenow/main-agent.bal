import ballerina/ai;
import ballerina/http;

// listener http:Listener fullfillmentAgentListener = new (aiPort);
listener ai:Listener fullfillmentAgentListener = new (aiPort);

@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"]
    }
}
service /orderAgent on fullfillmentAgentListener {
    resource function post chat(@http:Payload ai:ChatReqMessage request) returns ai:ChatRespMessage|error {
        string stringResult = check _fullfillmentAgentAgent.run(request.message, request.sessionId);
        return {message: stringResult};
    }
}