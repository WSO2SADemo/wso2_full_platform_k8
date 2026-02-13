import ballerina/http;
import ballerina/log;
import ballerinax/wso2.apim.catalog as _;
import ballerinax/moesif as _;
import ballerinax/kafka;

function init() {
    log:printInfo("VIES DMZ External service initializing...");
}

// Service to consume SOAP requests from Kafka topic 2 and invoke VIES service
service on kafkaListenerTopic2 {

    // Remote function to handle incoming SOAP requests from Kafka topic 2
    remote function onConsumerRecord(kafka:AnydataConsumerRecord[] records) returns error? {
        log:printInfo("Received SOAP requests from Kafka topic 2", count = records.length());
        
        // Process each record
        foreach kafka:AnydataConsumerRecord consumerRecord in records {
            // Extract message value
            anydata messageValue = consumerRecord.value;
            
            // Convert to string
            string payloadString = "";
            if messageValue is byte[] {
                string|error convertedString = string:fromBytes(messageValue);
                if convertedString is error {
                    log:printError("Failed to convert message bytes to string", 'error = convertedString);
                    continue;
                }
                payloadString = convertedString;
            } else if messageValue is string {
                payloadString = messageValue;
            } else {
                payloadString = messageValue.toString();
            }
            
            // Parse JSON payload
            json|error payloadJson = payloadString.fromJsonString();
            if payloadJson is error {
                log:printError("Failed to parse payload JSON", 'error = payloadJson);
                continue;
            }
            
            // Convert to KafkaRequestPayload record
            KafkaRequestPayload|error requestPayload = payloadJson.cloneWithType();
            if requestPayload is error {
                log:printError("Failed to convert payload to KafkaRequestPayload", 'error = requestPayload);
                continue;
            }
            
            // Extract UUID and SOAP request
            string requestUuid = requestPayload.uuid;
            string soapRequestString = requestPayload.soapRequest;
            string requestType = requestPayload.requestType;
            
            log:printInfo("Processing request", uuid = requestUuid, requestType = requestType);
            
            // Parse SOAP request XML
            xml|error soapRequestXml = xml:fromString(soapRequestString);
            if soapRequestXml is error {
                log:printError("Failed to parse SOAP request XML", 'error = soapRequestXml, uuid = requestUuid);
                continue;
            }
            
            // Invoke VIES service with the SOAP request and UUID
            error? invokeResult = invokeViesService(soapRequestXml, requestUuid);
            if invokeResult is error {
                log:printError("Failed to invoke VIES service", 'error = invokeResult, uuid = requestUuid);
                continue;
            }
            
            log:printInfo("Successfully processed SOAP request and invoked VIES service", uuid = requestUuid);
        }
        
        return;
    }

    // Remote function to handle errors during message processing
    remote function onError(kafka:Error 'error) returns error? {
        log:printError("Error occurred while consuming messages from Kafka topic 2", 'error = 'error);
        return;
    }
}

// Function to invoke VIES service with SOAP request and send response to Kafka
function invokeViesService(xml soapRequest, string requestUuid) returns error? {
    log:printInfo("Invoking VIES service with SOAP request", uuid = requestUuid);
    
    // Send SOAP request to VIES service
    http:Response|error viesResponse = viesClient->post("", soapRequest, {
        "Content-Type": "text/xml;charset=UTF-8",
        "SOAPAction": ""
    });
    
    if viesResponse is error {
        log:printError("Error sending request to VIES", 'error = viesResponse, uuid = requestUuid);
        return viesResponse;
    }
    
    // Get SOAP response
    xml|error soapResponseXml = viesResponse.getXmlPayload();
    
    if soapResponseXml is error {
        log:printError("Error parsing VIES response", 'error = soapResponseXml, uuid = requestUuid);
        return soapResponseXml;
    }
    
    log:printInfo("Successfully received response from VIES service", uuid = requestUuid);
    log:printInfo("VIES Response", response = soapResponseXml.toString(), uuid = requestUuid);
    
    // Create response payload with UUID
    KafkaResponsePayload responsePayload = {
        uuid: requestUuid,
        soapResponse: soapResponseXml
    };
    
    // Convert response payload to JSON string
    json responseJson = responsePayload.toJson();
    string responseJsonString = responseJson.toJsonString();
    
    // Send response to Kafka producer topic
    kafka:Error? sendResult = kafkaProducerResponse->send({
        topic: externalKafkaTopicResponse,
        value: responseJsonString.toBytes()
    });
    
    if sendResult is kafka:Error {
        log:printError("Failed to send response to Kafka", 'error = sendResult, uuid = requestUuid);
        return sendResult;
    }
    
    log:printInfo("Successfully sent response to Kafka topic", topic = externalKafkaTopicResponse, uuid = requestUuid);
    
    return;
}