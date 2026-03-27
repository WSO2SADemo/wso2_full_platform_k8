# ✈️ Autonomous Disruption Recovery (ADR) — Flight Delay Demo

## Project Overview

This demo showcases an **Agentic AI-powered Autonomous Disruption Recovery** system for the aviation industry. When a flight delay occurs at a major hub, AI agents and backend microservices collaborate in real-time to negotiate and execute a recovery plan — balancing cost, regulatory compliance, and customer experience — without manual human intervention for each individual rebooking.

### The Problem

A 2-hour delay at a major hub (e.g., London Heathrow) triggers a chaotic chain reaction:
- **300+ passengers** need rebooking across multiple flights
- **Crew Operations** must verify pilots aren't hitting legal "duty hour" limits
- **Catering & Logistics** must redirect thousands of meals and reassign gates
- Departments work in **silos** — a human "Controller" must manually check 4–5 different screens to make one decision

### The Agentic Solution

Instead of humans shuffling data, **AI Agents + backend microservices** collaborate in a "Digital War Room":

| Component | Type | Role |
|-----------|------|------|
| **Disruption Detection Service** | Microservice | Monitors flights and detects delays in real-time |
| **Crew Service** | Microservice | Checks crew duty hours, finds available crew, ensures regulatory compliance |
| **Passenger Service** | Microservice | Handles intelligent rebooking, VIP-aware compensation, proactive notifications |
| **Logistics Service** | Microservice | Manages gate assignments, catering redirection, ground handling coordination |
| **ADR Orchestrator** | Microservice | Coordinates all services, runs multi-service negotiation, produces a unified recovery plan |
| **MCP Server** | Tool Gateway | Exposes 22 tools from all backend services via Model Context Protocol |
| **Admin Agent** | AI Agent | LLM-powered natural language interface for admin staff (MCP tool discovery via APIM) |
| **Customer Service Agent** | AI Agent | MCP copilot for customer service operators |
| **Native CS Agent** | AI Agent | Ballerina-native `ai:Agent` pattern for customer service |

### Architecture Diagram

```
┌───────────────────────────────────────────────────────────────────────────┐
│                          WSO2 API Manager 4.6.0                          │
│              AI Gateway · MCP Gateway Proxy · REST API Gateway            │
└────┬──────────────────────┬──────────────────────┬────────────────────────┘
     │ /ollama/1.0.0        │ /adr-mcp/1.0.0/mcp   │ REST APIs
     │ (AI Gateway)         │ (MCP Gateway)         │
     ▼                      ▼                       ▼
┌──────────┐      ┌─────────────────┐     ┌─────────────────────────────────┐
│  Ollama  │      │   MCP Server    │     │       Backend Microservices     │
│  (LLM)   │      │   (Port 9096)   │     │                                │
│ qwen3:   │      │   22 tools      │────▶│ ┌───────────┐ ┌─────────────┐  │
│ 1.7b     │      └─────────────────┘     │ │Disruption │ │Crew Service │  │
└──────────┘                              │ │Detection  │ │ (Port 9091) │  │
                                          │ │(Port 9090)│ └─────────────┘  │
     ┌─────────────────────────┐          │ └───────────┘                  │
     │    ADR Orchestrator     │          │ ┌───────────┐ ┌─────────────┐  │
     │      (Port 9094)        │─────────▶│ │Passenger  │ │ Logistics   │  │
     │   Recovery Coordinator  │          │ │Service    │ │ Service     │  │
     └─────────────────────────┘          │ │(Port 9092)│ │ (Port 9093) │  │
                                          │ └───────────┘ └─────────────┘  │
                                          └─────────────────────────────────┘
     ┌─────────────────────────┐                        │
     │   WSO2 Identity Server  │          ┌─────────────▼──────┐
     │        7.2.0            │          │      MySQL 8.0     │
     │  OAuth2 · OBO · JWT     │          │   (Port 3306)      │
     └─────────────────────────┘          └────────────────────┘

     ┌─────────────────────────────────────────────────────────┐
     │                    AI Agents                            │
     │                                                         │
     │  ┌─────────────┐  ┌──────────────────┐  ┌───────────┐  │
     │  │ Admin Agent  │  │ Customer Service │  │ Native CS │  │
     │  │ (Port 9095)  │  │ Agent (Port 9097)│  │   Agent   │  │
     │  │ LLM + 22 MCP │  │ Keyword→MCP      │  │ ai:Agent  │  │
     │  │ tools via    │  │ routing          │  │ pattern   │  │
     │  │ APIM Gateway │  │                  │  │           │  │
     │  └─────────────┘  └──────────────────┘  └───────────┘  │
     └─────────────────────────────────────────────────────────┘

     ┌─────────────────────────┐
     │    ADR Dashboard        │
     │    React + Tailwind     │
     │    (Port 3000)          │
     └─────────────────────────┘
```

