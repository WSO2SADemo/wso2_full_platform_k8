import ballerina/http;

// HTTP clients for backend services
final http:Client mockApiClient = check new (mockApiBaseUrl);
