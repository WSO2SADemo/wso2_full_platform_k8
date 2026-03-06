import ballerina/http;

// Per-request timeout for each fund call (2.9 seconds as per specification)
final decimal FUND_TIMEOUT_SECONDS = 2.9;

// HTTP clients for all 10 unemployment fund backends.
// Each client has a 2.9-second timeout so that high-latency services
// (funds 7 & 8) are classified as timeouts rather than making the
// overall response exceed the 3-second SLA.

final http:Client fund1Client = check new ("http://localhost:9091",
    {timeout: FUND_TIMEOUT_SECONDS}
);

final http:Client fund2Client = check new ("http://localhost:9092",
    {timeout: FUND_TIMEOUT_SECONDS}
);

final http:Client fund3Client = check new ("http://localhost:9093",
    {timeout: FUND_TIMEOUT_SECONDS}
);

final http:Client fund4Client = check new ("http://localhost:9094",
    {timeout: FUND_TIMEOUT_SECONDS}
);

final http:Client fund5Client = check new ("http://localhost:9095",
    {timeout: FUND_TIMEOUT_SECONDS}
);

final http:Client fund6Client = check new ("http://localhost:9096",
    {timeout: FUND_TIMEOUT_SECONDS}
);

// High-latency services – will time out after 2.9 s
final http:Client fund7Client = check new ("http://localhost:9097",
    {timeout: FUND_TIMEOUT_SECONDS}
);

final http:Client fund8Client = check new ("http://localhost:9098",
    {timeout: FUND_TIMEOUT_SECONDS}
);

// Error service – always returns HTTP 500
final http:Client fund9Client = check new ("http://localhost:9099",
    {timeout: FUND_TIMEOUT_SECONDS}
);

// Empty response service – always returns HTTP 200 with empty body
final http:Client fund10Client = check new ("http://localhost:9100",
    {timeout: FUND_TIMEOUT_SECONDS}
);
