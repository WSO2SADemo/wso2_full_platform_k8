import ballerina/http;
import ballerina/log;
import ballerinax/wso2.apim.catalog as _;
import ballerinax/moesif as _;
import ballerinax/kafka;

// Service to receive SAP-MDM requests and forward to Kafka
service /sapToKafka on sapMdmListener {

    // Resource to validate VAT number
    resource function post checkVat(@http:Payload SapMdmVatRequest request) returns http:Ok|http:InternalServerError {
        log:printInfo("Received VAT validation request", countryCode = request.countryCode, vatNumber = request.vatNumber);
        
        // Transform SAP-MDM request to VIES SOAP format
        xml soapRequest = transformToViesSoapRequest(request);
        
        // Publish to Kafka
        string soapRequestString = soapRequest.toString();
        kafka:Error? sendResult = kafkaProducer->send({
            topic: kafkaTopic1,
            value: soapRequestString.toBytes()
        });
        
        if sendResult is kafka:Error {
            log:printError("Failed to publish message to Kafka", 'error = sendResult);
            return <http:InternalServerError>{
                body: {"error": "Failed to publish message to Kafka", "details": sendResult.message()}
            };
        }
        
        log:printInfo("Successfully published VAT validation request to Kafka");
        return <http:Ok>{
            body: {"status": "Message published to Kafka successfully"}
        };
    }

    // Resource to validate VAT number with approximate matching
    resource function post checkVatApprox(@http:Payload SapMdmVatApproxRequest request) returns http:Ok|http:InternalServerError {
        log:printInfo("Received VAT approximate validation request", countryCode = request.countryCode, vatNumber = request.vatNumber);
        
        // Transform SAP-MDM request to VIES SOAP format
        xml soapRequest = transformToViesApproxSoapRequest(request);
        
        // Publish to Kafka
        string soapRequestString = soapRequest.toString();
        kafka:Error? sendResult = kafkaProducer->send({
            topic: kafkaTopic1,
            value: soapRequestString.toBytes()
        });
        
        if sendResult is kafka:Error {
            log:printError("Failed to publish message to Kafka", 'error = sendResult);
            return <http:InternalServerError>{
                body: {"error": "Failed to publish message to Kafka", "details": sendResult.message()}
            };
        }
        
        log:printInfo("Successfully published VAT approximate validation request to Kafka");
        return <http:Ok>{
            body: {"status": "Message published to Kafka successfully"}
        };
    }

    // Health check endpoint
    resource function get health() returns string {
        return "SAP-MDM to Kafka integration service is running";
    }
}