import ballerina/os;

configurable string mcpServerTokenURL = os:getEnv("mcpServerTokenURL");
configurable string agentAppClientId = os:getEnv("agentAppClientId");
configurable string agentAppClientSecret = os:getEnv("agentAppClientSecret");
configurable string redirectUri = os:getEnv("redirectUri");
configurable string mcpServerClientSecret = os:getEnv("mcpServerClientSecret");
configurable string keystorePath = os:getEnv("keystorePath");
configurable string keystorePassword = os:getEnv("keystorePassword");
configurable string truststorePath = os:getEnv("truststorePath");
configurable string truststorePassword = os:getEnv("truststorePassword");
configurable string insurancecustomermcpURL = os:getEnv("insurancecustomermcpURL");
configurable string insuranceagentmcpURL = os:getEnv("insuranceagentmcpURL");
configurable string privilegedAgentID = os:getEnv("privilegedAgentID");
configurable string privilegedAgentSecret = os:getEnv("privilegedAgentSecret");
configurable string agentID = os:getEnv("agentID");
configurable string agentSecret = os:getEnv("agentSecret");
configurable string mistralKey = os:getEnv("mistralKey");
configurable string mistralAccessToken = os:getEnv("mistralAccessToken");
configurable string wso2gwURL = os:getEnv("wso2gwURL");
configurable string wso2ProviderConfigServiceUrl = os:getEnv("wso2ProviderConfigServiceUrl");
configurable string wso2ProviderConfigAccessToken = os:getEnv("wso2ProviderConfigAccessToken");

configurable string pineConeKey = os:getEnv("pineConeKey");
configurable string pineconeURL = os:getEnv("pineconeURL");
configurable string openAIKey = os:getEnv("openAIKey");

// OBO flow config
configurable string oboIsBaseUrl = os:getEnv("oboIsBaseUrl");
configurable string oboCallbackUrl = os:getEnv("oboCallbackUrl");
