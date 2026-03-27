# Parallel Service Orchestration – Unemployment Fund Lookup

A Ballerina integration that implements a **Scatter-Gather pattern**: a single inbound request is fanned out simultaneously to 10 unemployment fund backends, all results are collected, classified, and returned as a single aggregated response — with a 3-second end-to-end SLA.

---

## Architecture

### Scatter-Gather Flow

```
Caller
  │
  │  POST /unemployment/lookup  { personId }
  ▼
┌──────────────────────────────────────────────────────────────────────┐
│          parallel_service_orchestration  (port 9090)                 │
│                                                                      │
│  ── SCATTER ────────────────────────────────────────────────────     │
│  All 10 fund calls fired simultaneously (Ballerina fork/wait)        │
│                                                                      │
│  ┌──────────┐  GET /lookup?personId=…  ┌───────────────────────┐    │
│  │ worker   ├─────────────────────────►│ Fund 1: AEA           │    │
│  │ fund1    │◄─────────────────────────┤ (normal latency)      │    │
│  └──────────┘  MemberInfo              └───────────────────────┘    │
│                                                                      │
│  ┌──────────┐  GET /lookup?personId=…  ┌───────────────────────┐    │
│  │ worker   ├─────────────────────────►│ Fund 2: Unionen       │    │
│  │ fund2    │◄─────────────────────────┤ (normal latency)      │    │
│  └──────────┘  MemberInfo              └───────────────────────┘    │
│                                                                      │
│  ┌──────────┐  GET /lookup?personId=…  ┌───────────────────────┐    │
│  │ worker   ├─────────────────────────►│ Fund 3: Akademikernas │    │
│  │ fund3    │◄─────────────────────────┤ (normal latency)      │    │
│  └──────────┘  MemberInfo              └───────────────────────┘    │
│                                                                      │
│  ┌──────────┐  GET /lookup?personId=…  ┌───────────────────────┐    │
│  │ worker   ├─────────────────────────►│ Fund 4: IF Metall     │    │
│  │ fund4    │◄─────────────────────────┤ (normal latency)      │    │
│  └──────────┘  MemberInfo              └───────────────────────┘    │
│                                                                      │
│  ┌──────────┐  GET /lookup?personId=…  ┌───────────────────────┐    │
│  │ worker   ├─────────────────────────►│ Fund 5: Kommunal      │    │
│  │ fund5    │◄─────────────────────────┤ (normal latency)      │    │
│  └──────────┘  MemberInfo              └───────────────────────┘    │
│                                                                      │
│  ┌──────────┐  GET /lookup?personId=…  ┌───────────────────────┐    │
│  │ worker   ├─────────────────────────►│ Fund 6: Handels       │    │
│  │ fund6    │◄─────────────────────────┤ (normal latency)      │    │
│  └──────────┘  MemberInfo              └───────────────────────┘    │
│                                                                      │
│  ┌──────────┐  GET /lookup?personId=…  ┌───────────────────────┐    │
│  │ worker   ├─────────────────────────►│ Fund 7: Vision        │    │
│  │ fund7    │◄─── TIMEOUT (2.9 s) ─────┤ (high latency)        │    │
│  └──────────┘  FundError               └───────────────────────┘    │
│                                                                      │
│  ┌──────────┐  GET /lookup?personId=…  ┌───────────────────────┐    │
│  │ worker   ├─────────────────────────►│ Fund 8: Transport     │    │
│  │ fund8    │◄─── TIMEOUT (2.9 s) ─────┤ (high latency)        │    │
│  └──────────┘  FundError               └───────────────────────┘    │
│                                                                      │
│  ┌──────────┐  GET /lookup?personId=…  ┌───────────────────────┐    │
│  │ worker   ├─────────────────────────►│ Fund 9: SEKO          │    │
│  │ fund9    │◄─── HTTP 503 ────────────┤ (always errors)       │    │
│  └──────────┘  FundError               └───────────────────────┘    │
│                                                                      │
│  ┌──────────┐  GET /lookup?personId=…  ┌───────────────────────┐    │
│  │ worker   ├─────────────────────────►│ Fund 10: Fastighets   │    │
│  │ fund10   │◄─── HTTP 200 {} ─────────┤ (empty body)          │    │
│  └──────────┘  BlankResponse           └───────────────────────┘    │
│                                                                      │
│  ── GATHER ─────────────────────────────────────────────────────     │
│  wait { fund1, fund2, ..., fund10 }  — blocks until all complete     │
│                                                                      │
│  ── CLASSIFY & AGGREGATE ───────────────────────────────────────     │
│                                                                      │
│   Each result classified into one of three buckets:                  │
│                                                                      │
│   ┌──────────────────────────────────────────────────────────┐      │
│   │  MemberInfo       → validResponses[]                     │      │
│   │  { fund, personId, status, registeredSince, memberType } │      │
│   └──────────────────────────────────────────────────────────┘      │
│   ┌──────────────────────────────────────────────────────────┐      │
│   │  FundError        → errors[]                             │      │
│   │  { fund, errorType: TIMEOUT|SERVICE_ERROR, message }     │      │
│   └──────────────────────────────────────────────────────────┘      │
│   ┌──────────────────────────────────────────────────────────┐      │
│   │  BlankResponse    → blankResponses[]                     │      │
│   │  { fund, message }  (HTTP 200 but empty / no data)       │      │
│   └──────────────────────────────────────────────────────────┘      │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
  │
  │  HTTP 200  AggregatedResponse
  │  {
  │    personId,
  │    totalFundsQueried: 10,
  │    summary: { validCount, errorCount, blankCount },
  │    validResponses: [ MemberInfo, ... ],
  │    errors:         [ FundError, ... ],
  │    blankResponses: [ BlankResponse, ... ]
  │  }
  ▼
Caller
```

