import ballerina/os;

configurable string rabbitmqHost = os:getEnv("rabbitmqHost");
configurable int rabbitmqPort = check int:fromString(os:getEnv("rabbitmqPort"));
configurable string rabbitmqUser = os:getEnv("RABBITMQ_USER");
configurable string rabbitmqPassword = os:getEnv("RABBITMQ_PASSWORD");
configurable string backendUrl = os:getEnv("backendUrl");
