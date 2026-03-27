import ballerina/http;
import ballerina/log;
import ballerina/lang.runtime;

// ─── Listeners ────────────────────────────────────────────────────────────────

listener http:Listener fund1Listener = check new http:Listener(9091);
listener http:Listener fund2Listener = check new http:Listener(9092);
listener http:Listener fund3Listener = check new http:Listener(9093);
listener http:Listener fund4Listener = check new http:Listener(9094);
listener http:Listener fund5Listener = check new http:Listener(9095);
listener http:Listener fund6Listener = check new http:Listener(9096);
listener http:Listener fund7Listener = check new http:Listener(9097);  // slow
listener http:Listener fund8Listener = check new http:Listener(9098);  // slow
listener http:Listener fund9Listener = check new http:Listener(9099);  // error
listener http:Listener fund10Listener = check new http:Listener(9100); // empty
listener http:Listener fund11Listener = check new http:Listener(9101); // notification receiver (store-and-forward backend)

// ─── Mock member database (shared across all funds) ───────────────────────────
// personId format: bare personnummer without country prefix (e.g. "199001011234")

final map<MemberInfo> & readonly memberDatabase = {
    "199001011234": {fund: "", personId: "199001011234", status: "ACTIVE", registeredSince: "2015-06-01", memberType: "FULL"},
    "198505152345": {fund: "", personId: "198505152345", status: "ACTIVE", registeredSince: "2018-03-10", memberType: "PART_TIME"},
    "197212203456": {fund: "", personId: "197212203456", status: "INACTIVE", registeredSince: "2010-01-15", memberType: "FULL"},
    "200102044567": {fund: "", personId: "200102044567", status: "ACTIVE", registeredSince: "2022-09-01", memberType: "STUDENT"}
};

// ─── Fund registration: which fund(s) each person is registered in ─────────────
// Each person is registered in at most 1-2 funds for demo variety.
// Empty array = not registered anywhere; use fund name strings matching the
// fundName parameter passed to buildMemberInfo().

final map<string[]> & readonly fundRegistrations = {
    "199001011234": ["AEA", "Kommunal"],
    "198505152345": ["Unionen"],
    "197212203456": ["IF Metall"],
    "200102044567": ["Akademikernas"]
};

// ─── Helper: build a valid MemberInfo for a specific fund ─────────────────────
// Returns a result only if the person is registered in the given fund.

function buildMemberInfo(string fundName, string personId) returns MemberInfo? {
    MemberInfo? base = memberDatabase[personId];
    string[]? registeredFunds = fundRegistrations[personId];
    if base is MemberInfo && registeredFunds is string[] && registeredFunds.indexOf(fundName) != () {
        return {
            fund: fundName,
            personId: base.personId,
            status: base.status,
            registeredSince: base.registeredSince,
            memberType: base.memberType
        };
    }
    return ();
}

// ─── Fund 1 – AEA (fast, ~100 ms) ────────────────────────────────────────────

service /lookup on fund1Listener {
    function init() {
        log:printInfo("Fund 1 – AEA lookup service started on port 9091");
    }

    resource function get .(string personId) returns MemberInfo|http:Response {
        runtime:sleep(0.1d);
        MemberInfo? member = buildMemberInfo("AEA", personId);
        if member is MemberInfo {
            return member;
        }
        http:Response empty = new;
        empty.statusCode = 200;
        empty.setJsonPayload({fund: "AEA"});
        return empty;
    }

    resource function get health() returns string {
        return "fund1Listener Service is running on port 9091";
    }
}

// ─── Fund 2 – Unionen (fast, ~200 ms) ────────────────────────────────────────

service /lookup on fund2Listener {
    function init() {
        log:printInfo("Fund 2 – Unionen lookup service started on port 9092");
    }

    resource function get .(string personId) returns MemberInfo|http:Response {
        runtime:sleep(0.2d);
        MemberInfo? member = buildMemberInfo("Unionen", personId);
        if member is MemberInfo {
            return member;
        }
        http:Response empty = new;
        empty.statusCode = 200;
        empty.setJsonPayload({fund: "Unionen"});
        return empty;
    }
}

// ─── Fund 3 – Akademikernas (fast, ~150 ms) ───────────────────────────────────

service /lookup on fund3Listener {
    function init() {
        log:printInfo("Fund 3 – Akademikernas lookup service started on port 9093");
    }

    resource function get .(string personId) returns MemberInfo|http:Response {
        runtime:sleep(0.15d);
        MemberInfo? member = buildMemberInfo("Akademikernas", personId);
        if member is MemberInfo {
            return member;
        }
        http:Response empty = new;
        empty.statusCode = 200;
        empty.setJsonPayload({fund: "Akademikernas"});
        return empty;
    }
}

// ─── Fund 4 – IF Metall (fast, ~300 ms) ──────────────────────────────────────

service /lookup on fund4Listener {
    function init() {
        log:printInfo("Fund 4 – IF Metall lookup service started on port 9094");
    }

    resource function get .(string personId) returns MemberInfo|http:Response {
        runtime:sleep(0.3d);
        MemberInfo? member = buildMemberInfo("IF Metall", personId);
        if member is MemberInfo {
            return member;
        }
        http:Response empty = new;
        empty.statusCode = 200;
        empty.setJsonPayload({fund: "IF Metall"});
        return empty;
    }
}

