// Cash Registry calculation response
public type BenefitCalculationResponse record {|
    boolean approved;
    decimal dailyAllowance;
    string incomeBase;
    int totalDays;
    string message;
|};

// Response from OAS registration
public type RegistrationResponse record {|
    boolean success;
    string message;
    string registrationId?;
|};

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

// Cash Registry calculation request
public type BenefitCalculationRequest record {|
    string personalNumber;
    string[] workCertificates;
    decimal previousMonthlySalary;
|};

// Member lookup response
public type MemberLookupResponse record {|
    boolean found;
    MemberBenefit? benefit;
|};