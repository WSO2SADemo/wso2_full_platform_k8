import ballerina/http;
import ballerina/log;

listener http:Listener httpDefaultListener = http:getDefaultListener();

service /heartbeat on httpDefaultListener {
    resource function get status() returns json|error {

        do {
            json response = {
                status: "POC integration is running"
            };
            log:printInfo("Heartbeat endpoint called");
            log:printInfo("Response payload: " + response.toJsonString());
            return response;

        } on fail error err {
            // handle error
            return error("unhandled error", err);
        }
    }
}
