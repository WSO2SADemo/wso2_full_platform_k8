import ballerina/http;
import ballerina/log;
import ballerina/io;
import ballerina/data.xmldata;
import ballerina/file;
import ballerinax/wso2.controlplane as _;
import ballerinax/wso2.apim.catalog as _;

// ============================================================================
// OAS SERVICE (Master Database) - Port 9092
// ============================================================================

http:ClientConfiguration clientEPConfig = {
    secureSocket: {
        cert: {
            path: "./bre/security/truststore.p12",
            password: "ballerina"
        }
    }
};

listener http:Listener oasListener = check new (9092);

service /oas on oasListener {

    function init() {
        log:printError("Initialize mock_backends");
        log:printError("Initialize mock_backends with service URL: " + scServiceUrl);
    }

    // Register or update member benefit data (called by Cash Registries)
    resource function post benefits(@http:Payload BenefitRegistrationRequest request) returns RegistrationResponse|http:InternalServerError {
        
        string currentTimestamp = getCurrentTimestamp();
        
        MemberBenefit benefit = {
            personalNumber: request.personalNumber,
            kassaName: request.kassaName,
            isMember: true,
            dailyAllowance: request.dailyAllowance,
            incomeBase: request.incomeBase,
            remainingDays: request.totalDays,
            registrationDate: currentTimestamp,
            lastUpdated: currentTimestamp
        };
        
        oasMemberDatabase[request.personalNumber] = benefit;
        
        log:printInfo(string `OAS: Registered benefit for ${request.personalNumber} from ${request.kassaName}`);
        
        return {
            success: true,
            message: "Benefit data successfully registered in OAS",
            registrationId: request.personalNumber
        };
    }

    // Lookup member benefit (called by AF)
    resource function get members/[string personalNumber]() returns MemberLookupResponse {
        
        if oasMemberDatabase.hasKey(personalNumber) {
            MemberBenefit? benefit = oasMemberDatabase[personalNumber];
            
            log:printInfo(string `OAS: Lookup for ${personalNumber} - FOUND`);
            
            return {
                found: true,
                benefit: benefit
            };
        }
        
        log:printInfo(string `OAS: Lookup for ${personalNumber} - NOT FOUND`);
        
        return {
            found: false,
            benefit: ()
        };
    }

    // Update remaining days (called when benefits are consumed)
    resource function put members/[string personalNumber]/days(@http:Query int daysUsed) returns RegistrationResponse|http:NotFound {
        
        if !oasMemberDatabase.hasKey(personalNumber) {
            return <http:NotFound>{
                body: {
                    success: false,
                    message: "Member not found in OAS"
                }
            };
        }
        
        MemberBenefit? existingBenefit = oasMemberDatabase[personalNumber];
        if existingBenefit is MemberBenefit {
            int updatedRemainingDays = existingBenefit.remainingDays - daysUsed;
            string updatedTimestamp = getCurrentTimestamp();
            
            MemberBenefit updatedBenefit = {
                personalNumber: existingBenefit.personalNumber,
                kassaName: existingBenefit.kassaName,
                isMember: existingBenefit.isMember,
                dailyAllowance: existingBenefit.dailyAllowance,
                incomeBase: existingBenefit.incomeBase,
                remainingDays: updatedRemainingDays,
                registrationDate: existingBenefit.registrationDate,
                lastUpdated: updatedTimestamp
            };
            
            oasMemberDatabase[personalNumber] = updatedBenefit;
            
            log:printInfo(string `OAS: Updated days for ${personalNumber}. Remaining: ${updatedBenefit.remainingDays}`);
            
            return {
                success: true,
                message: string `Days updated. Remaining: ${updatedBenefit.remainingDays}`
            };
        }
        
        return <http:NotFound>{
            body: {
                success: false,
                message: "Member not found in OAS"
            }
        };
    }

    // Health check endpoint
    resource function get health() returns string {
        return "OAS Service is running";
    }
}

// ============================================================================
// CASH REGISTRY SERVICE (A-kassa) - Port 9091
// ============================================================================

listener http:Listener cashRegistryListener = check new (9091);

