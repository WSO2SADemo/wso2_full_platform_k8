import ballerina/http;
import ballerina/log;
import ballerinax/wso2.apim.catalog as _;
import ballerinax/moesif as _;
import ballerinax/kafka;

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
            string soapRequestString = "";
            if messageValue is byte[] {
                string|error convertedString = string:fromBytes(messageValue);
                if convertedString is error {
                    log:printError("Failed to convert message bytes to string", 'error = convertedString);
                    continue;
                }
                soapRequestString = convertedString;
            } else if messageValue is string {
                soapRequestString = messageValue;
            } else {
                soapRequestString = messageValue.toString();
            }
            
            // Parse SOAP request XML
            xml|error soapRequestXml = xml:fromString(soapRequestString);
            if soapRequestXml is error {
                log:printError("Failed to parse SOAP request XML", 'error = soapRequestXml);
                continue;
            }
            
            // Invoke VIES service with the SOAP request
            error? invokeResult = invokeViesService(soapRequestXml);
            if invokeResult is error {
                log:printError("Failed to invoke VIES service", 'error = invokeResult);
                continue;
            }
            
            log:printInfo("Successfully processed SOAP request and invoked VIES service");
        }
        
        return;
    }

    // Remote function to handle errors during message processing
    remote function onError(kafka:Error 'error) returns error? {
        log:printError("Error occurred while consuming messages from Kafka topic 2", 'error = 'error);
        return;
    }
}

// Function to invoke VIES service with SOAP request
function invokeViesService(xml soapRequest) returns error? {
    log:printInfo("Invoking VIES service with SOAP request");
    
    // Send SOAP request to VIES service
    http:Response|error viesResponse = viesClient->post("", soapRequest, {
        "Content-Type": "text/xml;charset=UTF-8",
        "SOAPAction": ""
    });
    
    if viesResponse is error {
        log:printError("Error sending request to VIES", 'error = viesResponse);
        return viesResponse;
    }
    
    // Get SOAP response
    xml|error soapResponseXml = viesResponse.getXmlPayload();
    
    if soapResponseXml is error {
        log:printError("Error parsing VIES response", 'error = soapResponseXml);
        return soapResponseXml;
    }
    
    log:printInfo("Successfully received response from VIES service");
    log:printInfo("VIES Response", response = soapResponseXml.toString());
    
    return;
}