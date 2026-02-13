import ballerina/os;
// Configuration for the service
configurable int servicePort = 8080;

// VIES service endpoint
configurable string viesServiceUrl = os:getEnv("viesServiceUrl");

// Kafka configuration
configurable string kafkaBootstrapServers = os:getEnv("kafkaBootstrapServers");
configurable string externalKafkaTopic = os:getEnv("externalKafkaTopic");
configurable string externalKafkaTopicResponse = os:getEnv("externalKafkaTopicResponse");
configurable string kafkaCaCertPath = "/home/ballerina/external-resources/external_ca.pem";
configurable string kafkaClientCertPath = "/home/ballerina/external-resources/external_service.cert";
configurable string kafkaClientKeyPath = "/home/ballerina/external-resources/external_service.key";