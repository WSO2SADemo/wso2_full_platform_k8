import ballerina/http;
import ballerina/log;
import ballerinax/kafka;
import ballerinax/wso2.controlplane as _;

// Service to receive SAP-MDM requests and forward to VIES
service /sapToVies on sapMdmListener {

    // Resource to validate VAT number
    resource function post checkVat(@http:Payload SapMdmVatRequest request) returns SapMdmVatResponse|http:InternalServerError {

        log:printInfo("Received VAT validation request", countryCode = request.countryCode, vatNumber = request.vatNumber);

        // Process the VAT validation
        SapMdmVatResponse|error response = processVatValidation(request);

        if response is error {
            log:printError("Error processing VAT validation", 'error = response);

            // Return error response in SAP-MDM format
            SapMdmVatResponse errorResponse = createErrorResponse(request.countryCode, request.vatNumber, response.message());

            return <http:InternalServerError>{
                body: errorResponse
            };
        }

        log:printInfo("VAT validation completed successfully", valid = response.valid);
        check kafkaProducer->send({
            topic: "sampletopic",
            value: (response)
        });
        return response;
    }

    // Resource to validate VAT number with approximate matching
    resource function post checkVatApprox(@http:Payload SapMdmVatApproxRequest request) returns SapMdmVatApproxResponse|http:InternalServerError {

        log:printInfo("Received VAT approximate validation request", countryCode = request.countryCode, vatNumber = request.vatNumber);

        // Process the VAT approximate validation
        SapMdmVatApproxResponse|error response = processVatApproxValidation(request);

        if response is error {
            log:printError("Error processing VAT approximate validation", 'error = response);

            // Return error response in SAP-MDM format
            SapMdmVatApproxResponse errorResponse = createApproxErrorResponse(request.countryCode, request.vatNumber, response.message());

            return <http:InternalServerError>{
                body: errorResponse
            };
        }

        log:printInfo("VAT approximate validation completed successfully", valid = response.valid);
        return response;
    }

    // Health check endpoint
    resource function get health() returns string {
        return "SAP-MDM to VIES integration service is running";
    }
}
