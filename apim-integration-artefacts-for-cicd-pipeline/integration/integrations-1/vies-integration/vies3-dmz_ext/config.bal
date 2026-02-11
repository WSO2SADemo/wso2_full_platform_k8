import ballerina/os;
// Configuration for the service
configurable int servicePort = 8080;

// VIES service endpoint
configurable string viesServiceUrl = os:getEnv("viesServiceUrl");

// Kafka configuration
configurable string kafkaBootstrapServers = os:getEnv("kafkaBootstrapServers");
configurable string kafkaTopic1 = os:getEnv("kafkaTopic1");
configurable string kafkaTopic2 = os:getEnv("kafkaTopic2");
configurable string kafkaConsumerGroupId = os:getEnv("kafkaConsumerGroupId");
configurable string kafkaCaCertPath = "/home/ballerina/resources/ca.pem";
configurable string kafkaClientCertPath = "/home/ballerina/resources/service.cert";
configurable string kafkaClientKeyPath = "/home/ballerina/resources/service.key";