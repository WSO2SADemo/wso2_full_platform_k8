import ballerina/http;
import ballerina/log;

// This will get the value from Kubernetes ConfigMap (or env var)
configurable string ENVIRONMENT = ?;

listener http:Listener httpDefaultListener = http:getDefaultListener();

service /heartbeat on httpDefaultListener {
    resource function get status() returns json|error {
        do {
            json response = {
                status: "POC integration is running",
                test: "test",
                environment: ENVIRONMENT   // <-- added this
            };
            log:printInfo("Heartbeat endpoint called");
            log:printInfo("Response payload: " + response.toJsonString());
            return response;

        } on fail error err {
            return error("unhandled error", err);
        }
    }
}