service /cashregistry on cashRegistryListener {

    // Submit application for benefit calculation
    resource function post applications(@http:Payload BenefitCalculationRequest request) returns BenefitCalculationResponse|http:BadRequest {
        
        // Validate work certificates
        boolean certificatesValid = validateWorkCertificates(request.workCertificates);
        if !certificatesValid {
            return <http:BadRequest>{
                body: {
                    approved: false,
                    dailyAllowance: 0.0,
                    incomeBase: "",
                    totalDays: 0,
                    message: "Invalid or missing work certificates"
                }
            };
        }
        
        // Calculate daily allowance
        decimal dailyAllowance = calculateDailyAllowance(request.previousMonthlySalary);
        
        // Determine income base
        string incomeBase = determineIncomeBase(request.previousMonthlySalary);
        
        // Calculate total days
        int totalDays = calculateTotalDays(incomeBase);
        
        // Store application
        cashRegistryApplications[request.personalNumber] = request;
        
        log:printInfo(string `Cash Registry: Calculated benefit for ${request.personalNumber} - ${dailyAllowance} SEK/day`);
        
        return {
            approved: true,
            dailyAllowance: dailyAllowance,
            incomeBase: incomeBase,
            totalDays: totalDays,
            message: "Application approved and calculated"
        };
    }

    // Register calculated benefit to OAS (push to master database)
    resource function post register/[string personalNumber](@http:Query string kassaName) returns RegistrationResponse|http:NotFound|http:InternalServerError {
        
        if !cashRegistryApplications.hasKey(personalNumber) {
            return <http:NotFound>{
                body: {
                    success: false,
                    message: "No application found for this personal number"
                }
            };
        }
        
        BenefitCalculationRequest? application = cashRegistryApplications[personalNumber];
        if application is BenefitCalculationRequest {
            // Calculate benefit details
            decimal dailyAllowance = calculateDailyAllowance(application.previousMonthlySalary);
            string incomeBase = determineIncomeBase(application.previousMonthlySalary);
            int totalDays = calculateTotalDays(incomeBase);
            
            // Prepare registration request for OAS
            BenefitRegistrationRequest oasRequest = {
                personalNumber: personalNumber,
                kassaName: kassaName,
                dailyAllowance: dailyAllowance,
                incomeBase: incomeBase,
                totalDays: totalDays
            };
            
            // Push to OAS
            RegistrationResponse|http:ClientError oasResponse = oasClient->/oas/benefits.post(oasRequest);
            
            if oasResponse is RegistrationResponse {
                log:printInfo(string `Cash Registry: Successfully registered ${personalNumber} to OAS via ${kassaName}`);
                return oasResponse;
            } else {
                log:printError(string `Cash Registry: Failed to register to OAS - ${oasResponse.message()}`);
                return <http:InternalServerError>{
                    body: {
                        success: false,
                        message: "Failed to register benefit in OAS"
                    }
                };
            }
        }
        
        return <http:NotFound>{
            body: {
                success: false,
                message: "Application not found"
            }
        };
    }

    // Get application status
    resource function get applications/[string personalNumber]() returns BenefitCalculationRequest|http:NotFound {
        
        if cashRegistryApplications.hasKey(personalNumber) {
            BenefitCalculationRequest? application = cashRegistryApplications[personalNumber];
            if application is BenefitCalculationRequest {
                return application;
            }
        }
        
        return <http:NotFound>{
            body: "Application not found"
        };
    }

    // Health check endpoint
    resource function get health() returns string {
        return "Cash Registry Service is running";
    }
}

// ============================================================================
// SOAP SERVICE (XML/DTD/XSD Processing) - Port 9093
// ============================================================================

listener http:Listener soapListener = check new (9093);

// Directory paths for XML schemas and files
configurable string xsdSchemaPath = "./schemas/schema.xsd";
configurable string dtdSchemaPath = "./schemas/schema.dtd";
configurable string xmlFilesDirectory = "./xml_files";



// SOAP Request/Response types
type SoapEnvelope record {|
    xml Body;
|};

type XmlValidationRequest record {|
    string fileName;
    string schemaType; // "XSD" or "DTD"
    string xmlContent;
|};

type XmlValidationResponse record {|
    boolean valid;
    string message;
    string fileName;
    string schemaType;
|};

type XmlFileInfo record {|
    string fileName;
    int fileSize;
    string validationStatus;
    string schemaType;
    string processedTime;
|};

