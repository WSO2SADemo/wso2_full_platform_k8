import ballerina/http;
import ballerina/log;
import ballerinax/salesforce;
import ballerinax/servicenow;
import ballerinax/wso2.controlplane as _;

listener http:Listener OrderListener = new (samplePort);

service /'order on OrderListener {

    # Validates order ID in Salesforce and creates a ServiceNow ticket with the provided payload
    # 
    # + request - Request containing orderId and payload
    # + return - Response with order details and ticket information or error
    resource function post cancelOrder(@http:Payload OrderTicketRequest request) returns OrderTicketResponse|error {
        // Get Salesforce client
        salesforce:Client salesforceClient = check getSalesforceClient();
        
        // Determine if input is Order ID (15/18 chars) or Order Number
        string soqlQuery = "";
        int orderIdLength = request.orderId.length();
        if orderIdLength == 15 || orderIdLength == 18 {
            // Input is a Salesforce ID
            soqlQuery = "SELECT Id, OrderNumber, AccountId, Account.Name, Status, TotalAmount, CreatedDate, EffectiveDate FROM Order WHERE Id = '" + request.orderId + "'";
            log:printInfo("Querying order by Salesforce ID: " + request.orderId);
        } else {
            // Input is an Order Number
            soqlQuery = "SELECT Id, OrderNumber, AccountId, Account.Name, Status, TotalAmount, CreatedDate, EffectiveDate FROM Order WHERE OrderNumber = '" + request.orderId + "'";
            log:printInfo("Querying order by Order Number: " + request.orderId);
        }
        
        stream<record {|anydata...;|}, error?> orderStream = check salesforceClient->query(soqlQuery);
        
        // Get the first record from the stream
        record {|record {|anydata...;|} value;|}|error? orderRecordResult = orderStream.next();
        if orderRecordResult is error? {
            return error("Order not found for order ID: " + request.orderId);
        }
        
        // Extract order details
        record {|anydata...;|} orderRecord = orderRecordResult.value;
        anydata orderIdData = orderRecord["Id"];
        string orderIdValue = check orderIdData.ensureType();
        
        anydata orderNumberData = orderRecord["OrderNumber"];
        string orderNumberValue = check orderNumberData.ensureType();
        
        anydata totalAmountData = orderRecord["TotalAmount"];
        decimal totalAmountValue = check totalAmountData.ensureType();
        
        anydata statusData = orderRecord["Status"];
        string statusValue = check statusData.ensureType();
        
        // Get account name
        anydata accountData = orderRecord["Account"];
        record {|anydata...;|} accountRecord = check accountData.ensureType();
        anydata accountNameData = accountRecord["Name"];
        string accountNameValue = check accountNameData.ensureType();
        
        // Create ServiceNow incident with the payload
        json incidentPayload = {
            "short_description": "Order validation request for " + accountNameValue + " - Order #" + orderNumberValue,
            "description": "Order ID: " + orderIdValue + "\nOrder Number: " + orderNumberValue + "\nAccount: " + accountNameValue + "\nTotal Amount: $" + totalAmountValue.toString() + "\nStatus: " + statusValue + "\n\nPayload: " + request.payload,
            "caller_id": "integration.agent",
            "category": "inquiry",
            "impact": "3",
            "urgency": "3"
        };
        
        // Log the incident payload
        log:printInfo("Creating ServiceNow incident with payload: " + incidentPayload.toString());
        
        // Get ServiceNow client
        servicenow:Client servicenowClient = check getServiceNowClient();
        
        string tableName = "incident";
        json|error incidentResult = servicenowClient->createRecord(tableName, incidentPayload);
        
        if incidentResult is error {
            log:printError("Failed to create ServiceNow incident", incidentResult);
            return error("ServiceNow incident creation failed: " + incidentResult.message() + ". Please verify ServiceNow credentials and instance URL in Config.toml");
        }
        
        // Extract incident details
        record {|anydata...;|}|error incidentRecord = incidentResult.ensureType();
        if incidentRecord is error {
            log:printError("Failed to parse ServiceNow response", incidentRecord);
            return error("Invalid response from ServiceNow: " + incidentResult.toString());
        }
        
        // Log the full response for debugging
        log:printInfo("ServiceNow response: " + incidentRecord.toString());
        
        // ServiceNow wraps the response in a "result" object
        anydata resultData = incidentRecord["result"];
        if resultData is () {
            log:printError("ServiceNow response missing 'result' field");
            return error("ServiceNow response is missing the result field. Response: " + incidentRecord.toString());
        }
        
        record {|anydata...;|} resultRecord = check resultData.ensureType();
        
        anydata incidentNumberData = resultRecord["number"];
        if incidentNumberData is () {
            log:printError("ServiceNow response missing 'number' field");
            return error("ServiceNow response is missing the incident number. Response: " + resultRecord.toString());
        }
        string incidentNumber = check incidentNumberData.ensureType();
        
        anydata incidentSysIdData = resultRecord["sys_id"];
        if incidentSysIdData is () {
            log:printError("ServiceNow response missing 'sys_id' field");
            return error("ServiceNow response is missing the sys_id. Response: " + resultRecord.toString());
        }
        string incidentSysId = check incidentSysIdData.ensureType();
        
        // Return response
        return {
            orderId: orderIdValue,
            orderNumber: orderNumberValue,
            accountName: accountNameValue,
            totalAmount: totalAmountValue,
            status: statusValue,
            ticketNumber: incidentNumber,
            ticketSysId: incidentSysId,
            message: "Order validated and ticket created successfully"
        };
    }
}
