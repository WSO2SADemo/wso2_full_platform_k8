# Store and Forward

## Overview

This integration provides **guaranteed message delivery** for benefit notifications sent to a downstream backend (Fund 11 – Notification Receiver). The caller never waits for backend delivery: the message is accepted immediately and the integration handles delivery, retries, and dead-letter management autonomously.

Key capabilities:
1. Exposes an **HTTP endpoint** on port 9085 that accepts notification requests
2. **Publishes** the message to RabbitMQ immediately and returns `202 Accepted`
3. A **background consumer** attempts delivery to the backend; on failure it retries up to 3 times using a RabbitMQ TTL retry queue (30 s between attempts)
4. Messages that exhaust all retries are moved to a **Dead Letter Queue (DLQ)** and surfaced via a manual-retry API
5. The backend can be **toggled offline** (via its admin endpoint) to simulate a service window and demonstrate the full retry/DLQ path

---

## Architecture

### Happy Path

```
  Caller
  (UI / API)

  POST /notifications/send  ──▶  ┌─────────────────────────────────────────────────┐
                                  │  store-and-forward (port 9085)                  │
                                  │                                                 │
                                  │  1. Wrap payload in NotificationMessage         │
                                  │  2. Publish to RabbitMQ main queue              │
                                  │  3. Return 202 Accepted immediately             │
                                  └──────────────────────┬──────────────────────────┘
                                                         │
                                         ┌───────────────▼───────────────┐
                                         │  RabbitMQ                     │
                                         │  store-forward-notifications  │  ← main queue
                                         └───────────────┬───────────────┘
                                                         │  consumer polls (100 ms)
                                         ┌───────────────▼───────────────┐
                                         │  Background Consumer          │
                                         │  (queue_consumer.bal)         │
                                         └───────────────┬───────────────┘
                                                         │  POST /notifications
                                         ┌───────────────▼───────────────┐
                                         │  Fund 11 – Notification       │
                                         │  Receiver  (port 9101)        │
                                         └───────────────────────────────┘
                                                  HTTP 200 → ack ✓
```

### Retry / Failure Path (backend unavailable)

```
  Backend returns non-2xx or times out
         │
         ▼
  retryCount < MAX_RETRIES (3)?
         │
        YES ──▶ ┌──────────────────────────────────────┐
                │  RabbitMQ                            │
                │  store-forward-retry                 │  ← TTL 30 000 ms
                │  (x-dead-letter → main queue)        │
                └──────────────────┬───────────────────┘
                                   │  after 30 s
                                   ▼
                         re-enters store-forward-notifications
                         consumer retries (attempt 2, 3, 4)
         │
        NO (retries exhausted)
         │
         ▼
  ┌──────────────────────────────────────┐
  │  RabbitMQ                            │
  │  store-forward-dlq                   │  ← Dead Letter Queue
  └──────────────────────────────────────┘
         │  also stored in in-memory dlqMessages map
         │
         ├── GET  /notifications/dlq-status  → inspect pending messages
         │
         └── POST /notifications/retry       → requeue oldest message
                                               (retryCount reset to 0)
```

---

### Component Map

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │  Kubernetes namespace: ballerina                                     │
  │                                                                     │
  │  ┌──────────────────────────────────────┐                          │
  │  │  store-and-forward (port 9085)       │                          │
  │  │                                      │                          │
  │  │  main.bal           – HTTP service   │                          │
  │  │                       send / retry / │                          │
  │  │                       dlq-status     │                          │
  │  │  queue_consumer.bal – background     │                          │
  │  │                       delivery loop  │                          │
  │  │  connections.bal    – RabbitMQ +     │                          │
  │  │                       HTTP clients,  │                          │
  │  │                       queue setup,   │                          │
  │  │                       constants      │                          │
  │  │  config.bal         – env var wiring │                          │
  │  │  types.bal          – record types   │                          │
  │  └──────────────────────┬───────────────┘                          │
  │                         │                                           │
  │                         ▼                                           │
  │  ┌──────────────────────────────────────┐                          │
  │  │  RabbitMQ (namespace: ballerina)     │                          │
  │  │  store-forward-notifications         │  ← main delivery queue   │
  │  │  store-forward-retry                 │  ← TTL 30 s, auto-DLR   │
  │  │  store-forward-dlq                   │  ← exhausted messages    │
  │  └──────────────────────────────────────┘                          │
  │                                                                     │
  │  ┌──────────────────────────────────────┐                          │
  │  │  customer-backends (port 9101)       │                          │
  │  │  Fund 11 – Notification Receiver     │                          │
  │  │  POST /notifications                 │  ← delivery target       │
  │  │  POST /notifications/admin/toggle    │  ← simulate outage       │
  │  │  GET  /notifications/admin/status    │  ← check availability    │
  │  └──────────────────────────────────────┘                          │
  └─────────────────────────────────────────────────────────────────────┘
