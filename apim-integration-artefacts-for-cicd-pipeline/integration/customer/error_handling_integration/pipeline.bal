import ballerina/http;
import ballerina/log;
import xlibb/pipeline;

// ============================================================================
// Service Orchestration Pipeline – Step Functions
//
// Each function represents one stage in the sequential pipeline:
//
//   step1_getCustomerProfile  – calls Customer Profile Service
//   step2_calculatePricing    – transforms Step 1 result, calls Pricing Service
//
// Transformation logic is explicit at every step boundary so it is easy to
// trace exactly which upstream fields feed into each downstream request.
// ============================================================================

// ─── Pipeline Step 1: Fetch Customer Profile ──────────────────────────────────
//
//  Input  : customerId (string from the inbound OrderRequest)
//  Call   : GET /customer/profile/{customerId}
//  Output : CustomerProfile
//
//  Fields carried forward to Step 2:
//    CustomerProfile.tier         → mapped to customerSegment for the Pricing Service
//    CustomerProfile.creditLimit  → drives payment terms threshold

@pipeline:TransformerConfig {
    id: "step1_getCustomerProfile"
}
isolated function step1_getCustomerProfile(pipeline:MessageContext ctx)
// PricingResult - both pipelnes are passing
// error - 1st destination is failing, the pipeline will retry to retry from 1st destination
// ? - 1st pipeline has passe but 2nd has failed and it will handled separtely
        returns PricingPipelineContext|error {
    CustomerPipelineContext message = check ctx.getContentWithType();
    string correlationId = message.correlationId;
    string customerId = message.request.customerId;
    log:printInfo(string `[${correlationId}] ── Pipeline Step 1 START – fetching customer profile for customerId=${customerId}`);
    
    http:Response|http:ClientError response =
        customerServiceClient->get(string `/customer/profile/${customerId}`);
    
    if response is http:ClientError {
        log:printError(string `[${correlationId}] ── Pipeline Step 1 FAILED – customer service unreachable: ${response.message()}`);
        return error(string `Step 1 failed: Customer service unavailable – ${response.message()}`);
    }
    if response.statusCode == 404 {
        log:printWarn(string `[${correlationId}] ── Pipeline Step 1 FAILED – customer not found: ${customerId}`);
        return error(string `Step 1 failed: Customer '${customerId}' not found (HTTP 404)`);
    }
    if response.statusCode >= 400 {
        log:printError(string `[${correlationId}] ── Pipeline Step 1 FAILED – customer service returned HTTP ${response.statusCode}`);
        return error(string `Step 1 failed: Customer service returned HTTP ${response.statusCode}`);
    }
    json|error jsonPayload = response.getJsonPayload();
    if jsonPayload is error {
        log:printError(string `[${correlationId}] ── Pipeline Step 1 FAILED – cannot read response body: ${jsonPayload.message()}`);
        return error(string `Step 1 failed: Cannot read customer service response – ${jsonPayload.message()}`);
    }
    CustomerProfile|error profile = jsonPayload.cloneWithType(CustomerProfile);
    if profile is error {
        log:printError(string `[${correlationId}] ── Pipeline Step 1 FAILED – response does not match CustomerProfile schema: ${profile.message()}`);
        return error(string `Step 1 failed: Unexpected customer profile schema – ${profile.message()}`);
    }
    log:printInfo(string `[${correlationId}] ── Pipeline Step 1 DONE`
        + string ` | customer=${profile.name} tier=${profile.tier} creditLimit=${profile.creditLimit}`
        + string ` | NEXT: tier → customerSegment (value mapping), creditLimit → payment terms`);
    PricingPipelineContext pricingPipelineCtx = {
            profile: profile,
            request: message.request,
            correlationId: correlationId
        };
    // do {
    //     pipeline:ExecutionSuccess execute = check pricingPipeline.execute(pricingPipelineCtx);
    //     log:printInfo("Step 2: Customer pricing retrieval succeeded");
    //     return execute.destinationResults["step2_calculatePricing"].ensureType(PurchaseConfirmation);
    // } on fail error err {
    //     log:printError("Step 2: Customer pricing retrieval failed", err);
    // }
    return pricingPipelineCtx;
}

@pipeline:TransformerConfig {
    id: "mapTierToSegment"
}
isolated function mapTierToSegment(pipeline:MessageContext ctx) returns TransformedPricingRequest|error {
    PricingPipelineContext message = check ctx.getContentWithType();
    string correlationId = message.correlationId;
    CustomerProfile customerProfile = message.profile;
    string customerSegment;
    match customerProfile.tier {
        "GOLD"   => { customerSegment = "PREMIUM"; }
        "SILVER" => { customerSegment = "STANDARD"; }
        _        => { customerSegment = "BASIC"; }
    }
    log:printInfo(string `[${correlationId}] ── Transform (value mapping): tier '${customerProfile.tier}' → customerSegment '${customerSegment}'`);
    TransformedPricingRequest pricingReq = {
        items: message.request.items.map(i => <PricingRequestItem>{productId: i.productId, quantity: i.quantity}),
        customerSegment: customerSegment,  
        creditLimit: customerProfile.creditLimit ,
        correlationId: correlationId,
        profile: customerProfile
    };
    return pricingReq;
}

