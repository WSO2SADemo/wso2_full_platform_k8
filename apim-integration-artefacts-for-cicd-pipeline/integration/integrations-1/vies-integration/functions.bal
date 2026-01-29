import ballerina/http;

// Process VAT validation request
function processVatValidation(SapMdmVatRequest sapRequest) returns SapMdmVatResponse|error {
    // Transform SAP-MDM request to VIES SOAP format
    xml soapRequest = transformToViesSoapRequest(sapRequest);
    
    // Send SOAP request to VIES service
    http:Response viesResponse = check viesClient->post("", soapRequest, {
        "Content-Type": "text/xml;charset=UTF-8",
        "SOAPAction": ""
    });
    
    // Get SOAP response
    xml soapResponseXml = check viesResponse.getXmlPayload();
    
    // Transform VIES SOAP response to SAP-MDM format
    SapMdmVatResponse sapResponse = check transformToSapMdmResponse(soapResponseXml);
    
    return sapResponse;
}

// Process VAT approximate validation request
function processVatApproxValidation(SapMdmVatApproxRequest sapRequest) returns SapMdmVatApproxResponse|error {
    // Transform SAP-MDM request to VIES SOAP format
    xml soapRequest = transformToViesApproxSoapRequest(sapRequest);
    
    // Send SOAP request to VIES service
    http:Response viesResponse = check viesClient->post("", soapRequest, {
        "Content-Type": "text/xml;charset=UTF-8",
        "SOAPAction": ""
    });
    
    // Get SOAP response
    xml soapResponseXml = check viesResponse.getXmlPayload();
    
    // Transform VIES SOAP response to SAP-MDM format
    SapMdmVatApproxResponse sapResponse = check transformToSapMdmApproxResponse(soapResponseXml);
    
    return sapResponse;
}
