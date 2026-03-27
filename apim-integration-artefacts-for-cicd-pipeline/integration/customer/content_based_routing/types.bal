// ============================================================================
// Types for Content-Based Routing integration
// ============================================================================

// Normalised payload forwarded to each HTTP recipient backend
// after SOAP parsing and XSD validation
type NotificationForwardPayload record {|
    string personalNumber;
    string senderName;
    string senderId;
    decimal benefitAmount;
    string benefitType;
    string periodStart;
    string periodEnd;
    string message;
    string correlationId;
    string routedTo;
|};

public type NotificationContext record {|
    NotificationForwardPayload forwardPayload;
    string recipientName;
    string correlationId;
|};

public type NotificationStatusContext record {|
    string success;
    string message;
|};