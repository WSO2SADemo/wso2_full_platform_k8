# Service Orchestration Pipeline – E-Commerce Order Fulfillment

A Ballerina integration that implements a **3-step sequential service orchestration pipeline** using [`xlibb/pipeline`](https://central.ballerina.io/xlibb/pipeline). Each step's response is transformed and forwarded to the next step. Failures at any stage are automatically captured into a RabbitMQ-backed Dead Letter Queue for replay.

---

## Architecture

### Happy Path

```
Caller
  │
  │  POST /orders/process  { customerId, items[] }
  ▼
┌──────────────────────────────────────────────────────────────────────┐
│               error_handling_integration  (port 9086)                │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐     │
│  │           xlibb/pipeline HandlerChain                       │     │
│  │           "customer-profile-pipeline"                       │     │
│  │                                                             │     │
│  │  ┌─────────────────────────────────────────────────────┐   │     │
│  │  │ [Processor 1]  step1_getCustomerProfile             │   │     │
│  │  │                                                     │   │     │
│  │  │  GET /customer/profile/{customerId}  ────────────► Customer   │
│  │  │                                                  Profile Svc  │
│  │  │  ◄─────────────────────────────────────────────  (:9110)  │   │
│  │  │  { name, tier, creditLimit, shippingAddress }           │   │     │
│  │  └───────────────────────┬─────────────────────────────────┘   │     │
│  │                          │  CustomerProfile + OrderRequest       │     │
│  │                          ▼                                      │     │
│  │  ┌─────────────────────────────────────────────────────┐   │     │
│  │  │ [Processor 2]  mapTierToSegment  (value mapping)    │   │     │
│  │  │                                                     │   │     │
│  │  │   GOLD   ──────────────────────►  PREMIUM           │   │     │
│  │  │   SILVER ──────────────────────►  STANDARD          │   │     │
│  │  │   *      ──────────────────────►  BASIC             │   │     │
│  │  │                                                     │   │     │
│  │  │   (no network call – pure transformation)           │   │     │
│  │  └───────────────────────┬─────────────────────────────┘   │     │
│  │                          │  TransformedPricingRequest        │     │
│  │                          │  { items, customerSegment,        │     │
│  │                          │    creditLimit, profile }         │     │
│  │                          ▼                                      │     │
│  │  ┌─────────────────────────────────────────────────────┐   │     │
│  │  │ [Processor 3]  step2_calculatePricing               │   │     │
│  │  │                                                     │   │     │
│  │  │  POST /pricing/calculate  ───────────────────────► Pricing   │
│  │  │  { items, customerSegment, creditLimit }           Svc       │
│  │  │                                                  (:9112)  │   │
│  │  │  ◄───────────────────────────────────────────────          │   │
│  │  │  { grandTotal, discountPct, paymentTerms, lineItems }      │   │
│  │  └───────────────────────┬─────────────────────────────────┘   │     │
│  │                          │  PurchasePipelineContext             │     │
│  │                          │  { pricing, profile, correlationId } │     │
│  │                          ▼                                      │     │
│  │  ┌─────────────────────────────────────────────────────┐   │     │
│  │  │ [Destination]  step3_doPurchase                     │   │     │
│  │  │                retry: maxRetries=3, interval=30s    │   │     │
│  │  │                                                     │   │     │
│  │  │  POST /purchase/confirm  ────────────────────────► Purchase  │
│  │  │  { lineItems, grandTotal, paymentTerms,           Svc        │
│  │  │    customerId, customerTier }                    (:9113)  │   │
│  │  │                                                             │   │
│  │  │  ◄───────────────────────────────────────────────          │   │
│  │  │  { purchaseId, status, deliveryDate, trackingRef }         │   │
│  │  └─────────────────────────────────────────────────────┘   │     │
│  └─────────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────────┘
  │
  │  HTTP 200  { purchaseId, status, deliveryDate, trackingRef }
  ▼
Caller
```

### Failure & Replay Path

When `step3_doPurchase` fails (Purchase Service unreachable or HTTP 4xx/5xx), the pipeline retries automatically. If all retries are exhausted, the original message is persisted to RabbitMQ for manual replay.

```
step3_doPurchase (Destination)
Purchase Service (:9113) fails
         │
         │  xlibb/pipeline retries up to 3×  (30 s intervals)
         │  all retries exhausted
         ▼
┌──────────────────────────────┐
│  RabbitMQ                    │
│  errorhandling.order-failure │ ◄──── operator / demo UI inspects here
└──────────────┬───────────────┘
               │
               │  "Move to Order Replay" button in demo UI
               │  (or manual shovel via RabbitMQ Management API)
               ▼
┌──────────────────────────────┐
│  RabbitMQ                    │
│  errorhandling.order-replay  │
└──────────────┬───────────────┘
               │
               │  replayListenerConfig picks up message
               │  pipeline re-executes from Step 1
               │
       ┌───────┴──────────┐
       │ success           │ still failing after 3× retries
       ▼                   ▼
HTTP 200              ┌──────────────────────────────┐
to caller             │  RabbitMQ                    │
(if sync)             │  errorhandling.order-        │
                      │  deadletter                  │
                      └──────────────────────────────┘
```

### Pipeline internals (`xlibb/pipeline`)

| Role | Function | Behaviour on error |
|------|----------|--------------------|
| Processor | `step1_getCustomerProfile` | Propagates error immediately — no retry |
| Processor | `mapTierToSegment` | Propagates error immediately — no retry |
| Processor | `step2_calculatePricing` | Propagates error immediately — no retry |
| Destination | `step3_doPurchase` | Retried up to **3×** with **30 s** interval, then → failure queue |

> **Processors fail fast.** Only the Destination step has retry semantics. If Steps 1–3 fail (e.g. Customer Profile Service down), the error is returned directly to the caller with HTTP 500.

Failed Destination executions are written to `errorhandling.order-failure`. Messages moved to `errorhandling.order-replay` trigger a full pipeline re-run. Messages that exhaust retries on replay go to `errorhandling.order-deadletter`.

---

## API

### `POST /orders/process`

Submit an order for fulfillment.

**Request**
```json
{
  "customerId": "CUST-001",
  "items": [
    { "productId": "PROD-A1", "quantity": 1 },
    { "productId": "PROD-B2", "quantity": 2 }
  ]
}
```

**Response `200 OK`**
```json
{
  "purchaseId":   "PUR-3F9A1B2C",
  "status":       "CONFIRMED",
  "deliveryDate": "2026-03-13",
  "trackingRef":  "TRK-7E4D2C1A"
}
```

**Error responses**

| Status | Cause |
|--------|-------|
| `400 Bad Request` | Empty items list |
| `500 Internal Server Error` | Any backend service failure (step indicated in body) |

### `GET /orders/health`

Returns `200 OK` with a plain-text status message.

---

## Data transformations

### Step 1 → Step 2: Tier value mapping

The Customer Profile Service returns a `tier`, but the Pricing Service expects a `customerSegment` using a different vocabulary. The integration performs the mapping explicitly:

| Customer tier | Pricing segment |
|---------------|----------------|
| `GOLD`        | `PREMIUM` (15% discount) |
| `SILVER`      | `STANDARD` (10% discount) |
| `BRONZE`      | `BASIC` (5% discount) |

### Step 2 → Step 3: Context forwarding

`step2_calculatePricing` bundles the `PricingResult` and `CustomerProfile` into a `PurchasePipelineContext` so Step 3 can build the purchase request without re-calling any upstream service.

---

## Mock backends

All three backend services are provided by `mock_backends/customer_backends/` (same deployment as the other customer mock backends).

| Service | Port | Endpoint | Test data |
|---------|------|----------|-----------|
| Customer Profile | 9110 | `GET /customer/profile/{id}` | `CUST-001` GOLD, `CUST-002` SILVER, `CUST-003` BRONZE |
| Pricing | 9112 | `POST /pricing/calculate` | Products: `PROD-A1` Laptop, `PROD-B2` Mouse, `PROD-D4` Monitor |
| Purchase | 9113 | `POST /purchase/confirm` | Delivery: GOLD=3d, SILVER=7d, BRONZE=14d |

K8s cluster-local base URL: `http://customer-backends.ballerina.svc.cluster.local`

---

## Configuration

### Kubernetes ConfigMap (`ballerina-values-error-handling-flow`)

| Key | Value |
|-----|-------|
| `rabbitmqHost` | `rabbitmq.ballerina.svc.cluster.local` |
| `rabbitmqPort` | `5672` |
| `customerServiceUrl` | `http://customer-backends.ballerina.svc.cluster.local:9110` |
| `pricingServiceUrl` | `http://customer-backends.ballerina.svc.cluster.local:9112` |
| `purchaseServiceUrl` | `http://customer-backends.ballerina.svc.cluster.local:9113` |
| `BAL_CONFIG_DATA` | Moesif observability config (TOML block) |

### Kubernetes Secret (`rabbitmq-credentials`)

| Key | Description |
|-----|-------------|
| `RABBITMQ_USER` | RabbitMQ username |
| `RABBITMQ_PASSWORD` | RabbitMQ password |

### RabbitMQ queues

| Queue | Purpose |
|-------|---------|
| `errorhandling.order-failure` | Failed pipeline executions (retry source) |
| `errorhandling.order-replay` | Messages queued for manual/automatic replay |
| `errorhandling.order-deadletter` | Messages that exhausted all retries |

---

## Local development

Create `Config.toml` in this directory:

```toml
customerServiceUrl = "http://localhost:9110"
pricingServiceUrl  = "http://localhost:9112"
purchaseServiceUrl = "http://localhost:9113"
rabbitmqHost       = "localhost"
rabbitmqPort       = 5672
rabbitmqUser       = "wso2-rmq-admin"
rabbitmqPassword   = "R@bbitMQ#W$O2!2024Secure"
```

Run mock backends first, then the integration:

```bash
# Terminal 1
cd mock_backends/customer_backends && bal run

# Terminal 2
cd apim-integration-artefacts-for-cicd-pipeline/integration/customer/error_handling_integration
bal run
```

Test:
```bash
curl -X POST http://localhost:9086/orders/process \
  -H "Content-Type: application/json" \
  -d '{"customerId":"CUST-001","items":[{"productId":"PROD-A1","quantity":1}]}'
```

---

## Deployment

```bash
# Apply ConfigMap
kubectl apply -f config-map-error-handling.yaml -n ballerina

# Build, push image, and deploy to AKS
./amd64-deploy.sh
```

The deploy script:
1. Builds the Ballerina project and pushes `ramilu90/purchase_service_orchestration_pipeline:1.0.4` (linux/amd64)
2. Applies the ConfigMap
3. Applies the generated Kubernetes deployment
4. Creates the `error-handling-integration` Service (port 9086)
5. Patches the deployment with the keystore volume mount
6. Injects `RABBITMQ_USER`/`RABBITMQ_PASSWORD` from `rabbitmq-credentials` secret
7. Injects all ConfigMap env vars (`rabbitmqHost`, `rabbitmqPort`, backend URLs)
8. Rolls out and waits for readiness

### Startup health checks

On `init()` the integration logs connectivity status for all three backends:

```
Customer Profile Service health check PASSED – connection to port 9110 is working
Pricing Service health check PASSED – connection to port 9112 is working
Purchase Service health check PASSED – connection to port 9113 is working
```

---

## File structure

```
error_handling_integration/
├── main.bal          – HTTP listener, /orders/process endpoint, health checks
├── pipeline.bal      – Step functions (step1, mapTierToSegment, step2, step3)
├── clients.bal       – HandlerChain + RabbitMQ MessageStore declarations
├── connections.bal   – HTTP client declarations
├── types.bal         – All record types and pipeline context types
├── config.bal        – Configurable variables (env var bindings)
├── Cloud.toml        – Container image + K8s env ref declarations
├── Ballerina.toml    – Project metadata and dependencies
├── config-map-error-handling.yaml  – K8s ConfigMap manifest
└── amd64-deploy.sh   – Local build + AKS deploy script
```
