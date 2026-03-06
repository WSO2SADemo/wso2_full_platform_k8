// Combined service hosting both orchestration and notification services
// This service provides a unified endpoint for both orchestration and notification flows

import ballerina/http;
import ballerina/log;
import ballerina/email;
import ballerinax/twilio;
// import ballerinax/wso2.apim.catalog as _;
import ballerinax/moesif as _;

// Single listener for both services
listener http:Listener combinedListener = check new (9090);

// Clients for orchestration backend services
final http:Client cashRegistryOrchClient = check new (cashRegistryUrl);
final http:Client oasOrchClient = check new (oasUrl);

// Client for notification service
final http:Client notificationCallClient = check new (notificationUrl);

// Email and SMS clients
int smtpPort = check int:fromString(smtpPortStr);

final email:SmtpClient smtpClient = check new (smtpHost, smtpUsername, smtpPassword, {
    port: smtpPort,
    security: email:START_TLS_AUTO
});

final twilio:Client twilioClient = check new ({
    auth: {
        accountSid: twilioAccountSid,
        authToken: twilioAuthToken
    }
});

// Request type for orchestration
type OrchestrationRequest record {|
    string personalNumber;
    string kassaName;
    decimal previousMonthlySalary;
    string[] workCertificates;
|};

// Complete orchestration response
type OrchestrationResponse record {|
    boolean success;
    string message;
    BenefitCalculationResponse? calculation;
    RegistrationResponse? registration;
    MemberBenefit? finalBenefit;
|};

// Notification orchestration request type
type NotificationOrchRequest record {|
    string message;
    json data?;
    boolean sendEmail?;
    boolean sendSms?;
|};

// Notification orchestration response type
type NotificationOrchResponse record {|
    boolean success;
    string message;
    string logId?;
    boolean emailSent?;
    boolean smsSent?;
    string[] errors?;
|};

// Orchestration service at /api
service /api on combinedListener {

    function init() {
        log:printInfo("Initialize orchestration service on combined listener");
        log:printInfo("Initialize cashRegistryUrl: " + cashRegistryUrl);

        // Health check: verify connectivity to mock backend OAS service
        http:Response|http:ClientError healthResult = oasOrchClient->get("/health");
        if healthResult is http:ClientError {
            log:printError("Mock backend health check failed - could not reach OAS: " + healthResult.message());
        } else if healthResult.statusCode == 200 {
            log:printInfo("Mock backend health check passed - connection to OAS is working");
        } else {
            log:printWarn(string `Mock backend health check returned unexpected status: ${healthResult.statusCode}`);
        }
    }

    // Complete orchestration: Calculate benefit, register to OAS, and return final result
    resource function post benefits/register(@http:Payload OrchestrationRequest request) returns OrchestrationResponse|http:BadRequest|http:InternalServerError {
        
        log:printInfo(string `Orchestration: Starting benefit registration for ${request.personalNumber}`);
        
        // Step 1: Submit application to Cash Registry for calculation
        BenefitCalculationRequest calculationRequest = {
            personalNumber: request.personalNumber,
            workCertificates: request.workCertificates,
            previousMonthlySalary: request.previousMonthlySalary
        };
        
        BenefitCalculationResponse|http:ClientError calculationResult = cashRegistryOrchClient->/applications.post(calculationRequest);
        
        if calculationResult is http:ClientError {
            log:printError(string `Orchestration: Failed to calculate benefit - ${calculationResult.message()}`);
            return <http:InternalServerError>{
                body: {
                    success: false,
                    message: "Failed to calculate benefit at Cash Registry",
                    calculation: (),
                    registration: (),
                    finalBenefit: ()
                }
            };
        }
        
        if !calculationResult.approved {
            log:printInfo(string `Orchestration: Application not approved - ${calculationResult.message}`);
            return <http:BadRequest>{
                body: {
                    success: false,
                    message: calculationResult.message,
                    calculation: calculationResult,
                    registration: (),
                    finalBenefit: ()
                }
            };
        }
        
        log:printInfo(string `Orchestration: Benefit calculated - ${calculationResult.dailyAllowance} SEK/day`);
        
        // Step 2: Register the calculated benefit to OAS
        RegistrationResponse|http:ClientError registrationResult = cashRegistryOrchClient->/register/[request.personalNumber].post(message = (), kassaName = request.kassaName);
        
        if registrationResult is http:ClientError {
            log:printError(string `Orchestration: Failed to register to OAS - ${registrationResult.message()}`);
            return <http:InternalServerError>{
                body: {
                    success: false,
                    message: "Failed to register benefit in OAS",
                    calculation: calculationResult,
                    registration: (),
                    finalBenefit: ()
                }
            };
        }
        
        log:printInfo(string `Orchestration: Registered to OAS - ${registrationResult.message}`);
        
        // Step 3: Verify registration by looking up in OAS
        MemberLookupResponse|http:ClientError lookupResult = oasOrchClient->/members/[request.personalNumber].get();
        
        if lookupResult is http:ClientError {
            log:printError(string `Orchestration: Failed to verify registration - ${lookupResult.message()}`);
            return <http:InternalServerError>{
                body: {
                    success: false,
                    message: "Failed to verify registration in OAS",
                    calculation: calculationResult,
                    registration: registrationResult,
                    finalBenefit: ()
                }
            };
        }
        
        MemberBenefit? finalBenefit = lookupResult.benefit;
        
        log:printInfo(string `Orchestration: Complete! Member ${request.personalNumber} registered successfully`);
        
        return {
            success: true,
            message: "Benefit successfully calculated and registered",
            calculation: calculationResult,
            registration: registrationResult,
            finalBenefit: finalBenefit
        };
    }
}

