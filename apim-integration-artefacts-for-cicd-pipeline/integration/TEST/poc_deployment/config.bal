import ballerina/os;
configurable string environment_type = os:getEnv("ENVIRONMENT");