import ballerina/http;

// OAS client for Cash Registries to push data
final http:Client oasClient = check new ("http://localhost:9092");
