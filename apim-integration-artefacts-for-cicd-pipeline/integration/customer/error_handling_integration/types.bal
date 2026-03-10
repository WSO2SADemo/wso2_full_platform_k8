// ============================================================================
// Types for Service Orchestration Pipeline
//
// Data flows sequentially through two pipeline steps:
//
//   OrderRequest
//       │
//       ▼ Step 1: GET /customer/profile/{customerId}
//   CustomerProfile
//       │  .tier         ──────────────────────────────────────────────────┐
//       │  .creditLimit  ──────────────────────────────────────────────────┼──► PricingRequest
//       │                                                                  │
//       ▼ Step 2: POST /pricing/calculate  ◄─────────────────────────────┘
//            [transform] tier → customerSegment (value mapping)
//   PricingResult
//       │
//       ▼
//   OrderSummary  (returned to caller)
// ============================================================================

// ─── Inbound Request ─────────────────────────────────────────────────────────

public type CustomerPipelineContext record {|
    OrderRequest request;
    string correlationId;
|};

public type PricingPipelineContext record {|
    CustomerProfile profile;
    OrderRequest request;
    string correlationId;
|};

public type TransformedPricingRequest record {|
    PricingRequestItem[] items;
    string customerSegment;  
    decimal creditLimit;
    string correlationId;
    CustomerProfile profile;
|};

public type OrderRequest record {|
    string customerId;
    OrderItem[] items;
|};

public type OrderItem record {|
    string productId;
    int quantity;
|};

// ─── Pipeline Step 1: Customer Profile ───────────────────────────────────────
// Returned as-is from the Customer Profile Service.
// Fields carried forward:
//   .tier         → Step 2 (drives discount percentage after value mapping)
//   .creditLimit  → Step 2 (drives payment terms threshold)

public type CustomerProfile record {|
    string customerId;
    string name;
    string tier;            // GOLD | SILVER | BRONZE
    decimal creditLimit;
    string shippingAddress;
|};

// ─── Pipeline Step 2: Pricing ────────────────────────────────────────────────
// Request built from:
//   original items            (what the caller ordered)
//   CustomerProfile.tier      (from Step 1) → MAPPED to customerSegment before sending
//   CustomerProfile.creditLimit (from Step 1) → drives payment terms
//
// Message transformation applied by the integration before calling the Pricing Service:
//   Value mapping – tier (GOLD|SILVER|BRONZE) → customerSegment (PREMIUM|STANDARD|BASIC)
//   The Pricing Service speaks a different vocabulary; the integration translates.

public type PricingRequestItem record {|
    string productId;
    int quantity;
|};

public type PricingRequestPayload record {|
    PricingRequestItem[] items;
    string customerSegment;   // PREMIUM | STANDARD | BASIC  (mapped from tier)
    decimal creditLimit;
|};

public type PricingLineItem record {|
    string productId;
    int quantity;
    decimal unitPrice;
    decimal lineTotal;
|};

public type PricingResponse record {|
    PricingLineItem[] lineItems;
    decimal baseTotal;
    decimal discountPercentage;
    decimal discountAmount;
    decimal finalTotal;
    decimal shippingFee;
    decimal grandTotal;
    string paymentTerms;
    string currency;
|};

// Transformed result extracted from PricingResponse.
public type PricingResult record {|
    PricingLineItem[] lineItems;
    decimal baseTotal;
    decimal discountPercentage;
    decimal discountAmount;
    decimal finalTotal;
    decimal shippingFee;
    decimal grandTotal;
    string paymentTerms;
    string currency;
|};

// ─── Pipeline Step 3: Purchase ────────────────────────────────────────────────
// Context fed to purchasePipeline.execute() by step2_calculatePricing.
// Carries the confirmed pricing result and customer profile so step3 can
// build a PurchaseRequest without re-calling upstream services.

public type PurchasePipelineContext record {|
    PricingResult pricing;
    CustomerProfile profile;
    string correlationId;
|};

// Request sent to the Purchase Service.
// Built by step3_doPurchase from PurchasePipelineContext.
public type PurchaseRequest record {|
    PricingLineItem[] lineItems;
    decimal grandTotal;
    string paymentTerms;
    string currency;
    string customerId;
    string customerTier;
|};

// Response from the Purchase Service.
public type PurchaseConfirmation record {|
    string purchaseId;
    string status;          // CONFIRMED | REJECTED
    string deliveryDate;    // ISO-8601 date (YYYY-MM-DD)
    string trackingRef;
|};

// ─── Final Order Summary (returned to caller) ─────────────────────────────────

public type OrderSummary record {|
    string orderId;
    string correlationId;
    CustomerProfile customer;
    PricingResult pricing;
    string processedAt;
|};
