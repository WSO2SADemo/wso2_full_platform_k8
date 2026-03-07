// ─── Request / Response types for the scatter-gather service ──────────────────

// Incoming request from the caller
public type MemberLookupRequest record {|
    string personId;
|};

// Successful lookup result returned by a fund backend
public type MemberInfo record {|
    string fund;
    string personId;
    string status;
    string registeredSince;
    string memberType;
|};

// Classified error from a fund backend (timeout, HTTP error, etc.)
public type FundError record {|
    string fund;
    string errorType;  // "TIMEOUT" | "SERVICE_ERROR" | "PARSE_ERROR"
    string message;
|};

// Blank response – the fund responded with 200 OK but no meaningful data
public type BlankResponse record {|
    string fund;
    string message;
|};

// Summary counts
public type ResponseSummary record {|
    int validCount;
    int errorCount;
    int blankCount;
|};

// Aggregated response returned to the caller
public type AggregatedResponse record {|
    string personId;
    int totalFundsQueried;
    ResponseSummary summary;
    MemberInfo[] validResponses;
    FundError[] errors;
    BlankResponse[] blankResponses;
|};
