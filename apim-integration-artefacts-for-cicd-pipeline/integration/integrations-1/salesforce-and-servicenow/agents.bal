import ballerina/ai;
import ballerina/http;
import ballerina/log;
import ballerina/regex;
import ballerinax/ai.openai;
import ballerinax/sendgrid;

final openai:ModelProvider _fullfillmentAgentModel = check new (openaiApiKey, "gpt-4.1");
final ai:Agent _fullfillmentAgentAgent = check new (
    systemPrompt = {
        role: "Expert E-commerce Fulfillment Agent",
        instructions: string `You are an advanced fulfillment agent for an online retail store, responsible for managing the complete order lifecycle and customer service operations.

        Your core responsibilities include:
        1. Order Management:
           - Retrieve and verify order details from Salesforce
           - Process order returns within the 7-day return window
           - Handle order status updates and modifications

        2. Return Processing:
           - Validate return eligibility based on order date and amount
           - Automatically process returns for orders under $100
           - Create ServiceNow incidents for high-value returns (over $100)

        3. Customer Communication:
           - Send automated email notifications for return status updates
           - Provide order-specific information and tracking details
           - Handle return policy inquiries using the knowledge base

        4. Integration Management:
           - Coordinate between Salesforce (CRM), ServiceNow (Incident Management), and SendGrid (Email)
           - Ensure data consistency across all connected systems
           - Handle errors and provide meaningful feedback

        You have access to various tools to interact with these systems and should use them appropriately to provide efficient and accurate service.`
    }, model = _fullfillmentAgentModel, tools = [getAllOrdersTool, initiateReturnTool, getIncidentByIdTool, createIncidentTool, queryReturnPolicyTool, sendMailTool, getAccountInfoTool], verbose = true
, memory = new ai:MessageWindowChatMemory(128)
);

# Retrieves all orders from Salesforce with comprehensive order details.
# Fetches critical order information including:
# - Order identification (ID, OrderNumber)
# - Financial details (TotalAmount)
# - Status information
# - Creation and effective dates
# - Product details for each order item
# - Quantity and pricing information
# Use this for bulk order analysis and reporting
# + accountId - Optional Salesforce Account ID to filter orders. If not provided, uses the configured default account ID
# + return - Stream of detailed order records with product information or an error if the query fails
@ai:AgentTool
@display {label: "", iconPath: "https://bcentral-packageicons.azureedge.net/images/ballerinax_salesforce_8.2.0.png"}
isolated function getAllOrdersTool(string accountId = salesforceAccountId) returns stream<record {|anydata...;|}, error?>|error {
    string soql = "SELECT Id, OrderNumber, AccountId, Status, TotalAmount, CreatedDate, EffectiveDate, (SELECT Id, Quantity, UnitPrice, TotalPrice, PricebookEntry.Product2.Name, PricebookEntry.Product2.ProductCode, PricebookEntry.Product2.Description FROM OrderItems) FROM Order WHERE AccountId = '" + accountId + "'";
    stream<record {|anydata...;|}, error?> streamReturntypeError = check salesforceClient->query(soql);
    return streamReturntypeError;
}

