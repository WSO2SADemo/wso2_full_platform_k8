import ballerina/os;

// Configurable backend URLs – populated from K8s ConfigMap via env vars.
// Override locally with Config.toml.
configurable string customerServiceUrl = os:getEnv("customerServiceUrl");
configurable string pricingServiceUrl = os:getEnv("pricingServiceUrl");
configurable string purchaseServiceUrl = os:getEnv("purchaseServiceUrl");

// RabbitMQ connection – host/port from ConfigMap, credentials from Secret.
configurable string rabbitmqHost = os:getEnv("rabbitmqHost");
configurable int rabbitmqPort = check int:fromString(os:getEnv("rabbitmqPort"));
configurable string rabbitmqUser = os:getEnv("RABBITMQ_USER");
configurable string rabbitmqPassword = os:getEnv("RABBITMQ_PASSWORD");
