import ballerina/log;
import ballerinax/kafka;

// Service to consume messages from Kafka topic 1 and publish to Kafka topic 2
service on kafkaListenerTopic1 {

    // Remote function to handle incoming messages from Kafka topic 1
    remote function onConsumerRecord(kafka:AnydataConsumerRecord[] records) returns error? {
        log:printInfo("Received messages from Kafka topic 1", count = records.length());
        
        // Process each record
        foreach kafka:AnydataConsumerRecord consumerRecord in records {
            // Extract message value
            anydata messageValue = consumerRecord.value;
            
            // Convert to bytes for publishing
            byte[] messageBytes = [];
            if messageValue is byte[] {
                messageBytes = messageValue;
            } else if messageValue is string {
                messageBytes = messageValue.toBytes();
            } else {
                string messageString = messageValue.toString();
                messageBytes = messageString.toBytes();
            }
            
            // Publish to Kafka topic 2
            kafka:Error? sendResult = kafkaProducerTopic2->send({
                topic: kafkaTopic2,
                value: messageBytes
            });
            
            if sendResult is kafka:Error {
                log:printError("Failed to publish message to Kafka topic 2", 'error = sendResult);
                return sendResult;
            }
            
            log:printInfo("Successfully published message to Kafka topic 2");
        }
        
        return;
    }

    // Remote function to handle errors during message processing
    remote function onError(kafka:Error 'error) returns error? {
        log:printError("Error occurred while consuming messages from Kafka topic 1", 'error = 'error);
        return;
    }
}