### Response Classification Rules

Each fund call is independently classified by `callFund()`:

```
GET /lookup?personId=…
          │
          ├── Network / transport error ──────────────────► FundError  (TIMEOUT | SERVICE_ERROR)
          │   (connection refused, timeout after 2.9 s)
          │
          ├── HTTP 4xx / 5xx ─────────────────────────────► FundError  (SERVICE_ERROR)
          │
          ├── HTTP 200  +  empty body / non-JSON ─────────► BlankResponse
          │                                                  "Person not registered"
          │
          ├── HTTP 200  +  {} (empty object) ─────────────► BlankResponse
          │                                                  "Person not registered"
          │
          └── HTTP 200  +  valid JSON MemberInfo ─────────► MemberInfo  ✓
```

---

## Fund Backends (Demo Behaviour)

| Fund | Name | Configured Behaviour |
|------|------|----------------------|
| fund1 | AEA | Normal — returns `MemberInfo` |
| fund2 | Unionen | Normal — returns `MemberInfo` |
| fund3 | Akademikernas | Normal — returns `MemberInfo` |
| fund4 | IF Metall | Normal — returns `MemberInfo` |
| fund5 | Kommunal | Normal — returns `MemberInfo` |
| fund6 | Handels | Normal — returns `MemberInfo` |
| fund7 | Vision | **High latency** — times out at 2.9 s → `FundError (TIMEOUT)` |
| fund8 | Transport | **High latency** — times out at 2.9 s → `FundError (TIMEOUT)` |
| fund9 | SEKO | **Always HTTP 503** → `FundError (SERVICE_ERROR)` |
| fund10 | Fastighets | **Always HTTP 200 with empty body** → `BlankResponse` |

> Funds 7–10 deliberately simulate real-world failure modes: slow services, unavailable services, and services that have no data for the person.

---

## SLA Design

