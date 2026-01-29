import ballerina/os;
// Configuration for the service
configurable int servicePort = 8080;

// VIES service endpoint
configurable string viesServiceUrl = os:getEnv("viesServiceUrl");
