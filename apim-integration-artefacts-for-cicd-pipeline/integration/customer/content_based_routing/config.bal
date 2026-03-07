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

// AFA sender → DNE Online Calculator SOAP service (Add operation)
configurable string afaRecipientUrl = os:getEnv("afaRecipientUrl");

// Alfa sender → DataAccess NumberToWords SOAP service
configurable string alfaRecipientUrl = os:getEnv("alfaRecipientUrl");

// Folksam sender → DataAccess NumberToWords SOAP service
configurable string folksamRecipientUrl = os:getEnv("folksamRecipientUrl");

// Default recipient for unknown senders → DNE Online Calculator SOAP service
configurable string defaultRecipientUrl = os:getEnv("defaultRecipientUrl");

// High-value additional recipient – internal store-and-forward for durable delivery
configurable string highValueUrl = os:getEnv("highValueUrl");

// Benefit amount threshold above which high-value routing is also triggered
// Stored as string in ConfigMap, parsed at startup
configurable string highValueThresholdStr = os:getEnv("highValueThresholdStr");
