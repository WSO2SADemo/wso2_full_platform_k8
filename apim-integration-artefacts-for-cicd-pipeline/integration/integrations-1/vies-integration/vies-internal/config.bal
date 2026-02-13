import ballerina/os;
// Configuration for the service
configurable int servicePort = 8080;

// Kafka configuration
configurable string kafkaBootstrapServers = os:getEnv("kafkaBootstrapServers");
configurable string internalKafkaTopic = os:getEnv("internalKafkaTopic");
configurable string internalKafkaTopicResponse = os:getEnv("internalKafkaTopicResponse");
configurable string kafkaCaCertPath = "/home/ballerina/resources/ca.pem";
configurable string kafkaClientCertPath = "/home/ballerina/resources/service.cert";
configurable string kafkaClientKeyPath = "/home/ballerina/resources/service.key";