@pipeline:TransformerConfig {
    id: "step2_calculatePricing"
}
isolated function step2_calculatePricing(pipeline:MessageContext ctx)
        returns PurchasePipelineContext|error? {
    TransformedPricingRequest pricingReq = check ctx.getContentWithType();
    string correlationId = pricingReq.correlationId;
    CustomerProfile customerProfile = pricingReq.profile;

    log:printInfo(string `[${correlationId}] ── Pipeline Step 2 START – calculating pricing`
        + string ` | tier=${customerProfile.tier} (Step 1) creditLimit=${customerProfile.creditLimit} (Step 1)`);

    PricingRequestPayload pricingReqPayload = {
        items: pricingReq.items,
        customerSegment: pricingReq.customerSegment,  
        creditLimit: customerProfile.creditLimit
    };
    http:Response|http:ClientError response =
        pricingServiceClient->post("/pricing/calculate", pricingReqPayload);

    if response is http:ClientError {
        log:printError(string `[${correlationId}] ── Pipeline Step 2 FAILED – pricing service unreachable: ${response.message()}`);
        return error(string `Step 2 failed: Pricing service unavailable – ${response.message()}`);
    }

    if response.statusCode >= 400 {
        log:printError(string `[${correlationId}] ── Pipeline Step 2 FAILED – pricing service returned HTTP ${response.statusCode}`);
        return error(string `Step 2 failed: Pricing service returned HTTP ${response.statusCode}`);
    }

    json|error jsonPayload = response.getJsonPayload();
    if jsonPayload is error {
        log:printError(string `[${correlationId}] ── Pipeline Step 2 FAILED – cannot read response body: ${jsonPayload.message()}`);
        return error(string `Step 2 failed: Cannot read pricing service response – ${jsonPayload.message()}`);
    }

    PricingResponse|error pricingResp = jsonPayload.cloneWithType(PricingResponse);
    if pricingResp is error {
        log:printError(string `[${correlationId}] ── Pipeline Step 2 FAILED – response does not match PricingResponse schema: ${pricingResp.message()}`);
        return error(string `Step 2 failed: Unexpected pricing response schema – ${pricingResp.message()}`);
    }

    PricingResult result = {
        lineItems: pricingResp.lineItems,
        baseTotal: pricingResp.baseTotal,
        discountPercentage: pricingResp.discountPercentage,
        discountAmount: pricingResp.discountAmount,
        finalTotal: pricingResp.finalTotal,
        shippingFee: pricingResp.shippingFee,
        grandTotal: pricingResp.grandTotal,
        paymentTerms: pricingResp.paymentTerms,
        currency: pricingResp.currency
    };

    log:printInfo(string `[${correlationId}] ── Pipeline Step 2 DONE`
        + string ` | base=${result.baseTotal} discount=${result.discountPercentage}% (${result.discountAmount})`
        + string ` | shipping=${result.shippingFee} grand=${result.grandTotal} ${result.currency} terms=${result.paymentTerms}`
        + string ` | NEXT: grand=${result.grandTotal} ${result.currency} → purchase confirmation`);

    // ── Chain to purchasePipeline (Step 3: Purchase Confirmation) ────────────
    // Pass the pricing result and customer profile forward so step3 can build
    // the purchase request without re-calling any upstream services.
    PurchasePipelineContext purchaseCtx = {
        pricing: result,
        profile: customerProfile,
        correlationId: correlationId
    };
    return purchaseCtx;
}

@pipeline:DestinationConfig {
    id: "step3_doPurchase",
    retryConfig: {maxRetries: 3, retryInterval: 30}
}
isolated function step3_doPurchase(pipeline:MessageContext ctx)
        returns PurchaseConfirmation|error {
    PurchasePipelineContext purchaseCtx = check ctx.getContentWithType();
    PricingResult pricingResult = purchaseCtx.pricing;
    CustomerProfile customerProfile = purchaseCtx.profile;
    string correlationId = purchaseCtx.correlationId;

    log:printInfo(string `[${correlationId}] ── Pipeline Step 3 START – confirming purchase`
        + string ` | customer=${customerProfile.customerId} tier=${customerProfile.tier}`
        + string ` | grandTotal=${pricingResult.grandTotal} ${pricingResult.currency} paymentTerms=${pricingResult.paymentTerms}`);

    // Build purchase request from the confirmed pricing + customer profile
    PurchaseRequest purchaseReq = {
        lineItems:    pricingResult.lineItems,
        grandTotal:   pricingResult.grandTotal,
        paymentTerms: pricingResult.paymentTerms,
        currency:     pricingResult.currency,
        customerId:   customerProfile.customerId,
        customerTier: customerProfile.tier
    };

    http:Response|http:ClientError response =
        purchaseServiceClient->post("/purchase/confirm", purchaseReq);

    if response is http:ClientError {
        log:printError(string `[${correlationId}] ── Pipeline Step 3 FAILED – purchase service unreachable: ${response.message()}`);
        return error(string `Step 3 failed: Purchase service unavailable – ${response.message()}`);
    }
    if response.statusCode >= 400 {
        log:printError(string `[${correlationId}] ── Pipeline Step 3 FAILED – purchase service returned HTTP ${response.statusCode}`);
        return error(string `Step 3 failed: Purchase service returned HTTP ${response.statusCode}`);
    }

    json|error jsonPayload = response.getJsonPayload();
    if jsonPayload is error {
        return error(string `Step 3 failed: Cannot read purchase response – ${jsonPayload.message()}`);
    }

    PurchaseConfirmation|error confirmation = jsonPayload.cloneWithType(PurchaseConfirmation);
    if confirmation is error {
        return error(string `Step 3 failed: Unexpected purchase response schema – ${confirmation.message()}`);
    }

    log:printInfo(string `[${correlationId}] ── Pipeline Step 3 DONE`
        + string ` | purchaseId=${confirmation.purchaseId} status=${confirmation.status}`
        + string ` | delivery=${confirmation.deliveryDate} tracking=${confirmation.trackingRef}`);

    return confirmation;
}