```

---

### Retry Policy

| Attempt | Behaviour |
|---|---|
| 1 (initial) | Direct delivery to backend |
| 2–4 (auto retries) | Re-queued via TTL retry queue; 30 s delay between each |
| After attempt 4 | Moved to DLQ; available for manual retry via `POST /notifications/retry` |

| Constant | Value | Description |
|---|---|---|
| `MAX_RETRIES` | `3` | Automatic delivery attempts after the initial failure |
| `RETRY_TTL_MS` | `30 000` | Milliseconds a failed message waits before re-attempt |
| `BACKEND_TIMEOUT_SECONDS` | `5.0` | Per-request HTTP timeout to the backend |

> **Note:** The in-memory DLQ map (`dlqMessages`) is lost on pod restart. For production, persist DLQ messages to a database.

---

## API Reference

### POST `/notifications/send`

Queue a notification for durable delivery. Returns `202 Accepted` immediately.

**Request body:**
```json
{
  "personId": "199001011234",
  "notificationType": "BENEFIT_UPDATE",
  "data": {
    "benefitAmount": 15000,
    "currency": "SEK",
    "note": "Monthly update"
  }
}
```

Supported `notificationType` values: `STATUS_CHANGE`, `BENEFIT_UPDATE`, `REGISTRATION`

**Response (202):**
```json
{
  "messageId": "550e8400-e29b-41d4-a716-446655440000",
  "status": "QUEUED",
  "message": "Message accepted and queued for delivery. Automatic retries will occur if the backend is unavailable.",
  "timestamp": "2026-03-11T12:00:00.000Z"
}
```

---

### POST `/notifications/retry`

Manually requeue the oldest DLQ message for another delivery attempt (resets retry counter to 0).

**Response:**
```json
{ "status": "REQUEUED",  "message": "Message moved back to main queue for delivery", "messageId": "..." }
{ "status": "DLQ_EMPTY", "message": "No messages pending manual retry",              "messageId": null }
{ "status": "ERROR",     "message": "Failed to requeue: <reason>",                  "messageId": "..." }
```

---

### GET `/notifications/dlq-status`

List all messages currently awaiting manual retry.

**Response:**
```json
{
  "count": 1,
  "messages": [
    {
      "messageId": "550e8400-e29b-41d4-a716-446655440000",
      "personId": "199001011234",
      "notificationType": "BENEFIT_UPDATE",
      "data": { "benefitAmount": 15000, "currency": "SEK" },
      "retryCount": 3,
      "createdAt": "2026-03-11T12:00:00.000Z",
      "lastAttemptAt": "2026-03-11T12:01:30.000Z"
    }
  ]
}
```

---

## Configuration

Configured via Kubernetes ConfigMap (`ballerina-values-store-and-forward`) and Secret (`rabbitmq-credentials`).

| Env var | Source | Description |
|---|---|---|
| `rabbitmqHost` | ConfigMap | RabbitMQ hostname |
| `rabbitmqPort` | ConfigMap | RabbitMQ AMQP port (5672) |
| `backendUrl` | ConfigMap | Backend service URL for notification delivery |
| `RABBITMQ_USER` | Secret | RabbitMQ username |
| `RABBITMQ_PASSWORD` | Secret | RabbitMQ password |
| `BAL_CONFIG_DATA` | ConfigMap | Ballerina observability config (Moesif tracing/metrics) |

---

## Deployment

```bash
cd apim-integration-artefacts-for-cicd-pipeline/integration/customer/store_and_forward_integration
./amd64-deploy.sh
```

The deploy script:
1. Builds the Ballerina project (`bal build`)
2. Builds and pushes a `linux/amd64` Docker image
3. Applies the ConfigMap
4. Applies the generated Kubernetes deployment
5. Creates the ClusterIP Service (port 9085)
6. Creates the `ballerina-integration-secret` (keystore/truststore) if not present
7. Patches the deployment with the keystore volume
8. Scales to 1 replica (prevents RabbitMQ queue `PRECONDITION_FAILED` on multi-pod startup)
9. Restarts the deployment and waits for rollout

### Kubernetes Resources

| Resource | Name | Namespace |
|---|---|---|
| Deployment | `store-and-forwa-deployment` | `ballerina` |
| Service | `store-and-forward-integration` | `ballerina` |
| HPA | `store-and-forwa` | `ballerina` |
| ConfigMap | `ballerina-values-store-and-forward` | `ballerina` |
| Secret | `rabbitmq-credentials` | `ballerina` |
| Secret | `ballerina-integration-secret` | `ballerina` |

---

## cURL Commands

> **Local access (port-forward):**
> ```bash
> kubectl port-forward svc/store-and-forward-integration 9085:9085 -n ballerina
> kubectl port-forward svc/customer-backends 9101:9101 -n ballerina
> ```

### 1. Send a notification (backend online – delivered immediately)

```bash
curl -s -X POST http://localhost:9085/notifications/send \
  -H "Content-Type: application/json" \
  -d '{
    "personId": "199001011234",
    "notificationType": "BENEFIT_UPDATE",
    "data": {
      "benefitAmount": 15000,
      "currency": "SEK",
      "note": "Monthly update"
    }
  }'
