// ============================================================================
// Service Orchestration Pipeline
//
// Scenario: E-Commerce Order Fulfillment
//
// Two backend services are called sequentially. The response from Step 1 is
// transformed and injected as input into Step 2.
//
//   ┌─────────────────────────────────────────────────────────────────────┐
//   │  POST /orders/process                                               │
//   │  { customerId, items: [{ productId, quantity }] }                   │
//   └────────────────────────────────┬────────────────────────────────────┘
//                                    │
//              ┌─────────────────────▼─────────────────────┐
//              │  Step 1 – Customer Profile Service         │
//              │  GET /customer/profile/{customerId}        │
//              │  → CustomerProfile { tier, creditLimit }   │
//              └─────────────────────┬─────────────────────┘
//                                    │  [transform] tier → customerSegment
//                                    │  creditLimit → payment terms
//              ┌─────────────────────▼─────────────────────┐
//              │  Step 2 – Pricing Service                  │
//              │  POST /pricing/calculate                   │
//              │  ← { items, customerSegment, creditLimit } │
//              │  → PricingResult { grandTotal, terms }     │
//              └─────────────────────┬─────────────────────┘
//                                    │
//              ┌─────────────────────▼─────────────────────┐
//              │  OrderSummary (returned to caller)         │
//              │  { orderId, customer, pricing,             │
//              │    processedAt }                           │
//              └────────────────────────────────────────────┘
//
// Exposed endpoint: POST http://<host>:9086/orders/process
// ============================================================================

import ballerina/http;
import ballerina/log;
import ballerina/uuid;
import xlibb/pipeline;
import ballerinax/moesif as _;
// import ballerinax/wso2.icp as _;

listener http:Listener orchestrationListener = check new http:Listener(9086);

function init() {
    log:printInfo("Purchase order pipeline started on port 9086");

    // Health check: verify connectivity to Step 1 – Customer Profile Service
    http:Response|http:ClientError customerHealth = customerServiceClient->get("/customer/health");
    if customerHealth is http:ClientError {
        log:printError("Customer Profile Service health check FAILED – could not reach backend: " + customerHealth.message());
    } else if customerHealth.statusCode == 200 {
        log:printInfo("Customer Profile Service health check PASSED – connection to port 9110 is working");
    } else {
        log:printWarn(string `Customer Profile Service health check returned unexpected status: ${customerHealth.statusCode}`);
    }

    // Health check: verify connectivity to Step 2 – Pricing Service
    http:Response|http:ClientError pricingHealth = pricingServiceClient->get("/pricing/health");
    if pricingHealth is http:ClientError {
        log:printError("Pricing Service health check FAILED – could not reach backend: " + pricingHealth.message());
    } else if pricingHealth.statusCode == 200 {
        log:printInfo("Pricing Service health check PASSED – connection to port 9112 is working");
    } else {
        log:printWarn(string `Pricing Service health check returned unexpected status: ${pricingHealth.statusCode}`);
    }

    // Health check: verify connectivity to Step 3 – Purchase Service
    http:Response|http:ClientError purchaseHealth = purchaseServiceClient->get("/purchase/health");
    if purchaseHealth is http:ClientError {
        log:printError("Purchase Service health check FAILED – could not reach backend: " + purchaseHealth.message());
    } else if purchaseHealth.statusCode == 200 {
        log:printInfo("Purchase Service health check PASSED – connection to port 9113 is working");
    } else {
        log:printWarn(string `Purchase Service health check returned unexpected status: ${purchaseHealth.statusCode}`);
    }
}

// ─── Order Processing Service ─────────────────────────────────────────────────

service /orders on orchestrationListener {

    
    // POST /orders/process
    //
    // Drives the two-step pipeline. Step 1 output feeds into Step 2.
    // Any step failure short-circuits the pipeline and returns the appropriate
    // HTTP error with the step name so callers can diagnose which backend failed.
    resource function post process(@http:Payload OrderRequest request)
            returns PurchaseConfirmation|OrderSummary|http:BadRequest|http:NotFound|http:InternalServerError|pipeline:ExecutionError {
        string correlationId = uuid:createType1AsString();
        string orderId = "ORD-" + uuid:createType4AsString().substring(0, 8).toUpperAscii();
        log:printInfo(string `[${correlationId}] ════ ORDER PIPELINE STARTED ════ orderId=${orderId} customerId=${request.customerId} items=${request.items.length()}`);
        if request.items.length() == 0 {
            return <http:BadRequest>{body: {
                'error: "Order must contain at least one item",
                correlationId: correlationId
            }};
        }
        CustomerPipelineContext customerPipelineCtx = {
            request: request,
            correlationId: correlationId
        };
        do {
            pipeline:ExecutionSuccess execute = check customerProfilePipeline.execute(customerPipelineCtx);
            PurchaseConfirmation purchaseConfirmation = check execute.destinationResults["step3_doPurchase"].cloneWithType();
            return purchaseConfirmation;
        } on fail error err {
            //1st destination itself failed
            log:printError(string `[${correlationId}] ── ORDER PIPELINE FAILED at Step # – ${err.message()}`);
            return <http:InternalServerError>{body: {
                    'error: string `${err.message()}`,
                    correlationId: correlationId,
                    failedStep: "unknown"
                }};
        }
    }

    resource function get health() returns string {
        return "Service Orchestration Pipeline is running on port 9086";
    }
}
