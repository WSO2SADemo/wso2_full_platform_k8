// Types for OAS and Cash Registry systems

// Member benefit information stored in OAS
public type MemberBenefit record {|
    string personalNumber;
    string kassaName;
    boolean isMember;
    decimal dailyAllowance;
    string incomeBase;
    int remainingDays;
    string registrationDate;
    string lastUpdated;
|};

// Request to register/update member benefit in OAS
public type BenefitRegistrationRequest record {|
    string personalNumber;
    string kassaName;
    decimal dailyAllowance;
    string incomeBase;
    int totalDays;
|};

// Response from OAS registration
public type RegistrationResponse record {|
    boolean success;
    string message;
    string registrationId?;
|};

// Member lookup response
public type MemberLookupResponse record {|
    boolean found;
    MemberBenefit? benefit;
|};

// Cash Registry calculation request
public type BenefitCalculationRequest record {|
    string personalNumber;
    string[] workCertificates;
    decimal previousMonthlySalary;
|};

// Cash Registry calculation response
public type BenefitCalculationResponse record {|
    boolean approved;
    decimal dailyAllowance;
    string incomeBase;
    int totalDays;
    string message;
|};
