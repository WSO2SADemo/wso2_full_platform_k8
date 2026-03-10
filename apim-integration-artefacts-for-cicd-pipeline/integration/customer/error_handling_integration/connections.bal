import ballerina/http;

// Per-request timeout for each backend service call
final decimal SERVICE_TIMEOUT_SECONDS = 10.0;

// Pipeline Step 1 – Customer Profile Service
// URL configured via customerServiceUrl (env var / ConfigMap)
final http:Client customerServiceClient = check new (customerServiceUrl,
    {timeout: SERVICE_TIMEOUT_SECONDS}
);

// Pipeline Step 2 – Pricing Service
// URL configured via pricingServiceUrl (env var / ConfigMap)
final http:Client pricingServiceClient = check new (pricingServiceUrl,
    {timeout: SERVICE_TIMEOUT_SECONDS}
);

// Pipeline Step 3 – Purchase Service
// URL configured via purchaseServiceUrl (env var / ConfigMap)
final http:Client purchaseServiceClient = check new (purchaseServiceUrl,
    {timeout: SERVICE_TIMEOUT_SECONDS}
);
