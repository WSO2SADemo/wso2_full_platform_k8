# Autonomous Disruption Recovery (ADR) — Deployment & Demo Guide

## Overview

This is the **deployment and demo walkthrough guide** for the Autonomous Disruption Recovery use case.

> **For project overview, architecture diagrams, and efficiency comparisons, see the [Main README](../README.md).**
>
> **For service source code details, see the [Common Services README](../Common/Readme.md).**

This use case demonstrates an **Agentic AI-powered Autonomous Disruption Recovery** system for aviation operations. When a flight delay occurs at a major hub (e.g., London Heathrow), AI agents and backend microservices collaborate in real-time to negotiate and execute a recovery plan — balancing cost, regulatory compliance, and customer experience — without manual human intervention.

The deployment includes:

- **5 backend microservices** (Disruption Detection, Crew, Passenger, Logistics, ADR Orchestrator)
- **Admin Agent** — LLM-powered natural language interface for admin operations staff
- **MCP Server** — 22 tools proxying all backend services via Model Context Protocol
- **Customer Service Agent** — keyword→MCP tool routing copilot for CS operators
- **Customer Service MCP** — APIM-generated MCP server from existing REST APIs (14 tools)
- **WSO2 APIM 4.6.0** — API Gateway, MCP Gateway, AI Gateway
- **WSO2 IS 7.2.0** — Identity provider, OAuth2/OIDC, OBO agent flow
- **Ollama** — Local LLM (llama3.2)
- **MySQL 8.0** — Shared database

### What Happens During a Disruption

A 2-hour delay at a major hub triggers a chaotic chain reaction:
- **300+ passengers** need rebooking across multiple flights
- **Crew Operations** must verify pilots aren't hitting legal "duty hour" limits
- **Catering & Logistics** must redirect thousands of meals and reassign gates

### Services

| Service | Port | Role |
|---------|------|------|
| **Disruption Detection** | 9090 | Monitors flights and detects delays in real-time |
| **Crew Service** | 9091 | Checks crew duty hours, ensures regulatory compliance |
| **Passenger Service** | 9092 | VIP-aware rebooking, compensation, proactive notifications |
| **Logistics Service** | 9093 | Gate assignments, catering redirection, ground handling |
| **ADR Orchestrator** | 9094 | Coordinates all services, runs multi-service recovery negotiation |
| **Admin Agent** | 9095 | AI natural language interface (LLM + MCP tools) |
| **MCP Server** | 9096 | 22 MCP tools from all backend services |
| **Customer Service Agent** | 9097 | CS copilot — keyword→MCP tool routing |

All source code is in the `Common/` folder.

---

## Deployment (Fully Dockerized)

All services run as Docker containers via Docker Compose. No local installations required.

### Prerequisites

