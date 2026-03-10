# Store-and-Forward Notification Integration

A Ballerina integration service that accepts notification requests from callers and delivers them durably to a backend via RabbitMQ. Callers get an immediate `202 Accepted` response — delivery happens asynchronously with automatic retries and a dead-letter queue (DLQ) for manual recovery.

---

## Architecture

```
Caller
  │
  │  POST /notifications/send
  ▼
Store-and-Forward Service (port 9085)
  │
  │  publish
  ▼
RabbitMQ: store-forward-notifications (main queue)
  │
  │  consume
  ▼
Consumer Worker
  ├── Success          → ack message, done
  ├── Failure (attempt < 3) → publish to store-forward-retry (TTL 30s → back to main)
  └── Failure (attempt = 3) → publish to store-forward-dlq + store in memory
                                    │
                                    │  POST /notifications/retry
                                    ▼
                              Re-queued to main queue (retry counter reset)
```

---

## Queues

| Queue | Purpose |
|---|---|
| `store-forward-notifications` | Main delivery queue (durable) |
| `store-forward-retry` | Retry holding queue — messages expire after 30 s (TTL) and dead-letter back to main |
| `store-forward-dlq` | Dead-letter queue — messages that exhausted all 3 automatic retries |

---

## API Endpoints

Base URL (in-cluster): `http://store-and-forward-integration.ballerina.svc.cluster.local:9085`

### POST /notifications/send

Queue a notification for durable delivery. Returns `202` immediately.

**Request body:**
```json
{
  "personId": "P-12345",
  "notificationType": "BENEFIT_UPDATE",
  "data": {
    "amount": 35000,
    "period": "2026-Q1"
  }
}
```

**Response `202`:**
```json
{
  "messageId": "550e8400-e29b-41d4-a716-446655440000",
  "status": "QUEUED",
  "message": "Message accepted and queued for delivery. Automatic retries will occur if the backend is unavailable.",
  "timestamp": "2026-03-08T09:00:00.000Z"
}
```

**Supported `notificationType` values:** `STATUS_CHANGE`, `BENEFIT_UPDATE`, `REGISTRATION`

---

### POST /notifications/retry

Manually retry the oldest message in the in-memory DLQ. Resets its retry counter to 0 for a full new round of delivery attempts.

**Response:**
```json
{ "status": "REQUEUED",  "message": "Message moved back to main queue for delivery", "messageId": "..." }
{ "status": "DLQ_EMPTY", "message": "No messages pending manual retry",              "messageId": null }
{ "status": "ERROR",     "message": "Failed to requeue: <reason>",                  "messageId": "..." }
```

---

### GET /notifications/dlq-status

List all messages currently awaiting manual retry.

**Response:**
```json
{
  "count": 1,
  "messages": [
    {
      "messageId": "550e8400-e29b-41d4-a716-446655440000",
      "personId": "P-12345",
      "notificationType": "BENEFIT_UPDATE",
      "data": { "amount": 35000 },
      "retryCount": 3,
      "createdAt": "2026-03-08T07:00:00.000Z",
      "lastAttemptAt": "2026-03-08T07:05:00.000Z"
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

## Retry Policy

| Attempt | Behaviour |
|---|---|
| 1 (initial) | Deliver to backend |
| 2–4 (auto retries) | Re-queued via TTL retry queue, 30 s delay between each |
| After attempt 4 | Moved to DLQ; available for manual retry via `POST /notifications/retry` |

> **Note:** The in-memory DLQ map is lost on pod restart. For production, persist DLQ messages to a database.

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

### Image

```
ramilu90/store_and_forward_integration:<IMAGE_TAG>
```

Platform: `linux/amd64` (built with `docker buildx` for AKS compatibility)

### Kubernetes resources

| Resource | Name | Namespace |
|---|---|---|
| Deployment | `store-and-forwa-deployment` | `ballerina` |
| Service | `store-and-forward-integration` | `ballerina` |
| HPA | `store-and-forwa` | `ballerina` |
| ConfigMap | `ballerina-values-store-and-forward` | `ballerina` |
| Secret | `rabbitmq-credentials` | `ballerina` |
| Secret | `ballerina-integration-secret` | `ballerina` |

---

## Sample curl Commands

```bash
# Port-forward (if not exposed via ingress)
kubectl port-forward svc/store-and-forward-integration 9085:9085 -n ballerina

HOST="http://localhost:9085"

# Queue a notification
curl -X POST "$HOST/notifications/send" \
  -H "Content-Type: application/json" \
  -d '{
    "personId": "P-12345",
    "notificationType": "BENEFIT_UPDATE",
    "data": { "amount": 35000, "period": "2026-Q1" }
  }'

# Check DLQ
curl "$HOST/notifications/dlq-status"

# Manually retry oldest DLQ message
curl -X POST "$HOST/notifications/retry"
```