| Constraint | Value |
|-----------|-------|
| Per-fund HTTP client timeout | **2.9 seconds** |
| Total end-to-end SLA | **~3 seconds** |
| Parallelism model | Ballerina `fork`/`wait` (all 10 workers run concurrently) |

Because all 10 fund calls run in parallel, the total response time is bounded by the slowest non-timed-out fund — not the sum of all fund latencies. Funds 7 & 8 will always consume the full 2.9 s budget before being classified as `TIMEOUT`.

---

## API

### `POST /unemployment/lookup`

**Request**
```json
{ "personId": "199001011234" }
```

**Response `200 OK`**
```json
{
  "personId": "199001011234",
  "totalFundsQueried": 10,
  "summary": {
    "validCount": 6,
    "errorCount": 3,
    "blankCount": 1
  },
  "validResponses": [
    {
      "fund": "AEA",
      "personId": "199001011234",
      "status": "ACTIVE",
      "registeredSince": "2020-01-15",
      "memberType": "FULL"
    }
  ],
  "errors": [
    { "fund": "Vision",    "errorType": "TIMEOUT",       "message": "..." },
    { "fund": "Transport", "errorType": "TIMEOUT",       "message": "..." },
    { "fund": "SEKO",      "errorType": "SERVICE_ERROR", "message": "HTTP 503 – ..." }
  ],
  "blankResponses": [
    { "fund": "Fastighets", "message": "Person not registered in this fund" }
  ]
}
```

---

## Configuration

Each fund backend URL is supplied via environment variable (injected from a Kubernetes ConfigMap):

| Variable | Description |
|----------|-------------|
| `fund1Url` | Base URL for AEA backend |
| `fund2Url` | Base URL for Unionen backend |
| `fund3Url` | Base URL for Akademikernas backend |
| `fund4Url` | Base URL for IF Metall backend |
| `fund5Url` | Base URL for Kommunal backend |
| `fund6Url` | Base URL for Handels backend |
| `fund7Url` | Base URL for Vision backend (high latency) |
| `fund8Url` | Base URL for Transport backend (high latency) |
| `fund9Url` | Base URL for SEKO backend (HTTP 503) |
| `fund10Url` | Base URL for Fastighets backend (empty body) |

Override locally with `Config.toml`:

```toml
fund1Url  = "http://localhost:9200"
fund2Url  = "http://localhost:9201"
fund3Url  = "http://localhost:9202"
fund4Url  = "http://localhost:9203"
fund5Url  = "http://localhost:9204"
fund6Url  = "http://localhost:9205"
fund7Url  = "http://localhost:9206"
fund8Url  = "http://localhost:9207"
fund9Url  = "http://localhost:9208"
fund10Url = "http://localhost:9209"
```

---

## Local Development

```bash
# Run mock fund backends first, then the integration
bal run
```

Service starts on **port 9090**.

```bash
curl -X POST http://localhost:9090/unemployment/lookup \
  -H "Content-Type: application/json" \
  -d '{"personId": "199001011234"}'
```

---

## Deployment

```bash
# Apply ConfigMap
kubectl apply -f config-map-parallel_service_ochastration.yaml -n ballerina

# Build, push image, and deploy to AKS
./amd64-deploy.sh
```

---

## File Structure

```
parallel_service_ochastration/
├── main.bal                                 – HTTP listener, scatter-gather logic, callFund()
├── connections.bal                          – HTTP client declarations (10 fund clients, 2.9 s timeout each)
├── types.bal                                – MemberLookupRequest, MemberInfo, FundError, BlankResponse, AggregatedResponse
├── parallel_service_ochastration.yaml       – OpenAPI spec
├── config-map-parallel_service_ochastration.yaml  – K8s ConfigMap (fund URLs)
├── Cloud.toml                               – Container image + K8s env ref declarations
├── Ballerina.toml                           – Project metadata and dependencies
└── amd64-deploy.sh                          – Local build + AKS deploy script
```
