// Orchestration service that coordinates between Cash Registry and OAS
// This service provides a unified API for clients to interact with the system

import ballerina/http;
import ballerina/log;
import ballerinax/wso2.controlplane as _;
import ballerinax/moesif as _;

listener http:Listener orchestrationListener = check new (9090);

// Clients for backend services
final http:Client cashRegistryOrchClient = check new (cashRegistryUrl);
final http:Client oasOrchClient = check new (oasUrl);

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

service /api on orchestrationListener {

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
