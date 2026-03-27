// ============================================================================
// Routing recipient URLs
//
// Routing table (senderName in SOAP Header + benefitAmount):
//   "AFA",     any amount           → afaRecipientUrl     (DNE Calculator Add)
//   "Folksam", amount > threshold   → afaRecipientUrl     (DNE Calculator Multiply)
//   "Folksam", amount ≤ threshold   → folksamRecipientUrl (Oorsprong CountryInfo)
//   any other sender                → alfaRecipientUrl    (LearnWebServices Hello)
// ============================================================================
import ballerina/os;

// AFA sender → DNE Online Calculator SOAP service (Add operation)
configurable string afaRecipientUrl = os:getEnv("afaRecipientUrl");

// Default / other senders → LearnWebServices Hello SOAP service
configurable string alfaRecipientUrl = os:getEnv("alfaRecipientUrl");

// Folksam sender (low-value) → Oorsprong CountryInfo SOAP service
configurable string folksamRecipientUrl = os:getEnv("folksamRecipientUrl");

// Benefit amount threshold above which Folksam routes to Calculator Multiply
// Stored as string in ConfigMap, parsed at startup
configurable string highValueThresholdStr = os:getEnv("highValueThresholdStr");

// RabbitMQ connection configuration
configurable string rabbitmqHost = os:getEnv("rabbitmqHost");
configurable int rabbitmqPort = check int:fromString(os:getEnv("rabbitmqPort"));
configurable string rabbitmqUser = os:getEnv("RABBITMQ_USER");
configurable string rabbitmqPassword = os:getEnv("RABBITMQ_PASSWORD");