import ballerina/os;

configurable string servicenowBaseUrl = os:getEnv("servicenowBaseUrl");
configurable string servicenowUsername = os:getEnv("servicenowUsername");
configurable string servicenowPassword = os:getEnv("servicenowPassword");
configurable string salesforceClientId = os:getEnv("salesforceClientId");
configurable string salesforceClientSecret = os:getEnv("salesforceClientSecret");
configurable string salesforceTokenUrl = os:getEnv("salesforceTokenUrl");
configurable string salesforceBaseUrl = os:getEnv("salesforceBaseUrl");
configurable string pineconeVectorStoreUrl = os:getEnv("pineconeVectorStoreUrl");
configurable string pineconeApiKey = os:getEnv("pineconeApiKey");
configurable string sendgridApiToken = os:getEnv("sendgridApiToken");
configurable string sendGridSenderEmail = os:getEnv("sendGridSenderEmail");
configurable string openaiApiKey = os:getEnv("openaiApiKey");
configurable string cloudmersiveApiKey = os:getEnv("cloudmersiveApiKey");
configurable boolean enableDocumentIngestion = false;
configurable string salesforceAccountId = "001g5000003n9YHAAY";
configurable int samplePort = 8080;
configurable int aiPort = 8081;