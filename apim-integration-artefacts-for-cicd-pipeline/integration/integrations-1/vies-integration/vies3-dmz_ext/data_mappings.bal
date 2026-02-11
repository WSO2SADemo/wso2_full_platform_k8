import ballerina/time;
import ballerina/io;

// Transform SAP-MDM request to VIES SOAP request
function transformToViesSoapRequest(SapMdmVatRequest sapRequest) returns xml {
    xml soapEnvelope = xml `<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:ec.europa.eu:taxud:vies:services:checkVat:types">
   <soapenv:Header/>
   <soapenv:Body>
      <urn:checkVat>
         <urn:countryCode>${sapRequest.countryCode}</urn:countryCode>
         <urn:vatNumber>${sapRequest.vatNumber}</urn:vatNumber>
      </urn:checkVat>
   </soapenv:Body>
</soapenv:Envelope>`;
    return soapEnvelope;
}

// Transform VIES SOAP response to SAP-MDM response
function transformToSapMdmResponse(xml soapResponse) returns SapMdmVatResponse|error {
    // Print raw SOAP response
    io:println("========== RAW SOAP RESPONSE START ==========");
    io:println(soapResponse.toString());
    io:println("========== RAW SOAP RESPONSE END ==========");
    
    xmlns "urn:ec.europa.eu:taxud:vies:services:checkVat:types" as ns;
    
    xml countryCodeElement = soapResponse/**/<ns:countryCode>;
    xml vatNumberElement = soapResponse/**/<ns:vatNumber>;
    xml requestDateElement = soapResponse/**/<ns:requestDate>;
    xml validElement = soapResponse/**/<ns:valid>;
    xml nameElement = soapResponse/**/<ns:name>;
    xml addressElement = soapResponse/**/<ns:address>;
    
    string countryCodeText = (countryCodeElement/*).toString();
    string vatNumberText = (vatNumberElement/*).toString();
    string requestDateText = (requestDateElement/*).toString();
    string validText = (validElement/*).toString();
    string nameText = (nameElement/*).toString();
    string addressText = (addressElement/*).toString();
    
    boolean isValid = validText == "true";
    
    SapMdmVatResponse response = {
        countryCode: countryCodeText,
        vatNumber: vatNumberText,
        valid: isValid,
        name: nameText != "" ? nameText : (),
        address: addressText != "" ? addressText : (),
        requestDate: requestDateText
    };
    
    return response;
}

// Create error response for SAP-MDM
function createErrorResponse(string countryCode, string vatNumber, string errorMessage) returns SapMdmVatResponse {
    time:Utc currentTime = time:utcNow();
    string currentDateString = time:utcToString(currentTime);
    
    SapMdmVatResponse errorResponse = {
        countryCode: countryCode,
        vatNumber: vatNumber,
        valid: false,
        name: (),
        address: (),
        requestDate: currentDateString
    };
    
    return errorResponse;
}

// Transform SAP-MDM request to VIES SOAP request for checkVatApprox
function transformToViesApproxSoapRequest(SapMdmVatApproxRequest sapRequest) returns xml {
    string traderNameValue = sapRequest?.traderName ?: "";
    string traderCompanyTypeValue = sapRequest?.traderCompanyType ?: "";
    string traderStreetValue = sapRequest?.traderStreet ?: "";
    string traderPostcodeValue = sapRequest?.traderPostcode ?: "";
    string traderCityValue = sapRequest?.traderCity ?: "";
    
    xml soapEnvelope = xml `<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:ec.europa.eu:taxud:vies:services:checkVat:types">
   <soapenv:Header/>
   <soapenv:Body>
      <urn:checkVatApprox>
         <urn:countryCode>${sapRequest.countryCode}</urn:countryCode>
         <urn:vatNumber>${sapRequest.vatNumber}</urn:vatNumber>
         <urn:traderName>${traderNameValue}</urn:traderName>
         <urn:traderCompanyType>${traderCompanyTypeValue}</urn:traderCompanyType>
         <urn:traderStreet>${traderStreetValue}</urn:traderStreet>
         <urn:traderPostcode>${traderPostcodeValue}</urn:traderPostcode>
         <urn:traderCity>${traderCityValue}</urn:traderCity>
      </urn:checkVatApprox>
   </soapenv:Body>
</soapenv:Envelope>`;
    return soapEnvelope;
}

// Transform VIES SOAP response to SAP-MDM response for checkVatApprox
function transformToSapMdmApproxResponse(xml soapResponse) returns SapMdmVatApproxResponse|error {
    // Print raw SOAP response
    io:println("========== RAW SOAP APPROX RESPONSE START ==========");
    io:println(soapResponse.toString());
    io:println("========== RAW SOAP APPROX RESPONSE END ==========");
    
    xmlns "urn:ec.europa.eu:taxud:vies:services:checkVat:types" as ns;
    
    xml countryCodeElement = soapResponse/**/<ns:countryCode>;
    xml vatNumberElement = soapResponse/**/<ns:vatNumber>;
    xml requestDateElement = soapResponse/**/<ns:requestDate>;
    xml validElement = soapResponse/**/<ns:valid>;
    xml traderNameElement = soapResponse/**/<ns:traderName>;
    xml traderCompanyTypeElement = soapResponse/**/<ns:traderCompanyType>;
    xml traderStreetElement = soapResponse/**/<ns:traderStreet>;
    xml traderPostcodeElement = soapResponse/**/<ns:traderPostcode>;
    xml traderCityElement = soapResponse/**/<ns:traderCity>;
    xml traderAddressElement = soapResponse/**/<ns:traderAddress>;
    xml traderNameMatchElement = soapResponse/**/<ns:traderNameMatch>;
    xml traderCompanyTypeMatchElement = soapResponse/**/<ns:traderCompanyTypeMatch>;
    xml traderStreetMatchElement = soapResponse/**/<ns:traderStreetMatch>;
    xml traderPostcodeMatchElement = soapResponse/**/<ns:traderPostcodeMatch>;
    xml traderCityMatchElement = soapResponse/**/<ns:traderCityMatch>;
    
    string countryCodeText = (countryCodeElement/*).toString();
    string vatNumberText = (vatNumberElement/*).toString();
    string requestDateText = (requestDateElement/*).toString();
    string validText = (validElement/*).toString();
    string traderNameText = (traderNameElement/*).toString();
    string traderCompanyTypeText = (traderCompanyTypeElement/*).toString();
    string traderStreetText = (traderStreetElement/*).toString();
    string traderPostcodeText = (traderPostcodeElement/*).toString();
    string traderCityText = (traderCityElement/*).toString();
    string traderAddressText = (traderAddressElement/*).toString();
    string traderNameMatchText = (traderNameMatchElement/*).toString();
    string traderCompanyTypeMatchText = (traderCompanyTypeMatchElement/*).toString();
    string traderStreetMatchText = (traderStreetMatchElement/*).toString();
    string traderPostcodeMatchText = (traderPostcodeMatchElement/*).toString();
    string traderCityMatchText = (traderCityMatchElement/*).toString();
    
    boolean isValid = validText == "true";
    
    SapMdmVatApproxResponse response = {
        countryCode: countryCodeText,
        vatNumber: vatNumberText,
        valid: isValid,
        traderName: traderNameText != "" ? traderNameText : (),
        traderCompanyType: traderCompanyTypeText != "" ? traderCompanyTypeText : (),
        traderStreet: traderStreetText != "" ? traderStreetText : (),
        traderPostcode: traderPostcodeText != "" ? traderPostcodeText : (),
        traderCity: traderCityText != "" ? traderCityText : (),
        traderAddress: traderAddressText != "" ? traderAddressText : (),
        traderNameMatch: traderNameMatchText != "" ? traderNameMatchText : (),
        traderCompanyTypeMatch: traderCompanyTypeMatchText != "" ? traderCompanyTypeMatchText : (),
        traderStreetMatch: traderStreetMatchText != "" ? traderStreetMatchText : (),
        traderPostcodeMatch: traderPostcodeMatchText != "" ? traderPostcodeMatchText : (),
        traderCityMatch: traderCityMatchText != "" ? traderCityMatchText : (),
        requestDate: requestDateText
    };
    
    return response;
}

// Create error response for SAP-MDM checkVatApprox
function createApproxErrorResponse(string countryCode, string vatNumber, string errorMessage) returns SapMdmVatApproxResponse {
    time:Utc currentTime = time:utcNow();
    string currentDateString = time:utcToString(currentTime);
    
    SapMdmVatApproxResponse errorResponse = {
        countryCode: countryCode,
        vatNumber: vatNumber,
        valid: false,
        traderName: (),
        traderCompanyType: (),
        traderStreet: (),
        traderPostcode: (),
        traderCity: (),
        traderAddress: (),
        traderNameMatch: (),
        traderCompanyTypeMatch: (),
        traderStreetMatch: (),
        traderPostcodeMatch: (),
        traderCityMatch: (),
        requestDate: currentDateString
    };
    
    return errorResponse;
}