- **Docker** & **Docker Compose** — [Download](https://docs.docker.com/get-docker/)

### Deploy

```bash
cd FullyDockered
./start.sh
```

The script will:
1. Build Docker images for all Ballerina services
2. Start MySQL 8.0 with schema and seed data
3. Start WSO2 APIM 4.6.0 and WSO2 IS 7.2.0
4. Start Ollama and pull the llama3.2 model
5. Start all service containers connected via Docker networking
6. Publish REST APIs and MCP servers to APIM
7. Create the Customer Service MCP from existing APIs
8. Wait for all services to become healthy

Or run directly:
```bash
cd FullyDockered
docker compose up --build -d
```

### Stop

```bash
cd FullyDockered
./stop.sh             # Keep database volume
./stop.sh --clean     # Remove database volume (fresh start)
```

---

## Demo Walkthrough

### Part 1: Autonomous Recovery (Admin / Operations)

**Scenario: 3-Hour Delay at London Heathrow**

1. **Report a delay** on flight BA256 (FL001):
   ```bash
   curl -X PUT http://localhost:9090/disruption/flights/FL001/delay \
     -H 'Content-Type: application/json' \
     -d '{"delayMinutes": 180, "reason": "Severe thunderstorm at LHR"}'
   ```

2. **Trigger ADR Recovery** — the orchestrator coordinates all services:
   ```bash
   curl -X POST http://localhost:9094/adr/recover \
     -H 'Content-Type: application/json' \
     -d '{"flightId": "FL001", "disruptionType": "DELAY"}'
   ```

3. **Observe service negotiation** in the response:
   - Disruption Detection identifies affected passengers
   - Crew Service checks duty hour compliance for all assigned crew
   - Passenger Service applies VIP-aware compensation (PLATINUM gets bonus miles + upgrades)
   - Logistics Service reassigns gates and redirects catering
   - Orchestrator produces a unified **Recovery Plan** with full negotiation log

4. **View recovery plans:**
   ```bash
   curl http://localhost:9094/adr/recovery-plans
   ```

5. **Use the Admin Agent** (natural language via LLM):
   ```bash
   curl -X POST http://localhost:9095/ai/chat \
     -H 'Content-Type: application/json' \
     -d '{"message": "What flights are currently delayed?"}'
   ```

### Part 2: Customer Service Copilot (MCP from Existing APIs)

The Customer Service MCP exposes **14 tools** generated from existing REST APIs using WSO2 APIM's `generate-from-api` capability.

#### MCP Tools Reference

**Flight & Disruption Info** (from DisruptionDetectionAPI):

| # | Tool Name | Description |
|---|-----------|-------------|
| 1 | `getFlights` | List all flights with status and schedule |
| 2 | `getFlightById` | Get details for a specific flight |
| 3 | `getFlightSeats` | Check seat availability |
| 4 | `getActiveDisruptions` | View active disruptions |

**Passenger Management** (from PassengerServiceAPI):

| # | Tool Name | Description |
|---|-----------|-------------|
| 5 | `getBookingsByFlight` | Bookings for a specific flight |
| 6 | `getAllBookings` | All bookings across flights |
| 7 | `getPassengerById` | Passenger profile and preferences |
| 8 | `getPassengerHistory` | Flight history for a passenger |
| 9 | `getAlternativeFlights` | Find rebooking options |
| 10 | `getAlternativeFlightsDetailed` | Detailed rebooking options |
| 11 | `evaluateRebook` | Evaluate rebooking recommendations |
| 12 | `rebookPassenger` | Execute passenger rebooking |
| 13 | `notifyPassenger` | Send passenger notification |
| 14 | `processCompensation` | Process delay compensation |

#### Customer Service Scenario

A typical customer service interaction using these MCP tools:

1. **Customer calls about delayed flight FL001**
   - `getFlightById` → check flight status
   - `getActiveDisruptions` → understand the disruption

2. **Look up the customer's booking**
   - `getPassengerById` → get passenger profile (loyalty tier)
   - `getBookingsByFlight` → find their booking on FL001

3. **Find rebooking options**
   - `getAlternativeFlights` → available alternatives
   - `evaluateRebook` → get ranked recommendations

4. **Execute recovery actions**
   - `rebookPassenger` → move to new flight
   - `processCompensation` → issue compensation
   - `notifyPassenger` → send confirmation

#### Manual MCP Testing

```bash
# Get an access token
TOKEN=$(curl -sk -X POST https://localhost:9446/oauth2/token \
  -u '<CONSUMER_KEY>:<CONSUMER_SECRET>' \
  -d 'grant_type=client_credentials' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["access_token"])')

# MCP Initialize
curl -sk -X POST http://localhost:8283/cs-mcp/1.0.0/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}'

# List Available Tools
curl -sk -X POST http://localhost:8283/cs-mcp/1.0.0/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'

# Call a Tool — Get all flights
curl -sk -X POST http://localhost:8283/cs-mcp/1.0.0/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"getFlights","arguments":{}}}'
```

---

## Testing

Import the Postman collection from `postman_collection/`:

- **FlightDelayDemo.postman_collection.json** — Complete collection with REST API tests (Sections 1–6) and MCP tool tests via APIM (Sections 7–11)

Run the requests in order. Sections 7–11 require `create_customer_service_mcp.sh` to be run first.

---

## Service Endpoints

### Disruption Detection Service — Port 9090

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/disruption/flights` | List all flights |
| GET | `/disruption/flights/{id}` | Get flight details |
| POST | `/disruption/flights` | Register a new flight |
| PUT | `/disruption/flights/{id}/delay` | Report a delay |
| GET | `/disruption/delays` | Get all active disruptions |

### Crew Service — Port 9091

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/crew/members` | List all crew members |
| GET | `/crew/members/{id}` | Get crew member details |
| POST | `/crew/members` | Register a crew member |
| GET | `/crew/assignments/{flightId}` | Get crew assigned to a flight |
| POST | `/crew/check-compliance` | Check duty hour compliance |
| POST | `/crew/reassign` | Reassign crew to a different flight |
| GET | `/crew/available` | Find available crew members |

### Passenger Service — Port 9092

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/passenger/bookings/{flightId}` | Get passengers on a flight |
| GET | `/passenger/{id}` | Get passenger details |
| POST | `/passenger/rebook` | Rebook passenger to alternative flight |
| POST | `/passenger/notify` | Send notification to passenger |
| POST | `/passenger/compensation` | Determine VIP-aware compensation |
| GET | `/passenger/alternatives/{flightId}` | Find alternative flights for rebooking |

### Logistics Service — Port 9093

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/logistics/gates/available/{airport}` | Find available gates |
| POST | `/logistics/gates/assign` | Assign a gate |
| POST | `/logistics/catering/redirect` | Redirect catering to new flight |
| POST | `/logistics/ground-handling/notify` | Notify ground handling team |
| GET | `/logistics/resources/{airport}` | Get airport resource status |

### ADR Orchestrator — Port 9094

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/adr/recover` | **Trigger full autonomous recovery** for a disruption |
| GET | `/adr/recovery-plans` | List all recovery plans |
| GET | `/adr/recovery-plans/{id}` | Get recovery plan details |

### Admin Agent (AI) — Port 9095

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/ai/chat` | Natural language chat (LLM + 22 MCP tools via APIM) |
| GET | `/ai/callback` | OBO consent callback |
| GET | `/ai/health` | Health check (MCP tool count, model, OBO status) |

### MCP Server — Port 9096

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/mcp` | MCP Streamable HTTP endpoint (22 tools from all services) |

### Customer Service Agent — Port 9097

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/cs/chat` | Customer service copilot — keyword→MCP tool routing |