service /soap on soapListener {

    // SOAP endpoint to validate XML against XSD schema
    resource function post validateXml(@http:Payload xml soapRequest) returns xml|http:BadRequest|http:InternalServerError {
        
        log:printInfo("SOAP: Received XML validation request");
        
        // Extract SOAP body
        xml|error bodyContent = extractSoapBody(soapRequest);
        
        if bodyContent is error {
            log:printError(string `SOAP: Failed to extract SOAP body - ${bodyContent.message()}`);
            return <http:BadRequest>{
                body: createSoapFault(faultString = "Invalid SOAP envelope")
            };
        }
        
        // Parse validation request from SOAP body
        XmlValidationRequest|error validationRequest = parseValidationRequest(bodyContent);
        
        if validationRequest is error {
            log:printError(string `SOAP: Failed to parse validation request - ${validationRequest.message()}`);
            return <http:BadRequest>{
                body: createSoapFault(faultString = "Invalid validation request format")
            };
        }
        
        log:printInfo(string `SOAP: Validating ${validationRequest.fileName} against ${validationRequest.schemaType} schema`);
        
        // Validate XML content
        boolean isValid = false;
        string validationMessage = "";
        
        if validationRequest.schemaType == "XSD" {
            error? xsdValidation = validateAgainstXsd(xmlContent = validationRequest.xmlContent);
            if xsdValidation is error {
                isValid = false;
                validationMessage = string `XSD validation failed: ${xsdValidation.message()}`;
            } else {
                isValid = true;
                validationMessage = "XML is valid according to XSD schema";
            }
        } else if validationRequest.schemaType == "DTD" {
            // DTD validation (simplified - actual DTD validation would require external library)
            boolean dtdValid = validateAgainstDtd(xmlContent = validationRequest.xmlContent);
            isValid = dtdValid;
            validationMessage = dtdValid ? "XML is valid according to DTD schema" : "DTD validation failed";
        } else {
            validationMessage = "Unsupported schema type. Use 'XSD' or 'DTD'";
        }
        
        log:printInfo(string `SOAP: Validation result for ${validationRequest.fileName} - ${isValid}`);
        
        // Create SOAP response
        XmlValidationResponse response = {
            valid: isValid,
            message: validationMessage,
            fileName: validationRequest.fileName,
            schemaType: validationRequest.schemaType
        };
        
        xml soapResponse = createSoapResponse(response);
        return soapResponse;
    }

    // Process XML file from directory
    resource function post processFile(@http:Payload string fileName) returns XmlFileInfo|http:NotFound|http:InternalServerError {
        
        log:printInfo(string `SOAP: Processing file ${fileName}`);
        
        string filePath = string `${xmlFilesDirectory}/${fileName}`;
        
        // Check if file exists
        boolean|file:Error fileExistsResult = file:test(filePath, file:EXISTS);
        boolean fileExists = fileExistsResult is boolean ? fileExistsResult : false;
        if !fileExists {
            log:printError(string `SOAP: File not found - ${fileName}`);
            return <http:NotFound>{
                body: {
                    fileName: fileName,
                    fileSize: 0,
                    validationStatus: "FILE_NOT_FOUND",
                    schemaType: "UNKNOWN",
                    processedTime: getCurrentTimestamp()
                }
            };
        }
        
        // Read file content
        string|io:Error fileContent = io:fileReadString(filePath);
        
        if fileContent is io:Error {
            log:printError(string `SOAP: Failed to read file - ${fileContent.message()}`);
            return <http:InternalServerError>{
                body: {
                    fileName: fileName,
                    fileSize: 0,
                    validationStatus: "READ_ERROR",
                    schemaType: "UNKNOWN",
                    processedTime: getCurrentTimestamp()
                }
            };
        }
        
        // Determine schema type from file content or extension
        string schemaType = determineSchemaType(fileContent);
        
        // Validate the XML
        boolean isValid = false;
        if schemaType == "XSD" {
            error? xsdValidation = validateAgainstXsd(xmlContent = fileContent);
            isValid = xsdValidation is ();
        } else if schemaType == "DTD" {
            isValid = validateAgainstDtd(xmlContent = fileContent);
        }
        
        string validationStatus = isValid ? "VALID" : "INVALID";
        
        log:printInfo(string `SOAP: File ${fileName} processed - ${validationStatus}`);
        
        return {
            fileName: fileName,
            fileSize: fileContent.length(),
            validationStatus: validationStatus,
            schemaType: schemaType,
            processedTime: getCurrentTimestamp()
        };
    }

    // List all XML files in the directory
    resource function get files() returns XmlFileInfo[]|http:InternalServerError {
        
        log:printInfo("SOAP: Listing XML files");
        
        // Check if directory exists
        boolean|file:Error dirExistsResult = file:test(xmlFilesDirectory, file:EXISTS);
        boolean dirExists = dirExistsResult is boolean ? dirExistsResult : false;
        if !dirExists {
            log:printWarn(string `SOAP: XML files directory does not exist - ${xmlFilesDirectory}`);
            return [];
        }
        
        // Read directory (simplified - in production, use file:readDir)
        XmlFileInfo[] fileList = [];
        
        // This is a placeholder - actual implementation would scan the directory
        log:printInfo("SOAP: Directory listing complete");
        
        return fileList;
    }

    // Health check endpoint
    resource function get health() returns string {
        return "SOAP Service is running on port 9093";
    }
}

// Helper function to extract SOAP body from envelope
function extractSoapBody(xml soapEnvelope) returns xml|error {
    // Simple SOAP body extraction
    // In production, use proper SOAP library
    xml body = soapEnvelope/<Body>;
    if body.length() == 0 {
        return error("SOAP Body not found in envelope");
    }
    return body;
}

