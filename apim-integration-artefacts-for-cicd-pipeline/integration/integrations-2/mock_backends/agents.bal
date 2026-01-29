// Agent simulation for testing the orchestration

import ballerina/log;

// Simulate a member applying for unemployment benefits
public function simulateMemberApplication() returns error? {
    
    log:printInfo("=== Simulating Member Application ===");
    
    // Example 1: High income member
    check simulateCompleteFlow(
        personalNumber = "199001011234",
        monthlySalary = 35000.0d,
        kassaName = UNIONENS_AKASSA
    );
    
    // Example 2: Medium income member
    check simulateCompleteFlow(
        personalNumber = "198505152345",
        monthlySalary = 25000.0d,
        kassaName = AKADEMIKERNAS_AKASSA
    );
    
    // Example 3: Low income member
    check simulateCompleteFlow(
        personalNumber = "199212253456",
        monthlySalary = 18000.0d,
        kassaName = ALFA_KASSA
    );
    
    log:printInfo("=== All Simulations Complete ===");
}

// Simulate AF checking member benefits
public function simulateAfLookup(string personalNumber) returns error? {
    
    log:printInfo(string `=== AF Lookup for ${personalNumber} ===`);
    
    MemberBenefit? benefit = check afCheckMemberBenefit(personalNumber = personalNumber);
    
    if benefit is MemberBenefit {
        log:printInfo(string `Found: ${benefit.kassaName}`);
        log:printInfo(string `Daily Allowance: ${benefit.dailyAllowance} SEK`);
        log:printInfo(string `Remaining Days: ${benefit.remainingDays}`);
        log:printInfo(string `Income Base: ${benefit.incomeBase}`);
    } else {
        log:printInfo("Member not found - will receive basic grant (grundbelopp ~223 SEK/day)");
    }
}