# Processes a customer's return request with RAG-powered decision making and multi-system integration.
#
# Business Logic (RAG-Driven):
# 1. Queries knowledge base to determine return eligibility and processing type
# 2. AUTOMATIC_RETURN:
# - Immediately approves and updates status in Salesforce
# - Marks order as Returned without manual intervention
# 3. MANUAL_RETURN:
# - Creates a ticket for manual review and approval
# - Provide the reference ID to the customer for tracking and send email without return label
# 4. NOT_ELIGIBLE:
# - Denies return with specific policy-based reasoning
#
# The RAG system considers factors like order age, product type, order value,
# customer history, and complex policy rules stored in the knowledge base.
#
# + accountName - Customer's account name from Salesforce
# + orderId - Unique order identifier for the return request
# + return - Detailed response including processing type, status, and next steps
@ai:AgentTool
@display {label: "", iconPath: "https://bcentral-packageicons.azureedge.net/images/ballerinax_salesforce_8.2.0.png"}
isolated function initiateReturnTool(string accountName, string orderId) returns json|error {
    // fetch the order details using the order number from salesforce
    string soql = "SELECT Id, OrderNumber, TotalAmount, EffectiveDate, (SELECT Id, Quantity, UnitPrice, PricebookEntry.Product2.Name, PricebookEntry.Product2.ProductCode FROM OrderItems) FROM Order WHERE Id = '" + orderId + "'";
    stream<record {|anydata...;|}, error?> orderStream = check salesforceClient->query(soql);
    record {|anydata...;|}?|error _orderRecord = check orderStream.next();
    if (_orderRecord is error) {
        return error("Order not found for order ID: " + orderId);
    }
    OrderRecord|error orderRecord = _orderRecord.cloneWithType(OrderRecord);
    if (orderRecord is error) {
        return error("Failed to convert order record to Order type: " + orderRecord.message());
    }

    // Perform RAG-powered return eligibility validation
    string|error validationResult = validateReturnEligibilityWithRAG(orderRecord.value);
    if (validationResult is error) {
        return error("Return validation failed: " + validationResult.message());
    }

    // Handle different return scenarios based on RAG decision
    match validationResult {
        "AUTOMATIC_RETURN" => {
            // Automatically process the return - mark as returned in Salesforce
            error? update = salesforceClient->update("Order", orderRecord.value.Id, {
                "Status": "Returned"
            });
            if update is error {
                return error("Failed to mark order as returned in Salesforce: " + update.message());
            }
            return {
                "message": "Order return processed automatically. Send email WITH return label to customer.",
                "orderId": orderRecord.value.Id,
                "orderNumber": orderRecord.value.OrderNumber,
                "returnType": "AUTOMATIC",
                "status": "COMPLETED"
            };
        }
        "MANUAL_RETURN" => {
            // Create ServiceNow incident for manual processing
            json|error incidentResult = createIncidentTool(accountName, orderRecord.value.OrderNumber);
            if (incidentResult is error) {
                return error("Failed to create incident for manual return processing: " + incidentResult.message());
            }
            return {
                "message": "Return request submitted for manual review. Provide the Reference ID. Send email WITHOUT return label to customer.",
                "orderId": orderRecord.value.Id,
                "orderNumber": orderRecord.value.OrderNumber,
                "returnType": "MANUAL",
                "status": "PENDING_REVIEW",
                "incidentDetails": incidentResult
            };
        }
        _ => {
            // Return denied - validationResult contains the reason
            return error("Return not allowed: " + validationResult);
        }
    }
}

# Retrieves detailed information about a specific ServiceNow incident using its sys_id.
#
# Fetches comprehensive incident details including:
# - Incident number and system ID
# - Creation timestamp and current state
# - Assignment and priority information
# - Customer details and correlation data
# - Description and resolution notes
# - SLA compliance status
#
# Use this tool to:
# - Track return request progress
# - Verify incident status updates
# - Access resolution details
# - Monitor SLA compliance
#
# + incidentId - ServiceNow sys_id of the incident to retrieve
# + return - Detailed incident information as JSON, including all tracking and status details, or error if retrieval fails
@ai:AgentTool
@display {label: "", iconPath: "https://bcentral-packageicons.azureedge.net/images/ballerinax_servicenow_1.5.1.png"}
isolated function getIncidentByIdTool(string incidentId) returns json|error {
    string tableName = "incident";
    json jsonResult = check servicenowClient->getRecordById(tableName, incidentId, "true", true, "number,sys_id,sys_created_on,cmdb_ci,correlation_id,state,assignment_group,short_description,description,close_code,close_notes", false, "incident_view");
    return jsonResult;
}

