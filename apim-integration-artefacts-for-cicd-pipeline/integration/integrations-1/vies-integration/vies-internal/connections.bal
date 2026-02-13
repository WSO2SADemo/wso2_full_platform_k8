import ballerina/http;
import ballerinax/kafka;

// HTTP listener for receiving SAP-MDM requests
listener http:Listener sapMdmListener = new (servicePort);

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
