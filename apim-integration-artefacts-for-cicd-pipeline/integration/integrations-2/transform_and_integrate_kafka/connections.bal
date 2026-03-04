import ballerina/http;
import ballerinax/kafka;

final kafka:Producer kafkaProducer = check new ("kafka-b48cc93efa334420a155bc653b4d46be-ramindud637853112-choreo.d.aivencloud.com:24903", secureSocket = {
    cert: caCertPath,
    key: {
        certFile: accessCertPath,
        keyFile: accessKeyPath
    }
}, securityProtocol = kafka:PROTOCOL_SSL);
final http:Client httpClient = check new ("http://localhost:9094/employee/details", retryConfig = {
    count: 5,
    interval: 5
});
