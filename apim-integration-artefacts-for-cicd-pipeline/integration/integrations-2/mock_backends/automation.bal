// Automation and orchestration examples for OAS and Cash Registry integration

import ballerina/http;
import ballerina/log;

// Example orchestration: Complete flow from application to OAS registration
public function simulateCompleteFlow(string personalNumber, decimal monthlySalary, string kassaName) returns error? {
    
    final http:Client cashRegistryClient = check new ("http://localhost:9091");
    final http:Client oasClientLocal = check new ("http://localhost:9092");
    
    log:printInfo("=== Starting Complete Benefit Registration Flow ===");
    
    // Step 1: Member submits application to Cash Registry
    log:printInfo(string `Step 1: Submitting application for ${personalNumber}`);
    
    BenefitCalculationRequest applicationRequest = {
        personalNumber: personalNumber,
        workCertificates: ["cert-001", "cert-002"],
        previousMonthlySalary: monthlySalary
    };
    
    BenefitCalculationResponse calculationResponse = check cashRegistryClient->/cashregistry/applications.post(applicationRequest);
    
    log:printInfo(string `Step 1 Complete: Approved=${calculationResponse.approved}, Daily Allowance=${calculationResponse.dailyAllowance} SEK`);
    
    // Step 2: Cash Registry registers the benefit to OAS
    log:printInfo(string `Step 2: Registering benefit to OAS via ${kassaName}`);
    
    RegistrationResponse registrationResponse = check cashRegistryClient->/cashregistry/register/[personalNumber].post(message = (), kassaName = kassaName);
    
    log:printInfo(string `Step 2 Complete: ${registrationResponse.message}`);
    
    // Step 3: Simulate AF lookup in OAS
    log:printInfo(string `Step 3: AF looking up member ${personalNumber} in OAS`);
    
    MemberLookupResponse lookupResponse = check oasClientLocal->/oas/members/[personalNumber].get();
    
    if lookupResponse.found {
        MemberBenefit? benefit = lookupResponse.benefit;
        if benefit is MemberBenefit {
            log:printInfo(string `Step 3 Complete: Member found! Daily Allowance: ${benefit.dailyAllowance} SEK, Remaining Days: ${benefit.remainingDays}`);
        }
    } else {
        log:printInfo("Step 3 Complete: Member not found in OAS");
    }
    
    log:printInfo("=== Flow Complete ===");
}

// Example: AF checks OAS for member benefit
public function afCheckMemberBenefit(string personalNumber) returns MemberBenefit?|error {
    
    final http:Client oasClientLocal = check new ("http://localhost:9092");
    
    MemberLookupResponse lookupResponse = check oasClientLocal->/oas/members/[personalNumber].get();
    
    if lookupResponse.found {
        return lookupResponse.benefit;
    }
    
    return ();
}
