import ballerina/time;

// In-memory storage for OAS member benefits
map<MemberBenefit> oasMemberDatabase = {};

// In-memory storage for Cash Registry pending applications
map<BenefitCalculationRequest> cashRegistryApplications = {};

// Helper function to get current timestamp
function getCurrentTimestamp() returns string {
    time:Utc currentTime = time:utcNow();
    string timestamp = time:utcToString(currentTime);
    return timestamp;
}
