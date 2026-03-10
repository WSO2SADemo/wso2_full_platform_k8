import ballerina/os;

// Configurable backend URLs – populated from K8s ConfigMap via env vars.
// Override locally with Config.toml.
configurable string customerServiceUrl = os:getEnv("customerServiceUrl");
configurable string pricingServiceUrl = os:getEnv("pricingServiceUrl");
configurable string purchaseServiceUrl = os:getEnv("purchaseServiceUrl");
