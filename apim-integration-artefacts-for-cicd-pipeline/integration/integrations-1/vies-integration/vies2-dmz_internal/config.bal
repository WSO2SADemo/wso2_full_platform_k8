import ballerina/os;

// Internal Kafka configuration (for internalKafkaTopic)
configurable string internalKafkaBootstrapServers = os:getEnv("kafkaBootstrapServers");
configurable string internalKafkaTopic = os:getEnv("internalKafkaTopic");
configurable string internalKafkaTopicResponse = os:getEnv("internalKafkaTopicResponse");
configurable string internalKafkaConsumerGroupId = os:getEnv("internalKafkaConsumerGroupId");
configurable string internalKafkaCaCertPath = "/home/ballerina/resources/ca.pem";
configurable string internalKafkaClientCertPath = "/home/ballerina/resources/service.cert";
configurable string internalKafkaClientKeyPath = "/home/ballerina/resources/service.key";

// External Kafka configuration (for externalKafkaTopic and externalKafkaTopicResponse)
configurable string externalKafkaBootstrapServers = os:getEnv("externalKafkaBootstrapServers");
configurable string externalKafkaTopic = os:getEnv("externalKafkaTopic");
configurable string externalKafkaTopicResponse = os:getEnv("externalKafkaTopicResponse");
configurable string externalKafkaCaCertPath = "/home/ballerina/external-resources/external_ca.pem";
configurable string externalKafkaClientCertPath = "/home/ballerina/external-resources/external_service.cert";
configurable string externalKafkaClientKeyPath = "/home/ballerina/external-resources/external_service.key";