// Notification service at /call_service_and_notify
service /call_service_and_notify on combinedListener {

    function init() {
        log:printInfo("Initialize call_service_and_notify on combined listener");
        log:printInfo("Initialize smtpPortStr: " + smtpPortStr);
    }

    // Send notification endpoint
    resource function post send(@http:Payload NotificationOrchRequest request) returns NotificationOrchResponse|http:InternalServerError {
        
        log:printInfo("=== NOTIFICATION ORCHESTRATION SERVICE ===");
        log:printInfo(string `Processing notification: ${request.message}`);
        
        string[] errors = [];
        
        // Step 1: Call notification/servicecall in main.bal (which logs the payload)
        log:printInfo("Step 1: Calling notification/servicecall for logging");
        
        http:Response|http:ClientError serviceCallResult = notificationCallClient->/servicecall.post(request);
        
        if serviceCallResult is http:ClientError {
            string errorMsg = string `Failed to call notification service: ${serviceCallResult.message()}`;
            log:printError(errorMsg);
            errors.push(errorMsg);
            
            return <http:InternalServerError>{
                body: {
                    success: false,
                    message: "Failed to call notification service",
                    errors: errors
                }
            };
        }
        
        // Parse the response from notification/servicecall
        json|http:ClientError serviceCallJson = serviceCallResult.getJsonPayload();
        
        if serviceCallJson is http:ClientError {
            string errorMsg = string `Failed to parse notification service response: ${serviceCallJson.message()}`;
            log:printError(errorMsg);
            errors.push(errorMsg);
            
            return <http:InternalServerError>{
                body: {
                    success: false,
                    message: "Failed to parse notification service response",
                    errors: errors
                }
            };
        }
        
        // Extract log ID from response
        json|error logIdJson = serviceCallJson.logId;
        if logIdJson is error {
            string errorMsg = string `Failed to extract log ID: ${logIdJson.message()}`;
            log:printError(errorMsg);
            errors.push(errorMsg);
            
            return <http:InternalServerError>{
                body: {
                    success: false,
                    message: "Failed to extract log ID from response",
                    errors: errors
                }
            };
        }
        string logId = logIdJson.toString();
        
        log:printInfo(string `Logging successful - Log ID: ${logId}`);
        
        // Step 2: Send email (if requested)
        boolean emailSent = false;
        boolean sendEmailFlag = request.sendEmail ?: true;
        
        if sendEmailFlag {
            log:printInfo("Step 2: Sending email");
            error? emailResult = sendEmail(
                subject = "Notification",
                body = request.message
            );
            
            if emailResult is error {
                string errorMsg = string `Failed to send email: ${emailResult.message()}`;
                log:printError(errorMsg);
                errors.push(errorMsg);
            } else {
                emailSent = true;
                log:printInfo("Email sent successfully");
            }
        }
        
        // Step 3: Send SMS (if requested)
        boolean smsSent = false;
        boolean sendSmsFlag = request.sendSms ?: true;
        
        if sendSmsFlag {
            log:printInfo("Step 3: Sending SMS");
            error? smsResult = sendSms(message = request.message);
            
            if smsResult is error {
                string errorMsg = string `Failed to send SMS: ${smsResult.message()}`;
                log:printError(errorMsg);
                errors.push(errorMsg);
            } else {
                smsSent = true;
                log:printInfo("SMS sent successfully");
            }
        }
        
        log:printInfo("=== NOTIFICATION ORCHESTRATION COMPLETE ===");
        
        // Return response
        if errors.length() > 0 {
            return {
                success: false,
                message: "Notification completed with errors",
                logId: logId,
                emailSent: emailSent,
                smsSent: smsSent,
                errors: errors
            };
        }
        
        return {
            success: true,
            message: "Notification sent successfully",
            logId: logId,
            emailSent: emailSent,
            smsSent: smsSent
        };
    }

    // Health check endpoint
    resource function get health() returns string {
        return "Notification Orchestration Service is running on port 9090";
    }
}

// Helper function to send email
function sendEmail(string subject, string body) returns error? {
    
    error? result = smtpClient->send(
        to = emailTo,
        subject = subject,
        'from = emailFrom,
        body = body
    );
    
    if result is error {
        return error(string `Email sending failed: ${result.message()}`);
    }
    
    return;
}

// Helper function to send SMS
function sendSms(string message) returns error? {
    
    twilio:CreateMessageRequest smsRequest = {
        To: twilioToNumber,
        From: twilioFromNumber,
        Body: message
    };
    
    twilio:Message|error result = twilioClient->createMessage(smsRequest);
    
    if result is error {
        return error(string `SMS sending failed: ${result.message()}`);
    }
    
    return;
}