---

## Efficiency Comparison

| Feature | Traditional Enterprise | Agentic Enterprise (WSO2 + AI) |
|---------|----------------------|-------------------------------|
| Response Time | 30–60 minutes per incident | < 1 minute (Instantaneous) |
| Data Access | Manual lookups in silos | Real-time via MCP Servers |
| Scaling | Need more staff during storms | Agents scale infinitely with cloud |
| Customer Experience | "Please wait for an agent" | Proactive re-booking & notifications |
| Regulatory Risk | Human error in crew legal hours | Built-in compliance checking via AI |

| Aspect | Traditional Automation | Agentic AI |
|--------|----------------------|------------|
| Logic | "If-Then-Else" (Fixed) | Goal-Oriented (Dynamic) |
| Handling Exceptions | Fails; requires human | Reasons through and adapts |
| Integration | Hard-coded API connections | Semantic tool discovery via MCP |

---

## System Requirements

- **Docker** & **Docker Compose** — [Download](https://docs.docker.com/get-docker/)
- **Postman** (optional, for testing) — [Download](https://www.postman.com/downloads/)

---

## Project Structure

```
FlightDelayDemo/
├── README.md                              # This file — project overview & architecture
├── Common/                                # All Ballerina service source code
│   ├── Config.toml                        # Local development configuration
│   ├── Readme.md                          # Service catalog & descriptions
│   ├── Database_schemas/
│   │   └── init.sql                       # Database initialization script
│   ├── DisruptionDetection/               # Flight monitoring & delay detection
│   ├── CrewService/                       # Crew duty hours & compliance
│   ├── PassengerService/                  # Passenger rebooking & notifications
│   ├── LogisticsService/                  # Gate, catering & ground handling
│   ├── ADROrchestrator/                   # Multi-agent coordinator (REST API)
│   ├── AdminAgent/                        # AI Agent — LLM + MCP tool discovery via APIM
│   ├── MCPServer/                         # MCP Server — 22 tools proxying all services
│   ├── CustomerServiceAgent/              # CS Copilot — keyword→MCP tool routing
│   └── NativeCustomerServiceAgent/        # Ballerina-native AI agent (ai:Agent pattern)
└── Usecase_Autonomous_Disruption_Recovery/
    ├── Readme.md                          # ★ Deployment guide & demo walkthrough
    ├── postman_collection/
    │   └── FlightDelayDemo.postman_collection.json  # 52 requests (REST + MCP)
    └── FullyDockered/                     # Docker Compose deployment
        ├── start.sh                      # One-command start
        ├── stop.sh                        # Stop all services
        ├── docker-compose.yml             # 13 containers
        ├── create_apis.sh                 # APIM API provisioning & IS setup
        ├── create_customer_service_mcp.sh # APIM MCP from existing APIs
        ├── adr-dashboard/                 # React operations dashboard
        └── Config.docker.*.toml           # Docker networking configurations
```

---

## Quick Start

```bash
cd Usecase_Autonomous_Disruption_Recovery/FullyDockered
./start.sh
```

This single command builds all Docker images, starts 13 containers (services, APIM, IS, Ollama, MySQL, dashboard), publishes APIs, and configures identity — everything needed to run the demo.

> **📖 For detailed deployment instructions, demo walkthrough, API endpoints, and MCP testing guide, see the [Use Case README](Usecase_Autonomous_Disruption_Recovery/Readme.md).**

---

## Key Integration Patterns

- **MCP-Only Tool Discovery** — Admin Agent discovers all 22 tools exclusively from the APIM MCP Gateway at startup (no hardcoded tools)
- **On-Behalf-Of (OBO) Flow** — AI agents acquire delegated user tokens from WSO2 IS and pass OBO Bearer tokens to downstream APIs
- **APIM as AI + MCP Gateway** — WSO2 APIM 4.6.0 proxies both Ollama LLM calls and MCP server requests with token-based auth
- **Customer Service MCP** — APIM generates a 14-tool MCP server from existing REST API definitions (zero code)

---

## More Information

For **deployment instructions**, **demo walkthrough**, **API endpoint reference**, **Postman testing guide**, and **MCP testing** — see the detailed guide inside the Use Case folder:

> **📖 [Usecase_Autonomous_Disruption_Recovery/Readme.md](Usecase_Autonomous_Disruption_Recovery/Readme.md)** — Complete step-by-step deployment, demo scenario walkthrough, all service endpoints, and Postman collection reference.

### Additional Resources

| Document | Description |
|----------|-------------|
| [Common Services README](Common/Readme.md) | Service catalog with ports and descriptions |
| [Architecture Diagram](architecture-diagram.md) | Detailed Mermaid architecture diagrams |
| [MCP Server README](Common/MCPServer/README.md) | MCP tool catalog (22 tools) |

---

## License

See [LICENSE](../../LICENSE) for details.