// ─── Fund 5 – Kommunal (fast, ~250 ms) ───────────────────────────────────────

service /lookup on fund5Listener {
    function init() {
        log:printInfo("Fund 5 – Kommunal lookup service started on port 9095");
    }

    resource function get .(string personId) returns MemberInfo|http:Response {
        runtime:sleep(0.25d);
        MemberInfo? member = buildMemberInfo("Kommunal", personId);
        if member is MemberInfo {
            return member;
        }
        http:Response empty = new;
        empty.statusCode = 200;
        empty.setJsonPayload({fund: "Kommunal"});
        return empty;
    }
}

// ─── Fund 6 – Handels (fast, ~400 ms) ────────────────────────────────────────

service /lookup on fund6Listener {
    function init() {
        log:printInfo("Fund 6 – Handels lookup service started on port 9096");
    }

    resource function get .(string personId) returns MemberInfo|http:Response {
        runtime:sleep(0.4d);
        MemberInfo? member = buildMemberInfo("Handels", personId);
        if member is MemberInfo {
            return member;
        }
        http:Response empty = new;
        empty.statusCode = 200;
        empty.setJsonPayload({fund: "Handels"});
        return empty;
    }
}

// ─── Fund 7 – Vision (HIGH LATENCY – 3.5 s, will exceed 2.9 s client timeout) ─

service /lookup on fund7Listener {
    function init() {
        log:printInfo("Fund 7 – Vision lookup service started on port 9097 (high latency)");
    }

    resource function get .(string personId) returns MemberInfo|http:Response {
        runtime:sleep(3.5d);  // exceeds the 2.9 s client timeout → timeout error
        MemberInfo? member = buildMemberInfo("Vision", personId);
        if member is MemberInfo {
            return member;
        }
        http:Response empty = new;
        empty.statusCode = 200;
        empty.setJsonPayload({fund: "Vision"});
        return empty;
    }
}

// ─── Fund 8 – Transport (HIGH LATENCY – 4.0 s, will exceed 2.9 s client timeout) ─

service /lookup on fund8Listener {
    function init() {
        log:printInfo("Fund 8 – Transport lookup service started on port 9098 (high latency)");
    }

    resource function get .(string personId) returns MemberInfo|http:Response {
        runtime:sleep(4.0d);  // exceeds the 2.9 s client timeout → timeout error
        MemberInfo? member = buildMemberInfo("Transport", personId);
        if member is MemberInfo {
            return member;
        }
        http:Response empty = new;
        empty.statusCode = 200;
        empty.setJsonPayload({fund: "Transport"});
        return empty;
    }
}

// ─── Fund 9 – SEKO (always returns HTTP 503 technical error) ──────────────────

service /lookup on fund9Listener {
    function init() {
        log:printInfo("Fund 9 – SEKO lookup service started on port 9099 (error service)");
    }

    resource function get .(string personId) returns http:InternalServerError {
        return {
            body: <ErrorResponse>{
                'error: "Service temporarily unavailable",
                code: "FUND_UNAVAILABLE",
                fund: "SEKO"
            }
        };
    }
}

// ─── Fund 10 – Fastighets (always returns empty 200 OK) ──────────────────────

service /lookup on fund10Listener {
    function init() {
        log:printInfo("Fund 10 – Fastighets lookup service started on port 9100 (empty response)");
    }

    resource function get .(string personId) returns json {
        return {fund: "Fastighets"};
    }
}

// ─── Fund 11 – Notification Receiver (Store-and-Forward backend, port 9101) ───
//
// Simulates a receiving system that can be toggled offline to demonstrate
// the store-and-forward pattern (service window / outage simulation).
//
// Endpoints:
//   POST /notifications          – receive a notification from the integration
//   POST /notifications/admin/toggle  – toggle online/offline (simulate outage)
//   GET  /notifications/admin/status  – check current availability

boolean notificationServiceOnline = true;

service /notifications on fund11Listener {

    function init() {
        log:printInfo("Fund 11 – Notification Receiver started on port 9101");
    }

    resource function get health() returns string {
        return "Fund 11 – Notification Receiver is running on port 9101";
    }

    // Receive notification from store-and-forward integration
    resource function post .(IncomingNotification notification)
            returns NotificationAck|http:ServiceUnavailable {

        if !notificationServiceOnline {
            log:printWarn(string `Notification rejected – service window active (messageId=${notification.messageId})`);
            return <http:ServiceUnavailable>{
                body: {
                    'error: "Service window in progress – system temporarily offline",
                    code: "SERVICE_WINDOW"
                }
            };
        }

        log:printInfo(string `Notification received: messageId=${notification.messageId} type=${notification.notificationType} retryCount=${notification.retryCount}`);
        return <NotificationAck>{
            status: "RECEIVED",
            messageId: notification.messageId,
            receivedAt: notification.lastAttemptAt
        };
    }

    // Toggle service availability (simulate outage / restore)
    resource function post admin/toggle() returns json {
        notificationServiceOnline = !notificationServiceOnline;
        string state = notificationServiceOnline ? "ONLINE" : "OFFLINE (service window active)";
        log:printInfo("Notification Receiver toggled → " + state);
        return {available: notificationServiceOnline, state: state};
    }

    // Check current availability
    resource function get admin/status() returns json {
        string state = notificationServiceOnline ? "ONLINE" : "OFFLINE (service window active)";
        return {available: notificationServiceOnline, state: state};
    }
}
