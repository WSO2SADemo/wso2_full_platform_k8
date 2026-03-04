import ballerina/http;
import ballerina/io;
import ballerina/time;
// import ballerinax/wso2.apim.catalog as _;
// import ballerinax/moesif as _;

// Customer API listener on port 8082
listener http:Listener customerListener = check new http:Listener(8082);

// Agent API listener on port 8083
listener http:Listener agentListener = check new http:Listener(8083);

// Customer-facing API service
service /insurance/customer on customerListener {

    function init() {
        io:println("Insurance customer service initialized on port 8082");
    }

    // Get policy details by username
    resource function post policy(@http:Payload UsernameRequest request) returns PolicyResponse|ErrorResponse {
        string username = request.username;
        InsurancePolicy? policy = policyDatabase[username];

        if policy is () {
            return {message: "No policy found for username: " + username};
        }

        return {
            policyNumber: policy.policyNumber,
            policyType: policy.policyType,
            coverageAmount: policy.coverageAmount,
            premiumAmount: policy.premiumAmount,
            startDate: policy.startDate,
            endDate: policy.endDate,
            status: policy.status
        };
    }

    // Get claims list by username
    resource function post claims(@http:Payload UsernameRequest request) returns Claim[]|ErrorResponse {
        string username = request.username;
        InsurancePolicy? policy = policyDatabase[username];

        if policy is () {
            return {message: "No policy found for username: " + username};
        }

        Claim[]? userClaims = claimsDatabase[username];
        if userClaims is () {
            return [];
        }
        return userClaims;
    }

    // Submit a new claim
    resource function post claims/submit(@http:Payload ClaimSubmitRequest request) returns SuccessResponse|ErrorResponse {
        string username = request.username;
        InsurancePolicy? policy = policyDatabase[username];

        if policy is () {
            return { message: "No policy found for username: " + username };
        }

        if policy.status != "ACTIVE" {
            return {message: "Cannot submit claim. Policy status is: " + policy.status};
        }

        time:Utc currentTime = time:utcNow();
        string claimId = "CLM-" + currentTime[0].toString();

        Claim newClaim = {
            claimId: claimId,
            claimType: request.claimType,
            amount: request.amount,
            description: request.description,
            submittedDate: time:utcToString(currentTime).substring(0, 10),
            status: "PENDING"
        };

        Claim[]? existing = claimsDatabase[username];
        if existing is () {
            claimsDatabase[username] = [newClaim];
        } else {
            existing.push(newClaim);
        }

        return {message: "Claim " + claimId + " submitted successfully and is under review", success: true};
    }
}

// Agent-facing API service
service /insurance/agent on agentListener {

    function init() {
        io:println("Insurance agent service initialized on port 8083");
    }

    // List all policies
    resource function get policies() returns InsurancePolicy[] {
        return policyDatabase.toArray();
    }

    // Update policy status
    resource function post policy/update(@http:Payload PolicyUpdateRequest request) returns SuccessResponse|ErrorResponse {
        string policyNumber = request.policyNumber;

        foreach string username in policyDatabase.keys() {
            InsurancePolicy? policy = policyDatabase[username];
            if policy is InsurancePolicy && policy.policyNumber == policyNumber {
                policy.status = request.status;
                policyDatabase[username] = policy;
                return {message: "Policy " + policyNumber + " updated to status: " + request.status, success: true};
            }
        }

        return {message: "Policy not found: " + policyNumber};
    }
}
