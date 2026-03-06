import ballerina/os;

// ============================================================================
// Routing recipient URLs
//
// Routing table (senderName in SOAP Header → recipient):
//   "AFA"     → fundAUrl  (Fund11 toggleable receiver – shows resilience demo)
//   "Alfa"    → fundBUrl  (notification mock backend)
//   "Folksam" → fundCUrl  (notification mock backend)
//   <other>   → defaultRecipientUrl
//
// Additional routing:
//   benefitAmount > highValueThreshold → ALSO forward to highValueUrl
//   (store-and-forward service for durable high-value delivery)
// ============================================================================

// AFA sender → Fund11 notification receiver (toggleable offline/online)
configurable string fundAUrl = os:getEnv("fundAUrl");

// Alfa sender → notification mock backend
configurable string fundBUrl = os:getEnv("fundBUrl");

// Folksam sender → notification mock backend
configurable string fundCUrl = os:getEnv("fundCUrl");

// Default recipient for unknown senders
configurable string defaultRecipientUrl = os:getEnv("defaultRecipientUrl");

// High-value additional recipient – store-and-forward for durable delivery
configurable string highValueUrl = os:getEnv("highValueUrl");

// Benefit amount threshold above which high-value routing is also triggered
// Stored as string in ConfigMap, parsed at startup
configurable string highValueThresholdStr = os:getEnv("highValueThresholdStr");
