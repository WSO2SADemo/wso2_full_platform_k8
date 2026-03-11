import ballerina/http;
import ballerina/log;

listener http:Listener httpDefaultListener = http:getDefaultListener();

service /heartbeat on httpDefaultListener {

    // Original status endpoint
    resource function get status() returns json|error {
        do {
            json response = {
                status: "POC integration is running for my testing purposes",
                Environment: environment_type
            };
            log:printInfo("Heartbeat endpoint called");
            log:printInfo("Response payload: " + response.toJsonString());
            return response;

        } on fail error err {
            return error("unhandled error", err);
        }
    }

    // New statusV2 endpoint
    // resource function get statusV2() returns json|error {
    //     do {
    //         json response = {
    //             status: "POC integration is running for my testing purposes from statusV2",
    //             Environment: environment_type
    //         };
    //         log:printInfo("Heartbeat V2 endpoint called");
    //         log:printInfo("Response payload: " + response.toJsonString());
    //         return response;

    //     } on fail error err {
    //         return error("unhandled error", err);
    //     }
    // }
}