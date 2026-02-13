import ballerina/http;
import ballerinax/kafka;

// HTTP client for VIES SOAP service
final http:Client viesClient = check new (viesServiceUrl, {timeout: 30});

// Kafka listener for topic 2 with SSL configuration
listener kafka:Listener kafkaListenerTopic2 = check new (
    bootstrapServers = kafkaBootstrapServers,
    groupId = "group1",
    topics = externalKafkaTopic,
    securityProtocol = kafka:PROTOCOL_SSL,
    secureSocket = {
        cert: kafkaCaCertPath,
        key: {
            certFile: kafkaClientCertPath,
            keyFile: kafkaClientKeyPath
        }
    }
);

// Kafka producer for sending responses to external topic
final kafka:Producer kafkaProducerResponse = check new (
    bootstrapServers = kafkaBootstrapServers,
    securityProtocol = kafka:PROTOCOL_SSL,
    secureSocket = {
        cert: kafkaCaCertPath,
        key: {
            certFile: kafkaClientCertPath,
            keyFile: kafkaClientKeyPath
        }
    }
);
