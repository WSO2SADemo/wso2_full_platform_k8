import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;

// ============================================================================
// Order Processing Pipeline – Mock Backend Services
//
// Three sequential backend services for the service orchestration demo:
//
//   Port 9110 – Customer Profile Service
//               GET /customer/profile/{customerId}
//               Returns customer tier, credit limit, shipping address.
//
//   Port 9111 – Inventory Service
//               POST /inventory/check
//               Checks stock for requested items; uses customer tier to set
//               reservation priority (GOLD gets highest priority).
//
//   Port 9112 – Pricing Service
//               POST /pricing/calculate
//               Calculates final price with tier-based discount and
//               warehouse-based shipping fee.
//
// Pipeline data flow:
//   Step 1 CustomerProfile.tier        → Step 2 PricingRequest.customerSegment (value-mapped by integration)
//   Step 1 CustomerProfile.creditLimit → Step 2 PricingRequest.creditLimit
// ============================================================================

// ─── Shared types (scoped to this file / package) ────────────────────────────

public type CustomerProfile record {|
    string customerId;
    string name;
    string tier;            // GOLD | SILVER | BRONZE
    decimal creditLimit;
    string shippingAddress;
|};

public type ProductStock record {|
    string productId;
    string name;
    int stock;
    string warehouseId;
|};

public type InventoryRequestItem record {|
    string productId;
    int quantity;
|};

public type InventoryCheckRequest record {|
    InventoryRequestItem[] items;
    string customerTier;
|};

public type InventoryLineItem record {|
    string productId;
    string name;
    int requestedQuantity;
    int availableQuantity;
    string warehouseId;
    int reservationPriority;
|};

public type InventoryCheckResponse record {|
    InventoryLineItem[] available;
    InventoryLineItem[] unavailable;
    string primaryWarehouseId;
    boolean canFulfill;
|};

public type PricingRequestItem record {|
    string productId;
    int quantity;
|};