# Creates a ServiceNow incident for high-value returns (over $100) requiring manual processing.
#
# Incident Details:
# - Categorized as return request
# - Priority based on order value
# - Includes customer and order information
# - Automated assignment to returns team
# - Tracking for SLA compliance
#
# + accountName - Customer's account name from Salesforce for incident reference
# + orderNumber - Order number for tracking and processing
# + return - Detailed incident information including sys_id and tracking number, or error details if creation fails
@ai:AgentTool
@display {label: "", iconPath: "https://bcentral-packageicons.azureedge.net/images/ballerinax_servicenow_1.5.1.png"}
isolated function createIncidentTool(string accountName, string orderNumber) returns json|error {
    json payload = {
        "short_description": "Customer order return initiated for " + accountName + " for order #" + orderNumber,
        "description": "A customer return has been requested for order #" + orderNumber + ". The return is within the 7-day window. Please process the return and send a shipping label to the customer.",
        "caller_id": "integration.agent",
        "category": "inquiry",
        "impact": "3",
        "urgency": "3"
    };
    string tableName = "incident";
    json|error jsonResult = check servicenowClient->createRecord(tableName, payload);
    if (jsonResult is error) {
        return error("Failed to create incident: " + jsonResult.message());
    }
    // If the creation is successful, return the created incident details
    return jsonResult;
}

# Queries the knowledge base for return policy information and guidelines.
#
# Provides instant access to:
# - Return eligibility criteria
# - Time window restrictions
# - Product-specific return policies
# - Required documentation
# - Shipping and handling guidelines
# - Refund processing timeframes
#
# Features:
# - Natural language query processing
# - Context-aware responses
# - Real-time policy updates
# - Accurate policy interpretations
#
# + query - Natural language question about return policies
# + return - Relevant policy information formatted as a string, or error if query fails
@ai:AgentTool
@display {label: "", iconPath: "https://bcentral-packageicons.azureedge.net/images/ballerinax_pinecone_1.0.0.png"}
isolated function queryReturnPolicyTool(string query) returns string|error {
    string|error result = queryReturnPolicy(query);
    return result;
}

