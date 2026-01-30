// Notification service that calls logging service and sends email/SMS
// This service orchestrates the complete notification flow

import ballerina/http;
import ballerina/log;
import ballerina/email;
import ballerinax/twilio;
// import ballerinax/wso2.controlplane as _;

listener http:Listener notificationServiceListener = check new (9097);

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

int smtpPort = check int:fromString(smtpPortStr);


// Email client
final email:SmtpClient smtpClient = check new (smtpHost, smtpUsername, smtpPassword, {
    port: smtpPort,
    security: email:START_TLS_AUTO
});

// Twilio client
final twilio:Client twilioClient = check new ({
    auth: {
        accountSid: twilioAccountSid,
        authToken: twilioAuthToken
    }
});


// HTTP client for notification service in main.bal
final http:Client notificationCallClient = check new ("http://localhost:9096");

service /notification on notificationServiceListener {

    // Send notification endpoint
    resource function post send(@http:Payload NotificationOrchRequest request) returns NotificationOrchResponse|http:InternalServerError {
        
        log:printInfo("=== NOTIFICATION ORCHESTRATION SERVICE ===");
        log:printInfo(string `Processing notification: ${request.message}`);
        
        string[] errors = [];
        
        // Step 1: Call notification/servicecall in main.bal (which logs the payload)
        log:printInfo("Step 1: Calling notification/servicecall for logging");
        
        http:Response|http:ClientError serviceCallResult = notificationCallClient->/notification/servicecall.post(request);
        
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
        boolean sendEmailFlag = request.sendEmail ?: true; // Default to true
        
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
        boolean sendSmsFlag = request.sendSms ?: true; // Default to true
        
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
        return "Notification Orchestration Service is running on port 9097";
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
