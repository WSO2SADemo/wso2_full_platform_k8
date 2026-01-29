import ballerina/ai;
import ballerina/http;
import ballerina/log;
import ballerina/time;

isolated function queryReturnPolicy(string question) returns string|error {
    ai:QueryMatch[] aiQuerymatch = check aiVectorknowledgebase.retrieve(question, filters = {
        filters: [
            {
                key: "id",
                value: 1
            }
        ]
    });
    ai:ChatUserMessage aiChatusermessage = ai:augmentUserQuery(aiQuerymatch, question);
    ai:ChatAssistantMessage aiChatassistantmessage = check _fullfillmentAgentModel->chat(aiChatusermessage, []);
    return aiChatassistantmessage.content.ensureType();
}

# Validates return eligibility using RAG-powered policy queries from the knowledge base.
#
# This function uses the Pinecone vector database to dynamically validate return requests
# based on stored policies rather than hardcoded business rules. It determines:
# - AUTOMATIC_RETURN: Immediate processing without manual intervention
# - MANUAL_RETURN: Eligible but requires manual review/approval
# - NOT_ELIGIBLE: Return denied with specific reason
#
# Considers factors like:
# - Order date and return window policies
# - Product-specific return restrictions
# - Order value thresholds
# - Customer-specific policies
# - Seasonal or promotional restrictions
#
# + orderRecord - Complete order record with items and metadata
# + return - "AUTOMATIC_RETURN", "MANUAL_RETURN", or reason for denial if not eligible
isolated function validateReturnEligibilityWithRAG(Order orderRecord) returns string|error {
    // Calculate days since order was placed
    time:Utc utc = check time:utcFromString(orderRecord.EffectiveDate + "T00:00:00Z");
    time:Utc currentTime = time:utcNow();
    time:Seconds utcDiffSeconds = time:utcDiffSeconds(currentTime, utc);
    int daysSinceOrder = <int>(utcDiffSeconds / 86400d); // Convert seconds to days

    // First, get the non-returnable items list using the same approach as the tool
    string nonReturnableQuery = "Can you provide a list of non-refundable items?";
    string|error nonReturnableResult = queryReturnPolicy(nonReturnableQuery);
    string nonReturnableItems = "";
    if (nonReturnableResult is string) {
        nonReturnableItems = nonReturnableResult;
        log:printInfo("Non-returnable items found: " + nonReturnableItems);
    } else {
        log:printError("Failed to get non-returnable items: " + nonReturnableResult.message());
        nonReturnableItems = "Unable to retrieve non-returnable items list";
    }

    // Use a comprehensive query that includes the non-returnable items context
    string validationQuery = string `I need to determine if this order is eligible for return and what type of processing it requires:

    ORDER DETAILS:
    - Order placed: ${daysSinceOrder} days ago
    - Order total: $${orderRecord.TotalAmount}
    - Order date: ${orderRecord.EffectiveDate}
    - Products: ${getProductNamesFromOrder(orderRecord)}

    NON-RETURNABLE ITEMS:
    ${nonReturnableItems}

    ANALYSIS REQUIRED:
    1. Is this order within the allowed return timeframe according to the return policy?
    2. Are any of these products (${getProductNamesFromOrder(orderRecord)}) in the non-returnable items list above?
    3. Based on the order value and policy, should this be processed automatically or require manual review?

    Please analyze this against the return policy and respond with exactly one of these:
    - "AUTOMATIC_RETURN" if it qualifies for immediate automatic processing
    - "MANUAL_RETURN" if it's eligible but needs manual review  
    - "NOT_ELIGIBLE" followed by the specific reason if return is not allowed

    Provide your reasoning first, then the final decision with exact reasons why the order falls into that category.`;

    log:printInfo("Validation query: " + validationQuery);

    // Query the knowledge base for policy-based validation
    string|error policyResponse = queryReturnPolicy(validationQuery);
    if (policyResponse is error) {
        return error("Failed to validate return eligibility: " + policyResponse.message());
    }
    log:printInfo("Policy response: " + policyResponse);

    // Parse the AI response to determine the specific return type
    string responseUpper = policyResponse.toUpperAscii();
    if (responseUpper.includes("AUTOMATIC_RETURN")) {
        return "AUTOMATIC_RETURN";
    } else if (responseUpper.includes("MANUAL_RETURN")) {
        return "MANUAL_RETURN";
    } else if (responseUpper.includes("NOT_ELIGIBLE")) {
        return policyResponse; // Return the full response with reason
    } else {
        // Fallback parsing for less structured responses
        if (responseUpper.includes("AUTOMATIC") || responseUpper.includes("IMMEDIATE")) {
            return "AUTOMATIC_RETURN";
        } else if (responseUpper.includes("MANUAL") || responseUpper.includes("REVIEW")) {
            return "MANUAL_RETURN";
        } else {
            return policyResponse; // Assume not eligible if unclear
        }
    }
}

# Helper function to extract product names from order items for context
# + orderRecord - Order record containing order items
# + return - Comma-separated string of product names
isolated function getProductNamesFromOrder(Order orderRecord) returns string {
    string[] productNames = [];
    foreach var item in orderRecord.OrderItems.records {
        string productName = item.PricebookEntry.Product2.Name;
        productNames.push(productName);
    }
    return string:'join(", ", ...productNames);
}

# Direct HTTP client implementation to generate QR code using Cloudmersive API
#
# + orderId - Order ID to encode in the QR code
# + return - Binary PNG data or error if generation fails
isolated function generateQRCodeDirectHTTP(string orderId) returns byte[]|error {
    http:Client cloudmersiveClient = check new ("https://api.cloudmersive.com");

    json requestPayload = {
        "OrderId": orderId
    };

    http:Request request = new;
    request.setJsonPayload(requestPayload);
    request.setHeader("Apikey", cloudmersiveApiKey);
    request.setHeader("Content-Type", "application/json");

    http:Response response = check cloudmersiveClient->post("/barcode/generate/qrcode", request);

    if (response.statusCode != 200) {
        return error("Cloudmersive API failed with status: " + response.statusCode.toString());
    }

    // Get the response as binary data
    byte[] binaryData = check response.getBinaryPayload();
    log:printInfo("Direct HTTP call - received " + binaryData.length().toString() + " bytes");

    return binaryData;
}