public type PricingRequest record {|
    PricingRequestItem[] items;
    string customerSegment;  // PREMIUM | STANDARD | BASIC  (mapped by integration from tier)
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

// ─── Pipeline Step 1: Customer Profile Service (port 9110) ───────────────────

listener http:Listener customerProfileListener = check new http:Listener(9110);

final map<CustomerProfile> & readonly customerDatabase = {
    "CUST-001": {
        customerId: "CUST-001",
        name: "Alice Svensson",
        tier: "GOLD",
        creditLimit: 50000d,
        shippingAddress: "Kungsgatan 1, Stockholm"
    },
    "CUST-002": {
        customerId: "CUST-002",
        name: "Bob Lindqvist",
        tier: "SILVER",
        creditLimit: 20000d,
        shippingAddress: "Drottninggatan 5, Gothenburg"
    },
    "CUST-003": {
        customerId: "CUST-003",
        name: "Carol Andersson",
        tier: "BRONZE",
        creditLimit: 5000d,
        shippingAddress: "Storgatan 12, Malmo"
    }
};

service /customer on customerProfileListener {

    function init() {
        log:printInfo("Customer Profile Service started on port 9110");
    }

    resource function get profile/[string customerId]() returns CustomerProfile|http:NotFound {
        CustomerProfile? profile = customerDatabase[customerId];
        if profile is CustomerProfile {
            log:printInfo(string `Customer profile found: ${customerId} tier=${profile.tier} creditLimit=${profile.creditLimit}`);
            return profile;
        }
        log:printWarn(string `Customer not found: ${customerId}`);
        return <http:NotFound>{
            body: {'error: "Customer not found", customerId: customerId}
        };
    }

    resource function get health() returns string {
        return "Customer Profile Service is running on port 9110";
    }
}

// ─── Pipeline Step 2: Inventory Service (port 9111) ──────────────────────────

listener http:Listener inventoryListener = check new http:Listener(9111);

final map<ProductStock> & readonly stockDatabase = {
    "PROD-A1": {productId: "PROD-A1", name: "Laptop Pro", stock: 15, warehouseId: "WH-STOCKHOLM"},
    "PROD-B2": {productId: "PROD-B2", name: "Wireless Mouse", stock: 200, warehouseId: "WH-STOCKHOLM"},
    "PROD-C3": {productId: "PROD-C3", name: "USB-C Hub", stock: 0, warehouseId: "WH-GOTHENBURG"},
    "PROD-D4": {productId: "PROD-D4", name: "Monitor 27in", stock: 8, warehouseId: "WH-STOCKHOLM"}
};

// Reservation priority by tier – GOLD customers get highest priority reservation
function tierPriority(string tier) returns int {
    match tier {
        "GOLD" => { return 5; }
        "SILVER" => { return 3; }
        _ => { return 1; }
    }
}

service /inventory on inventoryListener {

    function init() {
        log:printInfo("Inventory Service started on port 9111");
    }

    resource function post checkStock(@http:Payload InventoryCheckRequest request)
            returns InventoryCheckResponse {

        InventoryLineItem[] available = [];
        InventoryLineItem[] unavailable = [];
        string primaryWarehouse = "WH-STOCKHOLM";
        int priority = tierPriority(request.customerTier);

        foreach InventoryRequestItem item in request.items {
            ProductStock? stock = stockDatabase[item.productId];
            if stock is ProductStock {
                if stock.stock >= item.quantity {
                    available.push({
                        productId: item.productId,
                        name: stock.name,
                        requestedQuantity: item.quantity,
                        availableQuantity: stock.stock,
                        warehouseId: stock.warehouseId,
                        reservationPriority: priority
                    });
                    primaryWarehouse = stock.warehouseId;
                } else {
                    unavailable.push({
                        productId: item.productId,
                        name: stock.name,
                        requestedQuantity: item.quantity,
                        availableQuantity: stock.stock,
                        warehouseId: stock.warehouseId,
                        reservationPriority: 0
                    });
                }
            } else {
                unavailable.push({
                    productId: item.productId,
                    name: "Unknown product",
                    requestedQuantity: item.quantity,
                    availableQuantity: 0,
                    warehouseId: "N/A",
                    reservationPriority: 0
                });
            }
        }

        boolean canFulfill = unavailable.length() == 0;
        log:printInfo(string `Inventory check: ${available.length()} available, ${unavailable.length()} unavailable, tier=${request.customerTier} priority=${priority}`);

        return {
            available: available,
            unavailable: unavailable,
            primaryWarehouseId: primaryWarehouse,
            canFulfill: canFulfill
        };
    }

    resource function get health() returns string {
        return "Inventory Service is running on port 9111";
    }
}

// ─── Pipeline Step 3: Pricing Service (port 9112) ────────────────────────────

listener http:Listener pricingListener = check new http:Listener(9112);

final map<decimal> & readonly productPrices = {
    "PROD-A1": 12999.00d,
    "PROD-B2": 299.00d,
    "PROD-C3": 449.00d,
    "PROD-D4": 5999.00d
};

// Discount rate by customer segment (PREMIUM | STANDARD | BASIC)
// The integration maps GOLD→PREMIUM, SILVER→STANDARD, BRONZE→BASIC before calling.
function segmentDiscount(string segment) returns decimal {
    match segment {
        "PREMIUM" => { return 0.15d; }   // 15%
        "STANDARD" => { return 0.10d; }  // 10%
        _ => { return 0.05d; }            // 5%
    }
}

service /pricing on pricingListener {

    function init() {
        log:printInfo("Pricing Service started on port 9112");
    }

    resource function post calculate(@http:Payload PricingRequest request)
            returns PricingResponse {

        decimal baseTotal = 0d;
        PricingLineItem[] lineItems = [];

        foreach PricingRequestItem item in request.items {
            decimal unitPrice = productPrices[item.productId] ?: 0d;
            decimal lineTotal = unitPrice * <decimal>item.quantity;
            baseTotal += lineTotal;
            lineItems.push({
                productId: item.productId,
                quantity: item.quantity,
                unitPrice: unitPrice,
                lineTotal: lineTotal
            });
        }

        decimal discountPct = segmentDiscount(request.customerSegment);
        decimal discountAmount = baseTotal * discountPct;
        decimal finalTotal = baseTotal - discountAmount;

        // Flat shipping fee (warehouse is not part of the pricing request)
        decimal shippingFee = 99.00d;
        decimal grandTotal = finalTotal + shippingFee;

        // Payment terms: NET-30 if order fits within credit limit, otherwise PREPAID
        string paymentTerms = grandTotal <= request.creditLimit ? "NET-30" : "PREPAID";

        log:printInfo(string `Pricing: base=${baseTotal} discount=${discountPct * 100d}% (${discountAmount}) final=${finalTotal} shipping=${shippingFee} grand=${grandTotal} terms=${paymentTerms} segment=${request.customerSegment}`);

        return {
            lineItems: lineItems,
            baseTotal: baseTotal,
            discountPercentage: discountPct * 100d,
            discountAmount: discountAmount,
            finalTotal: finalTotal,
            shippingFee: shippingFee,
            grandTotal: grandTotal,
            paymentTerms: paymentTerms,
            currency: "SEK"
        };
    }

    resource function get health() returns string {
        return "Pricing Service is running on port 9112";
    }
}

// ─── Pipeline Step 3: Purchase Service (port 9113) ───────────────────────────

public type PurchaseLineItem record {|
    string productId;
    int quantity;
    decimal unitPrice;
    decimal lineTotal;
|};

public type PurchaseConfirmRequest record {|
    PurchaseLineItem[] lineItems;
    decimal grandTotal;
    string paymentTerms;
    string currency;
    string customerId;
    string customerTier;
|};

public type PurchaseConfirmResponse record {|
    string purchaseId;
    string status;       // CONFIRMED | REJECTED
    string deliveryDate; // ISO-8601 date (YYYY-MM-DD)
    string trackingRef;
|};

listener http:Listener purchaseListener = check new http:Listener(9113);

// Delivery lead-time by tier (calendar days)
function deliveryDays(string tier) returns int {
    match tier {
        "GOLD"   => { return 3; }
        "SILVER" => { return 7; }
        _        => { return 14; }
    }
}

service /purchase on purchaseListener {

    function init() {
        log:printInfo("Purchase Service started on port 9113");
    }

    // POST /purchase/confirm
    //
    // Validates the order total and issues a purchase confirmation.
    // Delivery date is calculated from today + tier-based lead time.
    // Payment terms PREPAID orders above credit limit are rejected.
    resource function post confirm(@http:Payload PurchaseConfirmRequest request)
            returns PurchaseConfirmResponse|http:BadRequest {

        if request.grandTotal <= 0d {
            log:printWarn(string `Purchase rejected – invalid grandTotal=${request.grandTotal} customer=${request.customerId}`);
            return <http:BadRequest>{body: {
                'error:      "Invalid order: grandTotal must be greater than zero",
                customerId:  request.customerId,
                grandTotal:  request.grandTotal
            }};
        }

        string purchaseId  = "PUR-" + uuid:createType4AsString().substring(0, 8).toUpperAscii();
        string trackingRef = "TRK-" + uuid:createType4AsString().substring(0, 8).toUpperAscii();

        int days = deliveryDays(request.customerTier);
        time:Utc deliveryUtc = time:utcAddSeconds(time:utcNow(), <decimal>(days * 86400));
        string deliveryDate = time:utcToString(deliveryUtc).substring(0, 10);

        log:printInfo(string `Purchase confirmed: purchaseId=${purchaseId} customer=${request.customerId}`
            + string ` tier=${request.customerTier} grand=${request.grandTotal} ${request.currency}`
            + string ` terms=${request.paymentTerms} delivery=${deliveryDate} (${days} days) tracking=${trackingRef}`);

        return {
            purchaseId:   purchaseId,
            status:       "CONFIRMED",
            deliveryDate: deliveryDate,
            trackingRef:  trackingRef
        };
    }

    resource function get health() returns string {
        return "Purchase Service is running on port 9113";
    }
}