// Helper function to parse validation request from XML
function parseValidationRequest(xml bodyContent) returns XmlValidationRequest|error {
    // Extract validation request fields from XML
    // This is simplified - actual implementation would use xmldata:parseString
    
    string fileName = (bodyContent/<fileName>/*).toString();
    string schemaType = (bodyContent/<schemaType>/*).toString();
    string xmlContent = (bodyContent/<xmlContent>/*).toString();
    
    if fileName == "" || schemaType == "" || xmlContent == "" {
        return error("Missing required fields in validation request");
    }
    
    return {
        fileName: fileName,
        schemaType: schemaType,
        xmlContent: xmlContent
    };
}

// Validate XML against XSD schema
function validateAgainstXsd(string xmlContent) returns error? {
    
    // Check if XSD schema file exists
    boolean|file:Error schemaExistsResult = file:test(xsdSchemaPath, file:EXISTS);
    boolean schemaExists = schemaExistsResult is boolean ? schemaExistsResult : false;
    if !schemaExists {
        log:printWarn(string `XSD schema file not found at ${xsdSchemaPath}`);
        // For demo purposes, we'll skip validation if schema doesn't exist
        return;
    }
    
    // Parse XML content
    xml|error xmlValue = xml:fromString(xmlContent);
    if xmlValue is error {
        return error(string `Invalid XML content: ${xmlValue.message()}`);
    }
    
    // Validate against XSD schema
    error? validationResult = xmldata:validate(xmlValue, xsdSchemaPath);
    
    if validationResult is error {
        return error(string `XSD validation failed: ${validationResult.message()}`);
    }
    
    return;
}

// Validate XML against DTD schema
function validateAgainstDtd(string xmlContent) returns boolean {
    
    // DTD validation is typically done during XML parsing
    // Check if XML contains DTD declaration
    boolean hasDtd = xmlContent.includes("<!DOCTYPE");
    
    if !hasDtd {
        log:printWarn("XML does not contain DTD declaration");
        return false;
    }
    
    // Try to parse XML (which will validate against embedded DTD)
    xml|error xmlValue = xml:fromString(xmlContent);
    
    if xmlValue is error {
        log:printError(string `DTD validation failed: ${xmlValue.message()}`);
        return false;
    }
    
    return true;
}

// Determine schema type from XML content
function determineSchemaType(string xmlContent) returns string {
    
    if xmlContent.includes("xmlns:xsi") || xmlContent.includes("xsi:schemaLocation") {
        return "XSD";
    } else if xmlContent.includes("<!DOCTYPE") {
        return "DTD";
    }
    
    return "UNKNOWN";
}

// Create SOAP response envelope
function createSoapResponse(XmlValidationResponse response) returns xml {
    
    xml soapResponse = xml `<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
            <ValidationResponse>
                <valid>${response.valid}</valid>
                <message>${response.message}</message>
                <fileName>${response.fileName}</fileName>
                <schemaType>${response.schemaType}</schemaType>
            </ValidationResponse>
        </soap:Body>
    </soap:Envelope>`;
    
    return soapResponse;
}

// Create SOAP fault response
function createSoapFault(string faultString) returns xml {
    
    xml soapFault = xml `<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
            <soap:Fault>
                <faultcode>soap:Client</faultcode>
                <faultstring>${faultString}</faultstring>
            </soap:Fault>
        </soap:Body>
    </soap:Envelope>`;
    
    return soapFault;
}



// ============================================================================
// NOTIFICATION SERVICE - Port 9096
// ============================================================================

listener http:Listener notificationListener = check new (9096);

// Notification request type
type NotificationRequest record {|
    string message;
    json data?;
    boolean sendEmail?;
    boolean sendSms?;
|};

// Notification response type
type NotificationResponse record {|
    boolean success;
    string message;
    string logId?;
    boolean emailSent?;
    boolean smsSent?;
    string[] errors?;
|};

service /notification on notificationListener {

    // Service call endpoint - logs the payload with println
    resource function post servicecall(@http:Payload NotificationRequest request) returns NotificationResponse {
        
        string currentTimestamp = getCurrentTimestamp();
        string logId = string `LOG-${currentTimestamp}`;
        
        // Log the payload using println
        io:println("=== NOTIFICATION SERVICE ===");
        io:println(string `Log ID: ${logId}`);
        io:println(string `Message: ${request.message}`);
        io:println(string `Timestamp: ${currentTimestamp}`);
        
        json? requestData = request?.data;
        if requestData != () {
            io:println(string `Data: ${requestData.toJsonString()}`);
        }
        
        io:println("============================");
        
        return {
            success: true,
            message: "Payload logged successfully",
            logId: logId
        };
    }

    // Health check endpoint
    resource function get health() returns string {
        return "Notification Service is running on port 9096";
    }
}


