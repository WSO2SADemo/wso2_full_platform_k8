import ballerina/http;
import ballerina/log;
// import ballerinax/wso2.apim.catalog as _;
import ballerinax/wso2.controlplane as _;

// Unified API Service
// listener http:Listener apiListener = new (airlineServicePort);
service /airline on new http:Listener(8080) {

    function init() {
        log:printError("Initialize service airline");
        log:printError("Initialize service airline with service URL: " + scServiceUrl);
    }

    // Todo resources
    resource function get test() returns json {
        json todos = [
            {
                "id": 1,
                "name": "Test Service Response 200",
                "status": "OPEN"
            }
        ];
        return todos;
    }

    // Get customer profile with loyalty information
    resource function get customers/[string customerId]() returns Customer|http:NotFound|http:InternalServerError {
        // Fetch customers from mock API
        log:printInfo("get customers/[string customerId] invoked", 'customerId = customerId);
        json[]|error response = mockApiClient->get(path = "/");
        if response is error {
            log:printError("Error calling mock API", 'error = response);
            return <http:InternalServerError>{body: "Failed to retrieve customer information"};
        }

        // Filter customer by customerId
        foreach json customerJson in response {
            Customer|error customer = customerJson.cloneWithType();
            if customer is error {
                log:printError("Error parsing customer data", 'error = customer);
                continue;
            }
            log:printError("parsing customer data", 'customer = customer);
            if customer.customerId == customerId {
                return customer;
            }
        }

        // Return NotFound if customer not found
        return <http:NotFound>{body: string `Customer with ID ${customerId} not found`};
    }

    resource function get newresource() returns string {
        log:printInfo("get newresource()");
        return "new resource payload";
    }

    resource function get customers() returns Customer[]|http:InternalServerError {
        log:printInfo("get customers()");
        // Fetch customers from mock API
        json[]|error response = mockApiClient->get(path = "/");
        if response is error {
            log:printError("Error calling mock API", 'error = response);
            return <http:InternalServerError>{body: "Failed to retrieve customer information"};
        }

        Customer[] customers = [];
        foreach json customerJson in response {
            Customer|error customer = customerJson.cloneWithType();
            if customer is error {
                log:printError("Error parsing customer data", 'error = customer);
                continue;
            }
            customers.push(customer);
        }
        return customers;
    }

    // Health check endpoint
    resource function get health() returns json {
        log:printInfo("get health()");
        return {status: "UP", serviceName: "Unified API Service"};
    }
}
