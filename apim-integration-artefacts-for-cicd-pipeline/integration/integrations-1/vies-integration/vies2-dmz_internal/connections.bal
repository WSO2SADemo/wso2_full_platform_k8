import ballerinax/kafka;

// Kafka producer for external topic with SSL configuration
final kafka:Producer externalKafkaProducer = check new (externalKafkaBootstrapServers, {
    securityProtocol: kafka:PROTOCOL_SSL,
    secureSocket: {
        cert: externalKafkaCaCertPath,
        key: {
            certFile: externalKafkaClientCertPath,
            keyFile: externalKafkaClientKeyPath
        }
    }
});

// Kafka producer for internal response topic with SSL configuration
final kafka:Producer internalKafkaProducer = check new (internalKafkaBootstrapServers, {
    securityProtocol: kafka:PROTOCOL_SSL,
    secureSocket: {
        cert: internalKafkaCaCertPath,
        key: {
            certFile: internalKafkaClientCertPath,
            keyFile: internalKafkaClientKeyPath
        }
    }
});

// Kafka listener for internal topic with SSL configuration
listener kafka:Listener internalKafkaListener = check new (
    bootstrapServers = internalKafkaBootstrapServers,
    groupId = "internalKafkaConsumerGroupId",
    topics = internalKafkaTopic,
    securityProtocol = kafka:PROTOCOL_SSL,
    secureSocket = {
        cert: internalKafkaCaCertPath,
        key: {
            certFile: internalKafkaClientCertPath,
            keyFile: internalKafkaClientKeyPath
        }
    }
);

