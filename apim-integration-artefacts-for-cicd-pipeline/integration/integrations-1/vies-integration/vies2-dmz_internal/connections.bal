import ballerina/http;
import ballerinax/kafka;

// HTTP listener for receiving SAP-MDM requests
listener http:Listener sapMdmListener = new (servicePort);

// HTTP client for VIES SOAP service
final http:Client viesClient = check new (viesServiceUrl, {timeout: 30});

// Kafka producer with SSL configuration
final kafka:Producer kafkaProducer = check new (kafkaBootstrapServers, {
    securityProtocol: kafka:PROTOCOL_SSL,
    secureSocket: {
        cert: kafkaCaCertPath,
        key: {
            certFile: kafkaClientCertPath,
            keyFile: kafkaClientKeyPath
        }
    }
});

// Kafka producer for topic 2 with SSL configuration
final kafka:Producer kafkaProducerTopic2 = check new (kafkaBootstrapServers, {
    securityProtocol: kafka:PROTOCOL_SSL,
    secureSocket: {
        cert: kafkaCaCertPath,
        key: {
            certFile: kafkaClientCertPath,
            keyFile: kafkaClientKeyPath
        }
    }
});

// Kafka listener for topic 1 with SSL configuration
listener kafka:Listener kafkaListenerTopic1 = check new (
    bootstrapServers = kafkaBootstrapServers,
    groupId = kafkaConsumerGroupId,
    topics = kafkaTopic1,
    securityProtocol = kafka:PROTOCOL_SSL,
    secureSocket = {
        cert: kafkaCaCertPath,
        key: {
            certFile: kafkaClientCertPath,
            keyFile: kafkaClientKeyPath
        }
    }
);

// Kafka listener for topic 2 with SSL configuration
listener kafka:Listener kafkaListenerTopic2 = check new (
    bootstrapServers = kafkaBootstrapServers,
    groupId = kafkaConsumerGroupId + "_topic2",
    topics = kafkaTopic2,
    securityProtocol = kafka:PROTOCOL_SSL,
    secureSocket = {
        cert: kafkaCaCertPath,
        key: {
            certFile: kafkaClientCertPath,
            keyFile: kafkaClientKeyPath
        }
    }
);
