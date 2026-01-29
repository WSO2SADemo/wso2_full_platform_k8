import ballerina/log;
import ballerina/regex;
import ballerinax/salesforce;
import ballerinax/servicenow;
import ballerina/ai;
import ballerinax/ai.openai;
import ballerinax/ai.pinecone;
import ballerinax/sendgrid;

// Lazy-initialized clients
salesforce:Client? salesforceClientInstance = ();
servicenow:Client? servicenowClientInstance = ();

function getSalesforceClient() returns salesforce:Client|error {
    salesforce:Client? existingClient = salesforceClientInstance;
    if existingClient is salesforce:Client {
        return existingClient;
    }
    
    // Validate configuration with detailed error messages
    if salesforceBaseUrl == "" {
        return error("Salesforce baseUrl is not configured. Please add 'salesforceAPIBaseUrl' in Config.toml");
    }
    if salesforceClientId == "" {
        return error("Salesforce clientId is not configured. Please add 'salesforceAPIClientId' in Config.toml");
    }
    if salesforceClientSecret == "" {
        return error("Salesforce clientSecret is not configured. Please add 'salesforceAPIClientSecret' in Config.toml");
    }
    if salesforceTokenUrl == "" {
        return error("Salesforce tokenUrl is not configured. Please add 'salesforceAPITokenUrl' in Config.toml");
    }
    
    // Trim whitespace from configuration values
    string trimmedBaseUrl = salesforceBaseUrl.trim();
    string trimmedClientId = salesforceClientId.trim();
    string trimmedClientSecret = salesforceClientSecret.trim();
    string trimmedTokenUrl = salesforceTokenUrl.trim();
    
    // Convert Lightning URL to My Domain URL if needed
    if trimmedBaseUrl.includes("lightning.force.com") {
        // Extract the instance name from lightning URL
        // Example: https://orgfarm-a042ac05ab-dev-ed.develop.lightning.force.com
        // Should become: https://orgfarm-a042ac05ab-dev-ed.develop.my.salesforce.com
        trimmedBaseUrl = regex:replaceAll(trimmedBaseUrl, "lightning.force.com", "my.salesforce.com");
        log:printInfo("Converted Lightning URL to My Domain URL: " + trimmedBaseUrl);
    }
    
    // Convert Lightning URL to My Domain URL in tokenUrl if needed
    if trimmedTokenUrl.includes("lightning.force.com") {
        trimmedTokenUrl = regex:replaceAll(trimmedTokenUrl, "lightning.force.com", "my.salesforce.com");
        log:printInfo("Converted tokenUrl Lightning URL to My Domain URL: " + trimmedTokenUrl);
    }
    
    // Remove double slashes from tokenUrl if present
    if trimmedTokenUrl.includes("//services") {
        trimmedTokenUrl = regex:replaceAll(trimmedTokenUrl, "//services", "/services");
        log:printInfo("Fixed tokenUrl double slash: " + trimmedTokenUrl);
    }
    
    // Log configuration (without sensitive data)
    log:printInfo("Initializing Salesforce client with baseUrl: " + trimmedBaseUrl);
    log:printInfo("Salesforce tokenUrl: " + trimmedTokenUrl);
    log:printInfo("Salesforce clientId length: " + trimmedClientId);
    log:printInfo("Salesforce clientSecret length: " + trimmedClientSecret);
    
    salesforce:Client newClient = check new ({
        baseUrl: trimmedBaseUrl,
        auth: {
            clientId: trimmedClientId,
            clientSecret: trimmedClientSecret,
            tokenUrl: trimmedTokenUrl
        }
    });
    
    salesforceClientInstance = newClient;
    return newClient;
}

function getServiceNowClient() returns servicenow:Client|error {
    servicenow:Client? existingClient = servicenowClientInstance;
    if existingClient is servicenow:Client {
        return existingClient;
    }
    
    // Validate configuration with detailed error messages
    if servicenowBaseUrl == "" {
        return error("ServiceNow baseUrl is not configured. Please add 'servicenowBaseUrl' in Config.toml");
    }
    if servicenowUsername == "" {
        return error("ServiceNow username is not configured. Please add 'servicenowUsername' in Config.toml");
    }
    if servicenowPassword == "" {
        return error("ServiceNow password is not configured. Please add 'servicenowPassword' in Config.toml");
    }
    
    // Trim whitespace from configuration values
    string trimmedBaseUrl = servicenowBaseUrl.trim();
    string trimmedUsername = servicenowUsername.trim();
    string trimmedPassword = servicenowPassword.trim();
    
    // Ensure baseUrl doesn't have trailing slash
    if trimmedBaseUrl.endsWith("/") {
        trimmedBaseUrl = trimmedBaseUrl.substring(0, trimmedBaseUrl.length() - 1);
    }
    
    // Log configuration (without sensitive data)
    log:printInfo("Initializing ServiceNow client with baseUrl: " + trimmedBaseUrl);
    log:printInfo("ServiceNow username: " + trimmedUsername);
    log:printInfo("ServiceNow password length: " + trimmedPassword.length().toString());
    
    servicenow:Client newClient = check new ({
        auth: {
            username: trimmedUsername,
            password: trimmedPassword
        }
    }, trimmedBaseUrl);
    
    servicenowClientInstance = newClient;
    log:printInfo("ServiceNow client initialized successfully");
    return newClient;
}

final salesforce:Client salesforceClient = check new ({
    baseUrl: salesforceBaseUrl,
    auth: {
        clientId: salesforceClientId,
        clientSecret: salesforceClientSecret,
        tokenUrl: salesforceTokenUrl
    }
});
final servicenow:Client servicenowClient = check new ({
    auth: {
        username: servicenowUsername,
        password: servicenowPassword
    }
}, servicenowBaseUrl);

final pinecone:VectorStore pineconeVectorstore = check new (pineconeVectorStoreUrl, pineconeApiKey);
final openai:EmbeddingProvider openaiEmbeddingProvider = check new (openaiApiKey, "text-embedding-3-small");
final ai:VectorKnowledgeBase aiVectorknowledgebase = new (pineconeVectorstore, openaiEmbeddingProvider);
final sendgrid:Client sendgridClient = check new ({
    auth: {
        token: sendgridApiToken
    }
});
