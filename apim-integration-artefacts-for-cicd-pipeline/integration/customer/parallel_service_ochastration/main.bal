import ballerina/http;
import ballerina/log;
import ballerinax/moesif as _;


listener http:Listener orchListener = check new http:Listener(9090);

// ─── Scatter-Gather Service ───────────────────────────────────────────────────
//
// Receives a lookup request, fans out in parallel to all 10 unemployment fund
// backends, waits for every response (within the per-client 2.9 s timeout),
// classifies each result, and returns a single aggregated response.

service /unemployment on orchListener {

    function init() {
        log:printInfo("Scatter-Gather orchestration service started on port 9090");

        // Health check: verify connectivity to mock backend OAS service
        http:Response|http:ClientError healthResult = fund1Client->get("/lookup/health");
        if healthResult is http:ClientError {
            log:printError("Fund1 backend health check failed - could not reach OAS: " + healthResult.message());
        } else if healthResult.statusCode == 200 {
            log:printInfo("Fund1 backend health check passed - connection to OAS is working");
        } else {
            log:printWarn(string `Fund1 backend health check returned unexpected status: ${healthResult.statusCode}`);
        }
    }

    resource function post lookup(@http:Payload MemberLookupRequest request)
            returns AggregatedResponse|http:InternalServerError {

        string personId = request.personId;
        log:printInfo("Scatter: initiating parallel lookup for personId=" + personId);

        // ── SCATTER: spawn all 10 fund calls in parallel using named workers ──
        fork {
            worker fund1 returns MemberInfo|FundError|BlankResponse {
                return callFund(fund1Client, "AEA", personId);
            }
            worker fund2 returns MemberInfo|FundError|BlankResponse {
                return callFund(fund2Client, "Unionen", personId);
            }
            worker fund3 returns MemberInfo|FundError|BlankResponse {
                return callFund(fund3Client, "Akademikernas", personId);
            }
            worker fund4 returns MemberInfo|FundError|BlankResponse {
                return callFund(fund4Client, "IF Metall", personId);
            }
            worker fund5 returns MemberInfo|FundError|BlankResponse {
                return callFund(fund5Client, "Kommunal", personId);
            }
            worker fund6 returns MemberInfo|FundError|BlankResponse {
                return callFund(fund6Client, "Handels", personId);
            }
            worker fund7 returns MemberInfo|FundError|BlankResponse {
                // High-latency service – will time out after 2.9 s
                return callFund(fund7Client, "Vision", personId);
            }
            worker fund8 returns MemberInfo|FundError|BlankResponse {
                // High-latency service – will time out after 2.9 s
                return callFund(fund8Client, "Transport", personId);
            }
            worker fund9 returns MemberInfo|FundError|BlankResponse {
                // Always returns HTTP 503
                return callFund(fund9Client, "SEKO", personId);
            }
            worker fund10 returns MemberInfo|FundError|BlankResponse {
                // Always returns empty 200 OK
                return callFund(fund10Client, "Fastighets", personId);
            }
        }

        // ── GATHER: collect all worker results ────────────────────────────────
        record {
            MemberInfo|FundError|BlankResponse fund1;
            MemberInfo|FundError|BlankResponse fund2;
            MemberInfo|FundError|BlankResponse fund3;
            MemberInfo|FundError|BlankResponse fund4;
            MemberInfo|FundError|BlankResponse fund5;
            MemberInfo|FundError|BlankResponse fund6;
            MemberInfo|FundError|BlankResponse fund7;
            MemberInfo|FundError|BlankResponse fund8;
            MemberInfo|FundError|BlankResponse fund9;
            MemberInfo|FundError|BlankResponse fund10;
        } results = wait {fund1, fund2, fund3, fund4, fund5, fund6, fund7, fund8, fund9, fund10};

        log:printInfo("Gather: all fund responses received for personId=" + personId);

        // ── CLASSIFY & AGGREGATE ──────────────────────────────────────────────
        (MemberInfo|FundError|BlankResponse)[] allResults = [
            results.fund1, results.fund2, results.fund3, results.fund4,
            results.fund5, results.fund6, results.fund7, results.fund8,
            results.fund9, results.fund10
        ];

        MemberInfo[] validResponses = [];
        FundError[] errors = [];
        BlankResponse[] blankResponses = [];

        foreach var result in allResults {
            if result is MemberInfo {
                validResponses.push(result);
            } else if result is FundError {
                errors.push(result);
            } else {
                blankResponses.push(result);
            }
        }

        AggregatedResponse aggregated = {
            personId: personId,
            totalFundsQueried: 10,
            summary: {
                validCount: validResponses.length(),
                errorCount: errors.length(),
                blankCount: blankResponses.length()
            },
            validResponses: validResponses,
            errors: errors,
            blankResponses: blankResponses
        };

        log:printInfo(string `Aggregation complete – valid:${validResponses.length()}, errors:${errors.length()}, blank:${blankResponses.length()}`);
        return aggregated;
    }
}

// ─── callFund: call a single fund backend and classify the raw HTTP response ──
//
// Classification rules:
//   • Network/timeout error          → FundError  (errorType = TIMEOUT | SERVICE_ERROR)
//   • HTTP 4xx/5xx                   → FundError  (errorType = SERVICE_ERROR)
//   • HTTP 200 with empty body / {}  → BlankResponse
//   • HTTP 200 with member data      → MemberInfo

function callFund(http:Client fundClient, string fundName, string personId)
        returns MemberInfo|FundError|BlankResponse {

    // Step 1 – perform the HTTP call; capture transport-level errors (timeout, etc.)
    http:Response|error httpResult = fundClient->get("/lookup?personId=" + personId);

    if httpResult is error {
        string errType = httpResult.message().toLowerAscii().includes("timeout")
            ? "TIMEOUT"
            : "SERVICE_ERROR";
        log:printWarn(string `Fund ${fundName}: ${errType} – ${httpResult.message()}`);
        return <FundError>{fund: fundName, errorType: errType, message: httpResult.message()};
    }

    int statusCode = httpResult.statusCode;

    // Step 2 – non-2xx status codes are technical errors
    if statusCode >= 400 {
        json|error body = httpResult.getJsonPayload();
        string errMsg = body is json ? body.toString() : "HTTP " + statusCode.toString();
        log:printWarn(string `Fund ${fundName}: SERVICE_ERROR HTTP ${statusCode}`);
        return <FundError>{
            fund: fundName,
            errorType: "SERVICE_ERROR",
            message: "HTTP " + statusCode.toString() + " – " + errMsg
        };
    }

    // Step 3 – 2xx response: inspect the JSON body
    json|error jsonBody = httpResult.getJsonPayload();

    if jsonBody is error {
        // Body is missing or not JSON → blank
        return <BlankResponse>{fund: fundName, message: "Empty or non-JSON response"};
    }

    // Empty object {} → blank response (person not registered in this fund)
    map<json>|error jsonMap = jsonBody.cloneWithType();
    if jsonMap is map<json> && jsonMap.length() == 0 {
        log:printInfo(string `Fund ${fundName}: blank – person not registered`);
        return <BlankResponse>{fund: fundName, message: "Person not registered in this fund"};
    }

    // Attempt to deserialise as MemberInfo
    MemberInfo|error memberInfo = jsonBody.cloneWithType(MemberInfo);
    if memberInfo is error {
        return <BlankResponse>{fund: fundName, message: "Unrecognised response format"};
    }

    log:printInfo(string `Fund ${fundName}: valid member found – status=${memberInfo.status}`);
    return memberInfo;
}
