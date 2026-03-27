// Insurance policy record
public type InsurancePolicy record {|
    string username;
    string policyNumber;
    string policyType;   // "HEALTH"
    decimal coverageAmount;
    decimal premiumAmount;
    string startDate;
    string endDate;
    string status;       // "ACTIVE", "EXPIRED", "SUSPENDED"
|};

// Claim record
public type Claim record {|
    string claimId;
    string claimType;
    decimal amount;
    string description;
    string submittedDate;
    string status;       // "PENDING", "APPROVED", "REJECTED"
|};

// Request types
public type UsernameRequest record {|
    string username;
|};

public type ClaimSubmitRequest record {|
    string username;
    string claimType;
    decimal amount;
    string description;
|};

public type PolicyUpdateRequest record {|
    string policyNumber;
    string status;
|};

// Response types
public type PolicyResponse record {|
    string policyNumber;
    string policyType;
    decimal coverageAmount;
    decimal premiumAmount;
    string startDate;
    string endDate;
    string status;
|};

public type SuccessResponse record {|
    string message;
    true success;
|};

public type ErrorResponse record {|
    string message;
    string? errorCode = ();
|};