```

**Expected:** `202 Accepted`, `status=QUEUED`. Backend receives delivery within ~100 ms.

---

### 2. Check backend availability

```bash
curl -s http://localhost:9101/notifications/admin/status
```

**Expected:** `{"available": true, "state": "ONLINE"}`

---

### 3. Toggle the backend offline (simulate service window)

```bash
curl -s -X POST http://localhost:9101/notifications/admin/toggle
```

**Expected:** `{"available": false, "state": "OFFLINE (service window active)"}`

---

### 4. Send a notification while backend is offline (triggers retry loop)

```bash
curl -s -X POST http://localhost:9085/notifications/send \
  -H "Content-Type: application/json" \
  -d '{
    "personId": "199001011234",
    "notificationType": "STATUS_CHANGE",
    "data": { "newStatus": "INACTIVE", "reason": "Employment started" }
  }'
```

**Expected:** `202 Accepted`. The background consumer will attempt delivery, fail, and retry up to 3 more times (each after 30 s). After all 4 attempts fail, the message is moved to the DLQ.

---

### 5. Check DLQ status (after retries are exhausted)

```bash
curl -s http://localhost:9085/notifications/dlq-status
```

**Expected:** `count=1`, message with `retryCount=3`.

---

### 6. Toggle the backend back online

```bash
curl -s -X POST http://localhost:9101/notifications/admin/toggle
```

**Expected:** `{"available": true, "state": "ONLINE"}`

---

### 7. Manually retry the DLQ message

```bash
curl -s -X POST http://localhost:9085/notifications/retry
```

**Expected:** `status=REQUEUED`. The message is moved back to the main queue and delivered to the now-online backend within ~100 ms.

---

### 8. Send a registration notification

```bash
curl -s -X POST http://localhost:9085/notifications/send \
  -H "Content-Type: application/json" \
  -d '{
    "personId": "200102044567",
    "notificationType": "REGISTRATION",
    "data": { "fund": "Akademikernas", "startDate": "2026-03-11" }
  }'
```

**Expected:** `202 Accepted`, delivered immediately if backend is online.

---

## Store & Forward Notification Integration

This integration implements the Store & Forward pattern specifically for the **Benefit Notification** use case:

- **Producer**: any system (UI, APIM-managed API) that needs to notify Fund 11 of a benefit status change, registration, or update
- **Store**: RabbitMQ queue (`store-forward-notifications`) acts as the durable store — the message survives pod restarts and network blips
- **Forward**: a background consumer continuously polls the queue and delivers each notification to the Fund 11 Notification Receiver endpoint
- **Retry & Dead-Letter**: failed deliveries are re-routed through a TTL-based retry queue before being moved to the DLQ for manual replay

The caller interacts only with the Store & Forward service — it never calls Fund 11 directly. This decouples the producer from the backend's availability, turning transient outages into an invisible retry cycle.
