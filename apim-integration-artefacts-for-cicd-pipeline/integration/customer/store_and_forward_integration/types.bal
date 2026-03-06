// ─── Types for Store-and-Forward Integration ──────────────────────────────────

// Incoming request from the API caller
public type NotificationRequest record {|
    string personId;
    string notificationType;  // e.g. "STATUS_CHANGE", "BENEFIT_UPDATE", "REGISTRATION"
    json data;
|};

// Full message envelope stored in RabbitMQ and forwarded to the backend
public type NotificationMessage record {|
    string messageId;
    string personId;
    string notificationType;
    json data;
    int retryCount;       // 0 = first attempt, 1-3 = automatic retries
    string createdAt;     // ISO-8601 timestamp when first queued
    string lastAttemptAt; // ISO-8601 timestamp of most recent delivery attempt
|};

// 202 Accepted response returned immediately to the caller
public type QueuedResponse record {|
    string messageId;
    string status;   // "QUEUED"
    string message;
    string timestamp;
|};

// Response from POST /notifications/retry
public type RetryResult record {|
    string status;     // "REQUEUED" | "DLQ_EMPTY" | "ERROR"
    string message;
    string? messageId;
|};

// Response from GET /notifications/dlq-status
public type DlqStatus record {|
    int count;
    NotificationMessage[] messages;
|};
