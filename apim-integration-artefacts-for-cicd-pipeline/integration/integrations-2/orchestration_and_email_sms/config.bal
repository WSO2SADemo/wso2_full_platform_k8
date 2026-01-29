import ballerina/os;

configurable string smtpHost = os:getEnv("smtpHost");
configurable string smtpPortStr = os:getEnv("smtpPort");
configurable string smtpUsername = os:getEnv("smtpUsername");
configurable string smtpPassword = os:getEnv("smtpPassword");
configurable string emailFrom = os:getEnv("emailFrom");
configurable string emailTo = os:getEnv("emailTo");

// Twilio SMS configuration
configurable string twilioAccountSid = os:getEnv("twilioAccountSid");
configurable string twilioAuthToken = os:getEnv("twilioAuthToken");
configurable string twilioFromNumber = os:getEnv("twilioFromNumber");
configurable string twilioToNumber = os:getEnv("twilioToNumber");
