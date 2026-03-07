// Types for unemployment fund lookup services

public type MemberInfo record {|
    string fund;
    string personId;
    string status;
    string registeredSince;
    string memberType;
|};

public type ErrorResponse record {|
    string 'error;
    string code;
    string fund;
|};

// ─── Types for Fund11 – Notification Receiver (port 9101) ────────────────────

// Notification message received from the store-and-forward integration
public type IncomingNotification record {|
    string messageId;
    string personId;
    string notificationType;
    json data;
    int retryCount;
    string createdAt;
    string lastAttemptAt;
|};

// Acknowledgement returned to the integration on successful delivery
public type NotificationAck record {|
    string status;
    string messageId;
    string receivedAt;
|};
