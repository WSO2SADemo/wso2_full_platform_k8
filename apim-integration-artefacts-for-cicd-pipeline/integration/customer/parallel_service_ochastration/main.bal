import ballerina/http;
import ballerina/log;
import ballerinax/moesif as _;
import ballerina/io;
// import ballerinax/wso2.icp as _;


listener http:Listener orchListener = check new http:Listener(9090);

// ─── Scatter-Gather Service ───────────────────────────────────────────────────
//
// Receives a lookup request, fans out in parallel to all 10 unemployment fund
// backends, waits for every response (within the per-client 2.9 s timeout),
// classifies each result, and returns a single aggregated response.

service /unemployment on orchListener {

    function init() {
        log:printInfo("Scatter-Gather orchestration service started on port 9090");
    }

    resource function get health(http:Headers headers) returns http:Ok {
        string[] headerNames = headers.getHeaderNames();
        log:printInfo("Health endpoint - Received headers: " + headerNames.toString());
        foreach string headerName in headerNames {
            string[]|http:HeaderNotFoundError headerValues = headers.getHeaders(headerName);
            if headerValues is string[] {
                log:printInfo(string `Header: ${headerName} = ${headerValues.toString()}`);
            }
        }
        return {body: {status: "UP"}};
    }

    resource function post lookup(@http:Payload MemberLookupRequest request, http:Headers headers)
            returns AggregatedResponse|http:InternalServerError|error {

        string personId = request.personId;
        string[] headerNames = headers.getHeaderNames();
        log:printInfo("Lookup endpoint - Received headers: " + headerNames.toString());
        foreach string headerName in headerNames {
            string[]|http:HeaderNotFoundError headerValues = headers.getHeaders(headerName);
            if headerValues is string[] {
                log:printInfo(string `Header: ${headerName} = ${headerValues.toString()}`);
            }
        }
        log:printInfo("Scatter: initiating parallel lookup for personId=" + personId);

        // Get fundUrls header if present
        string|http:HeaderNotFoundError fundUrlsHeader = headers.getHeader("fundUrls");
        AggregatedResponse aggregated = {
            personId: personId,
            totalFundsQueried: 0,
            summary: {
                validCount: 0,
                errorCount: 0,
                blankCount: 0
            },
            validResponses: [],
            errors: [],
            blankResponses: []
        };
        if fundUrlsHeader is string {
            log:printInfo("fundUrls header value: " + fundUrlsHeader);
            // Split the header value by comma to get array of URLs
            string:RegExp commaPattern = re `,`;
            string[] fundUrlsArray = commaPattern.split(fundUrlsHeader);
            log:printInfo("Split fundUrls array: " + fundUrlsArray.toString());
            log:printInfo("Number of fund URLs: " + fundUrlsArray.length().toString());

            future<MemberInfo|FundError|BlankResponse>[] fArray = [];
            MemberInfo[] validResponses = [];
            FundError[] errors = [];
            BlankResponse[] blankResponses = [];

            // parameterizedFundUrl = "http://swedish.{FUND_NAME}.org:9091"
            foreach string fundUrlInfo in fundUrlsArray {
                io:println(fundUrlInfo);
                // fundUrl = parameterizedFundUrl.repplaceAll("{FUND_NAME}", fundUrlInfo); // Remove any whitespace
                final http:Client fundClient = check new (fundUrlInfo,
                    {timeout: FUND_TIMEOUT_SECONDS}
                );
                future<MemberInfo|FundError|BlankResponse> f = callFund(fundClient, fundUrlInfo, personId);
                fArray.push(f);
            }
            foreach future<MemberInfo|FundError|BlankResponse> f in fArray {
                MemberInfo|FundError|BlankResponse result = check wait f;
                if result is MemberInfo {
                    validResponses.push(result);
                } else if result is FundError {
                    errors.push(result);
                } else {
                    blankResponses.push(result);
                }
            }
            aggregated = {
                    personId: personId,
                    totalFundsQueried: fundUrlsArray.length(),
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
        } else {
            log:printInfo("fundUrls header not found in request");
        }

        // // ── SCATTER: spawn all 10 fund calls in parallel using named workers ──
        // fork {
        //     worker fund1 returns MemberInfo|FundError|BlankResponse {
        //         return callFund(fund1Client, "AEA", personId);
        //     }
        //     worker fund2 returns MemberInfo|FundError|BlankResponse {
        //         return callFund(fund2Client, "Unionen", personId);
        //     }
        //     worker fund3 returns MemberInfo|FundError|BlankResponse {
        //         return callFund(fund3Client, "Akademikernas", personId);
        //     }
        //     worker fund4 returns MemberInfo|FundError|BlankResponse {
        //         return callFund(fund4Client, "IF Metall", personId);
        //     }
        //     worker fund5 returns MemberInfo|FundError|BlankResponse {
        //         return callFund(fund5Client, "Kommunal", personId);
        //     }
        //     worker fund6 returns MemberInfo|FundError|BlankResponse {
        //         return callFund(fund6Client, "Handels", personId);
        //     }
        //     worker fund7 returns MemberInfo|FundError|BlankResponse {
        //         // High-latency service – will time out after 2.9 s
        //         return callFund(fund7Client, "Vision", personId);
        //     }
        //     worker fund8 returns MemberInfo|FundError|BlankResponse {
        //         // High-latency service – will time out after 2.9 s
        //         return callFund(fund8Client, "Transport", personId);
        //     }
        //     worker fund9 returns MemberInfo|FundError|BlankResponse {
        //         // Always returns HTTP 503
        //         return callFund(fund9Client, "SEKO", personId);
        //     }
        //     worker fund10 returns MemberInfo|FundError|BlankResponse {
        //         // Always returns empty 200 OK
        //         return callFund(fund10Client, "Fastighets", personId);
        //     }
        // }

        // ── GATHER: collect all worker results ────────────────────────────────
        // record {
        //     MemberInfo|FundError|BlankResponse fund1;
        //     MemberInfo|FundError|BlankResponse fund2;
        //     MemberInfo|FundError|BlankResponse fund3;
        //     MemberInfo|FundError|BlankResponse fund4;
        //     MemberInfo|FundError|BlankResponse fund5;
        //     MemberInfo|FundError|BlankResponse fund6;
        //     MemberInfo|FundError|BlankResponse fund7;
        //     MemberInfo|FundError|BlankResponse fund8;
        //     MemberInfo|FundError|BlankResponse fund9;
        //     MemberInfo|FundError|BlankResponse fund10;
        // } results = wait {fund1, fund2, fund3, fund4, fund5, fund6, fund7, fund8, fund9, fund10};

        // ── CLASSIFY & AGGREGATE ──────────────────────────────────────────────
        // (MemberInfo|FundError|BlankResponse)[] allResults = [
        //     results.fund1, results.fund2, results.fund3, results.fund4,
        //     results.fund5, results.fund6, results.fund7, results.fund8,
        //     results.fund9, results.fund10
        // ];

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

isolated function callFund(http:Client fundClient, string fundUrl, string personId)
        returns future<MemberInfo|FundError|BlankResponse> {

    worker A returns MemberInfo|FundError|BlankResponse {
        // Step 1 – perform the HTTP call; capture transport-level errors (timeout, etc.)
        http:Response|error httpResult = fundClient->get("/lookup?personId=" + personId);
        if httpResult is error {
            string errType = httpResult.message().toLowerAscii().includes("timeout")
                ? "TIMEOUT"
                : "SERVICE_ERROR";
            log:printWarn(string `Fund ${fundUrl}: ${errType} – ${httpResult.message()}`);
            return <FundError>{fund: fundUrl, errorType: errType, message: httpResult.message(), url: fundUrl};
        }

        int statusCode = httpResult.statusCode;

        // Step 2 – non-2xx status codes: try to extract fund name from body
        if statusCode >= 400 {
            json|error body = httpResult.getJsonPayload();
            string errMsg = body is json ? body.toString() : "HTTP " + statusCode.toString();
            string fundName = fundUrl;
            if body is map<json> {
                json|error fundField = body.fund;
                if fundField is json {
                    fundName = fundField.toString();
                }
            }
            log:printWarn(string `Fund ${fundName}: SERVICE_ERROR HTTP ${statusCode}`);
            return <FundError>{
                fund: fundName,
                errorType: "SERVICE_ERROR",
                message: "HTTP " + statusCode.toString() + " – " + errMsg,
                url: fundUrl
            };
        }

        // Step 3 – 2xx response: inspect the JSON body
        json|error jsonBody = httpResult.getJsonPayload();
        if jsonBody is error {
            return <BlankResponse>{fund: fundUrl, message: "Empty or non-JSON response", url: fundUrl};
        }

        // Attempt to deserialise as MemberInfo (valid registered member)
        MemberInfo|error memberInfo = jsonBody.cloneWithType(MemberInfo);
        if memberInfo is MemberInfo {
            log:printInfo(string `Fund ${memberInfo.fund}: valid member found – status=${memberInfo.status}`);
            return <MemberInfo>{
                fund: memberInfo.fund,
                personId: memberInfo.personId,
                status: memberInfo.status,
                registeredSince: memberInfo.registeredSince,
                memberType: memberInfo.memberType,
                url: fundUrl
            };
        }

        // Not a full MemberInfo – backend returned a blank response with fund name
        string blankFundName = fundUrl;
        json|error fundField = jsonBody.fund;
        if fundField is json {
            blankFundName = fundField.toString();
        }
        log:printInfo(string `Fund ${blankFundName}: blank – person not registered`);
        return <BlankResponse>{fund: blankFundName, message: "Person not registered in this fund", url: fundUrl};
    }

    return A;

}
