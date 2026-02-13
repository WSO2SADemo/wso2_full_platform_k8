import ballerina/log;
import ballerinax/kafka;
// import ballerinax/wso2.apim.catalog as _;
// import ballerinax/moesif as _;

function init() {
    log:printInfo("VIES DMZ Internal service initializing...");
}

// Service to consume messages from internal Kafka topic
service on internalKafkaListener {

    // Remote function to handle incoming messages from internal Kafka topic
    remote function onConsumerRecord(kafka:AnydataConsumerRecord[] records) returns error? {
        log:printInfo("Received messages from internal Kafka topic", count = records.length());
        
        // Process each record
        foreach kafka:AnydataConsumerRecord consumerRecord in records {
            // Extract message value
            anydata messageValue = consumerRecord.value;
            
            // Parse the JSON payload
            InternalKafkaMessage kafkaMessage;
            if messageValue is byte[] {
                string messageString = check string:fromBytes(messageValue);
                json messageJson = check messageString.fromJsonString();
                kafkaMessage = check messageJson.cloneWithType();
            } else if messageValue is string {
                json messageJson = check messageValue.fromJsonString();
                kafkaMessage = check messageJson.cloneWithType();
            } else {
                log:printError("Unsupported message format received");
                continue;
            }
            
            log:printInfo("Processing message", uuid = kafkaMessage.uuid, requestType = kafkaMessage.requestType);
            
            // Send to external Kafka topic (include UUID so response can be correlated)
            json externalPayload = kafkaMessage.toJson();
            kafka:Error? sendResult = externalKafkaProducer->send({
                topic: externalKafkaTopic,
                value: externalPayload.toJsonString().toBytes()
            });
            
            if sendResult is kafka:Error {
                log:printError("Failed to publish message to external Kafka topic", 'error = sendResult, uuid = kafkaMessage.uuid);
                return sendResult;
            }
            
            log:printInfo("Successfully published message to external Kafka topic", uuid = kafkaMessage.uuid);
            
            // Create a consumer for the response topic with UUID as groupId
            string consumerGroupId = string `response-consumer-${kafkaMessage.uuid}`;
            kafka:Consumer responseConsumer = check new (
                bootstrapServers = externalKafkaBootstrapServers,
                groupId = consumerGroupId,
                topics = externalKafkaTopicResponse,
                securityProtocol = kafka:PROTOCOL_SSL,
                secureSocket = {
                    cert: externalKafkaCaCertPath,
                    key: {
                        certFile: externalKafkaClientCertPath,
                        keyFile: externalKafkaClientKeyPath
                    }
                },
                autoCommit = false,
                offsetReset = kafka:OFFSET_RESET_EARLIEST
            );
            
            log:printInfo("Created response consumer", uuid = kafkaMessage.uuid, topic = externalKafkaTopicResponse);
            
            // Poll for matching response (with timeout of 30 seconds)
            boolean responseFound = false;
            decimal elapsedSeconds = 0.0;
            decimal pollIntervalSeconds = 5.0;
            decimal maxWaitSeconds = 30.0;

            while !responseFound && elapsedSeconds < maxWaitSeconds {
                kafka:AnydataConsumerRecord[]|kafka:Error pollResult = responseConsumer->poll(pollIntervalSeconds);

                if pollResult is kafka:Error {
                    log:printError("Failed to poll response from external Kafka topic", 'error = pollResult, uuid = kafkaMessage.uuid);
                    break;
                }

                foreach kafka:AnydataConsumerRecord responseRecord in pollResult {
                    anydata responseValue = responseRecord.value;
                    string responseString;

                    if responseValue is byte[] {
                        responseString = check string:fromBytes(responseValue);
                    } else if responseValue is string {
                        responseString = responseValue;
                    } else {
                        responseString = responseValue.toString();
                    }

                    // Check if this response matches our UUID
                    json|error responseJson = responseString.fromJsonString();
                    if responseJson is json {
                        string|error responseUuid = (check responseJson.uuid).toString();
                        if responseUuid is string && responseUuid == kafkaMessage.uuid {
                            log:printInfo("Received matching response from external Kafka topic", uuid = kafkaMessage.uuid);

                            // Send response to internal Kafka response topic
                            kafka:Error? internalSendResult = internalKafkaProducer->send({
                                topic: internalKafkaTopicResponse,
                                value: responseString.toBytes()
                            });

                            if internalSendResult is kafka:Error {
                                log:printError("Failed to publish response to internal Kafka response topic", 'error = internalSendResult, uuid = kafkaMessage.uuid);
                            } else {
                                log:printInfo("Successfully published response to internal Kafka response topic", uuid = kafkaMessage.uuid, topic = internalKafkaTopicResponse);
                            }
                            responseFound = true;
                            break;
                        }
                    }
                }

                elapsedSeconds = elapsedSeconds + pollIntervalSeconds;
            }

            if !responseFound {
                log:printWarn("No matching response received within timeout period", uuid = kafkaMessage.uuid);
            }
            
            // Close the response consumer
            kafka:Error? closeResult = responseConsumer->close();
            if closeResult is kafka:Error {
                log:printError("Failed to close response consumer", 'error = closeResult, uuid = kafkaMessage.uuid);
            }
        }
        
        return;
    }

    // Remote function to handle errors during message processing
    remote function onError(kafka:Error 'error) returns error? {
        log:printError("Error occurred while consuming messages from internal Kafka topic", 'error = 'error);
        return;
    }
}
