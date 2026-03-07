import ballerina/http;
import ballerina/os;

// Per-request timeout for each fund call (2.9 seconds as per specification)
final decimal FUND_TIMEOUT_SECONDS = 2.9;

// Configurable URLs – defaults read from env vars (populated via K8s ConfigMap).
// Override locally via Config.toml.
configurable string fund1Url = os:getEnv("fund1Url");
configurable string fund2Url = os:getEnv("fund2Url");
configurable string fund3Url = os:getEnv("fund3Url");
configurable string fund4Url = os:getEnv("fund4Url");
configurable string fund5Url = os:getEnv("fund5Url");
configurable string fund6Url = os:getEnv("fund6Url");
configurable string fund7Url = os:getEnv("fund7Url");
configurable string fund8Url = os:getEnv("fund8Url");
configurable string fund9Url = os:getEnv("fund9Url");
configurable string fund10Url = os:getEnv("fund10Url");

// HTTP clients for all 10 unemployment fund backends.
// Each client has a 2.9-second timeout so that high-latency services
// (funds 7 & 8) are classified as timeouts rather than making the
// overall response exceed the 3-second SLA.

final http:Client fund1Client = check new (fund1Url,
    {timeout: FUND_TIMEOUT_SECONDS}
);

final http:Client fund2Client = check new (fund2Url,
    {timeout: FUND_TIMEOUT_SECONDS}
);

final http:Client fund3Client = check new (fund3Url,
    {timeout: FUND_TIMEOUT_SECONDS}
);

final http:Client fund4Client = check new (fund4Url,
    {timeout: FUND_TIMEOUT_SECONDS}
);

final http:Client fund5Client = check new (fund5Url,
    {timeout: FUND_TIMEOUT_SECONDS}
);

final http:Client fund6Client = check new (fund6Url,
    {timeout: FUND_TIMEOUT_SECONDS}
);

// High-latency services – will time out after 2.9 s
final http:Client fund7Client = check new (fund7Url,
    {timeout: FUND_TIMEOUT_SECONDS}
);

final http:Client fund8Client = check new (fund8Url,
    {timeout: FUND_TIMEOUT_SECONDS}
);

// Error service – always returns HTTP 500
final http:Client fund9Client = check new (fund9Url,
    {timeout: FUND_TIMEOUT_SECONDS}
);

// Empty response service – always returns HTTP 200 with empty body
final http:Client fund10Client = check new (fund10Url,
    {timeout: FUND_TIMEOUT_SECONDS}
);
