import ballerina/http;
import ballerina/log;
import ballerinax/wso2.apim.catalog as _;
import ballerinax/moesif as _;

// Service to receive SAP-MDM requests and forward to VIES
service /sapToVies on sapMdmListener {

    // Resource to validate VAT number
    resource function post checkVat(@http:Payload SapMdmVatRequest request) returns SapMdmVatResponse|http:InternalServerError {
        log:printInfo("Received VAT validation request", countryCode = request.countryCode, vatNumber = request.vatNumber);
        // Transform SAP-MDM request to VIES SOAP format
        xml soapRequest = transformToViesSoapRequest(request);
        // Send SOAP request to VIES service
        http:Response|error viesResponse = viesClient->post("", soapRequest, {
            "Content-Type": "text/xml;charset=UTF-8",
            "SOAPAction": ""
        });
        if viesResponse is error {
            log:printError("Error sending request to VIES", 'error = viesResponse);
            SapMdmVatResponse errorResponse = createErrorResponse(request.countryCode, request.vatNumber, viesResponse.message());
            return <http:InternalServerError>{
                body: errorResponse
            };
        }
        // Get SOAP response
        xml|error soapResponseXml = viesResponse.getXmlPayload();
        if soapResponseXml is error {
            log:printError("Error parsing VIES response", 'error = soapResponseXml);
            SapMdmVatResponse errorResponse = createErrorResponse(request.countryCode, request.vatNumber, soapResponseXml.message());
            return <http:InternalServerError>{
                body: errorResponse
            };
        }
        // Transform VIES SOAP response to SAP-MDM format
        SapMdmVatResponse|error sapResponse = transformToSapMdmResponse(soapResponseXml);
        if sapResponse is error {
            log:printError("Error transforming VIES response", 'error = sapResponse);
            SapMdmVatResponse errorResponse = createErrorResponse(request.countryCode, request.vatNumber, sapResponse.message());
            return <http:InternalServerError>{
                body: errorResponse
            };
        }
        return sapResponse;
    }

    // Resource to validate VAT number with approximate matching
    resource function post checkVatApprox(@http:Payload SapMdmVatApproxRequest request) returns SapMdmVatApproxResponse|http:InternalServerError {

        log:printInfo("Received VAT approximate validation request", countryCode = request.countryCode, vatNumber = request.vatNumber);

        // Transform SAP-MDM request to VIES SOAP format
        xml soapRequest = transformToViesApproxSoapRequest(request);
        
        // Send SOAP request to VIES service
        http:Response|error viesResponse = viesClient->post("", soapRequest, {
            "Content-Type": "text/xml;charset=UTF-8",
            "SOAPAction": ""
        });
        
        if viesResponse is error {
            log:printError("Error sending request to VIES", 'error = viesResponse);
            SapMdmVatApproxResponse errorResponse = createApproxErrorResponse(request.countryCode, request.vatNumber, viesResponse.message());
            return <http:InternalServerError>{
                body: errorResponse
            };
        }
        
        // Get SOAP response
        xml|error soapResponseXml = viesResponse.getXmlPayload();
        
        if soapResponseXml is error {
            log:printError("Error parsing VIES response", 'error = soapResponseXml);
            SapMdmVatApproxResponse errorResponse = createApproxErrorResponse(request.countryCode, request.vatNumber, soapResponseXml.message());
            return <http:InternalServerError>{
                body: errorResponse
            };
        }
        
        // Transform VIES SOAP response to SAP-MDM format
        SapMdmVatApproxResponse|error sapResponse = transformToSapMdmApproxResponse(soapResponseXml);
        
        if sapResponse is error {
            log:printError("Error transforming VIES response", 'error = sapResponse);
            SapMdmVatApproxResponse errorResponse = createApproxErrorResponse(request.countryCode, request.vatNumber, sapResponse.message());
            return <http:InternalServerError>{
                body: errorResponse
            };
        }

        log:printInfo("VAT approximate validation completed successfully", valid = sapResponse.valid);
        return sapResponse;
    }

    // Health check endpoint
    resource function get health() returns string {
        return "SAP-MDM to VIES integration service is running";
    }
}