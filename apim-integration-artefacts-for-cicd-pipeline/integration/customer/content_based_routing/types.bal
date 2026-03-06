// ============================================================================
// Types for Content-Based Routing integration
// ============================================================================

// Represents the routing decision made after evaluating the SOAP header
// and body content
type RoutingDecision record {|
    // Primary recipient name (e.g. "AFA-Fund-A")
    string recipientName;
    // Whether the message qualifies for high-value additional routing
    boolean isHighValue;
|};

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

// Payload shape expected by the store-and-forward service
// (POST /notifications/send)
type StoreForwardMessage record {|
    string messageId;
    string recipient;
    json payload;
    int retryCount = 0;
    string createdAt;
|};
