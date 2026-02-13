import ballerina/http;
import ballerina/log;
// import ballerinax/wso2.apim.catalog as _;
// import ballerinax/moesif as _;
import ballerinax/kafka;
import ballerina/uuid;
import ballerina/lang.runtime;

function init() {
    log:printInfo("VIES Internal service initializing...");
}

// Service to receive SAP-MDM requests and forward to Kafka
service /sapToKafka on sapMdmListener {

    // Resource to validate VAT number
    resource function post checkVat(@http:Payload SapMdmVatRequest request) returns SapMdmVatResponse|http:InternalServerError|error {
        log:printInfo("Received VAT validation request", countryCode = request.countryCode, vatNumber = request.vatNumber);
        
        // Generate UUID for this request
        string requestUuid = uuid:createType1AsString();
        log:printInfo("Generated UUID for request", uuid = requestUuid);
        
        // Transform SAP-MDM request to VIES SOAP format
        xml soapRequest = transformToViesSoapRequest(request);
        
        // Create Kafka message with UUID
        KafkaMessagePayload kafkaMessage = {
            uuid: requestUuid,
            soapRequest: soapRequest.toString(),
            requestType: "checkVat"
        };
        
        // Publish to Kafka
        string kafkaMessageString = kafkaMessage.toJsonString();
        kafka:Error? sendResult = kafkaProducer->send({
            topic: internalKafkaTopic,
            value: kafkaMessageString.toBytes()
        });
        
        if sendResult is kafka:Error {
            log:printError("Failed to publish message to Kafka", 'error = sendResult);
            return <http:InternalServerError>{
                body: {"error": "Failed to publish message to Kafka", "details": sendResult.message()}
            };
        }
        
        log:printInfo("Successfully published VAT validation request to Kafka");
        
        // Create Kafka consumer with UUID as group ID
        string consumerGroupId = string `internal-response-consumer-${requestUuid}`;
        kafka:Consumer kafkaConsumer = check new (kafkaBootstrapServers, {
            groupId: consumerGroupId,
            topics: [internalKafkaTopicResponse],
            securityProtocol: kafka:PROTOCOL_SSL,
            secureSocket: {
                cert: kafkaCaCertPath,
                key: {
                    certFile: kafkaClientCertPath,
                    keyFile: kafkaClientKeyPath
                }
            },
            autoCommit: true
        });
        
        // Poll for response with matching UUID (timeout: 30 seconds)
        int maxAttempts = 30;
        int attemptCount = 0;
        
        while attemptCount < maxAttempts {
            kafka:AnydataConsumerRecord[]|kafka:Error pollResult = kafkaConsumer->poll(1);
            if pollResult is kafka:AnydataConsumerRecord[] {
                foreach kafka:AnydataConsumerRecord consumerRecord in pollResult {
                    byte[] valueBytes = check consumerRecord.value.ensureType();
                    string responseString = check string:fromBytes(valueBytes);
                    KafkaResponsePayload responsePayload = check responseString.fromJsonStringWithType();
                    // Check if UUID matches
                    if responsePayload.uuid == requestUuid {
                        log:printInfo("Received matching response from Kafka", uuid = requestUuid);
                        // Parse SOAP response
                        xml soapResponse = check xml:fromString(responsePayload.soapResponse);
                        SapMdmVatResponse sapResponse = check transformToSapMdmResponse(soapResponse);  
                        log:printInfo("Responded to the client after converting the message to JSON", sapResponse = sapResponse);                   
                        return sapResponse;
                    }
                }
            }
            
            attemptCount += 1;
            runtime:sleep(0.5);
        }
        
        log:printError("Timeout waiting for response from Kafka", uuid = requestUuid);
        return <http:InternalServerError>{
            body: {"error": "Timeout waiting for response", "uuid": requestUuid}
        };
    }

    // Health check endpoint
    resource function get health() returns string {
        return "SAP-MDM to Kafka integration service is running";
    }
}