# Sends automated email notifications to customers regarding their return requests.
# Uses the customer's email from their Salesforce contact record for communication.
#
# Email Features:
# - Personalized with customer's name and order details
# - Return status and next steps
# - Conditional QR code attachment based on return type
#
# Note: The email address should be retrieved from the customer's Salesforce contact record
# using the getAllAccountsTool which includes contact information.
#
# + senderEmail - Customer's email address from their Salesforce contact record
# + senderName - Customer's name from Salesforce account
# + orderNumber - Order Number for reference and tracking
# + content - Customized email content including return instructions and next steps
# + includeQRCode - Whether to include QR code attachment (true for automatic returns, false for manual returns)
# + ticketId - ServiceNow ticket ID for manual returns (empty string for automatic returns)
# + return - HTTP response from SendGrid or error if sending fails
@ai:AgentTool
@display {label: "", iconPath: "https://bcentral-packageicons.azureedge.net/images/ballerinax_sendgrid_1.5.1.png"}
isolated function sendMailTool(string senderEmail, string senderName, string orderNumber, string content, boolean includeQRCode, string ticketId) returns http:Response|error {
    // Validate email format
    if senderEmail.trim() == "" || !senderEmail.includes("@") {
        return error("Invalid sender email address: " + senderEmail);
    }

    // Validate sender email configuration
    if sendGridSenderEmail.trim() == "" || !sendGridSenderEmail.includes("@") {
        return error("Invalid SendGrid sender email configuration");
    }

    // Generate QR code only for automatic returns
    string qrCodeBase64 = "";
    if (includeQRCode) {
        // Generate QR code for the return shipping label using direct HTTP call
        byte[]|error qrCodeBytes = generateQRCodeDirectHTTP(orderNumber);
        if (qrCodeBytes is error) {
            return error("Failed to generate QR code via direct HTTP: " + qrCodeBytes.message());
        }
        log:printInfo("Generated QR Code for order: " + orderNumber + " (" + qrCodeBytes.length().toString() + " bytes)");

        // Convert to base64 for SendGrid attachment
        qrCodeBase64 = qrCodeBytes.toBase64();

        // Validate that we have valid base64 data
        if (qrCodeBase64.trim() == "") {
            return error("QR code generation returned empty data");
        }
    } else {
        log:printInfo("Skipping QR code generation for manual return - order: " + orderNumber);
    }

    // Create the email content based on return type
    string emailContent = "Order Number: " + orderNumber + "\n\n" + content + "\n\n";
    if (includeQRCode) {
        emailContent += "Please find your return shipping label QR code attached to this email.";
    } else {
        emailContent += "Your return request has been submitted for review. You will receive further instructions once your return is approved.";
        if (ticketId.trim() != "") {
            emailContent += "\n\nFor reference, your support ticket ID is: " + ticketId + ". Please keep this number for your records and use it when inquiring about the status of your return.";
        }
    }

    // Create HTML content for better formatting
    string htmlContent = "<html><body>" +
                        "<h2>Return Request " + (includeQRCode ? "Processed" : "Received") + "</h2>" +
                        "<p><strong>Order Number:</strong> " + orderNumber + "</p>" +
                        "<div>" + regex:replaceAll(content, "\n", "<br>") + "</div>";

    if (includeQRCode) {
        htmlContent += "<p>Please find your return shipping label QR code attached to this email.</p>";
    } else {
        htmlContent += "<p>Your return request has been submitted for review. You will receive further instructions once your return is approved.</p>";
        if (ticketId.trim() != "") {
            htmlContent += "<p><strong>Support Ticket ID:</strong> " + ticketId + "<br>Please keep this number for your records and use it when inquiring about the status of your return.</p>";
        }
    }
    htmlContent += "</body></html>";

    // Build email payload
    sendgrid:SendEmailRequest emailPayload = {
        personalizations: [
            {
                to: [
                    {
                        email: senderEmail.trim(),
                        name: senderName.trim()
                    }
                ]
            }
        ],
        'from: {
            email: sendGridSenderEmail.trim(),
            name: "Nexus Store"
        },
        subject: "Return " + (includeQRCode ? "Accepted" : "Request Received") + " - Order Number: " + orderNumber,
        content: [
            {
                'type: "text/plain",
                value: emailContent
            },
            {
                'type: "text/html",
                value: htmlContent
            }
        ]
    };

    // Add QR code attachment only for automatic returns
    if (includeQRCode && qrCodeBase64.trim() != "") {
        emailPayload.attachments = [
            {
                content: qrCodeBase64,
                filename: "return_label_" + orderNumber + ".png",
                'type: "image/png",
                disposition: "attachment"
            }
        ];
    }

    http:Response httpResponse = check sendgridClient->sendMail(emailPayload);
    return httpResponse;
}

# Retrieves detailed information about the configured Salesforce account.
# Fetches comprehensive account information including:
# - Basic account details (ID, Name, Type, Website, Phone, Industry)
# - Account ownership information (Owner.Name)
# - Associated contact information (ID, Name, Email)
# Uses the configured salesforceAccountId to retrieve specific account data.
# + return - Stream of account record with nested contact information, or an error if the query fails
@ai:AgentTool
@display {label: "", iconPath: "https://bcentral-packageicons.azureedge.net/images/ballerinax_salesforce_8.2.0.png"}
isolated function getAccountInfoTool() returns stream<record {|anydata...;|}, error?>|error {
    string soql = "SELECT Id, Name, Type, Website, Phone, Industry, Owner.Name, (SELECT Id, Name, Email FROM Contacts) FROM Account WHERE Id = '" + salesforceAccountId + "'";
    stream<record {|anydata...;|}, error?> streamReturntypeError = check salesforceClient->query(soql);
    return streamReturntypeError;
}
