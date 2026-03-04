// Bank account record type
public type BankAccount record {|
    string username;
    string accountNumber;
    decimal savingsBalance;
    decimal currentAccountBalance;
    string status;
|};

// Request types
public type UsernameRequest record {|
    string username;
|};

// Response types
public type AccountResponse record {|
    string accountNumber;
    decimal savingsBalance;
    decimal currentAccountBalance;
    string status;
|};

public type ErrorResponse record {|
    string message;
|};

public type SuccessResponse record {|
    string message;
|};

// Transfer request type
public type TransferRequest record {|
    string username;
    string fromAccount; // "savings" or "current"
    string toAccount; // "savings" or "current"
    decimal amount;
|};

// Transaction record type
public type Transaction record {|
    string transactionId;
    string transactionType; // "TRANSFER", "DEPOSIT", "WITHDRAWAL"
    decimal amount;
    string fromAccount;
    string toAccount;
    string timestamp;
    string status;
|};

// Contact info request type
public type ContactUpdateRequest record {|
    string username;
    string email?;
    string phone?;
    string address?;
|};

// Contact info type
public type ContactInfo record {|
    string email;
    string phone;
    string address;
|};

// Loan request type
public type LoanRequest record {|
    string username;
    string loanType; // "PERSONAL", "HOME", "AUTO"
    decimal amount;
    int termMonths;
    string purpose;
|};

// Loan application response
public type LoanApplicationResponse record {|
    string applicationId;
    string status; // "PENDING", "APPROVED", "REJECTED"
    string message;
|};
