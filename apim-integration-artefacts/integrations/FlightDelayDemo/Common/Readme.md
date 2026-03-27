# Common Services — Autonomous Disruption Recovery (ADR)

This directory contains the Ballerina microservices source code that power the Flight Delay Demo.

> **📖 For deployment instructions, demo walkthrough, and testing guide, see the [Use Case README](../Usecase_Autonomous_Disruption_Recovery/Readme.md).**
>
> **For project overview and architecture, see the [Main README](../README.md).**

## Services

| Service | Port | Description |
|---------|------|-------------|
| DisruptionDetection | 9090 | Flight monitoring, delay detection, schedule management |
| CrewService | 9091 | Crew duty hour tracking, compliance checking, crew reassignment |
| PassengerService | 9092 | Passenger rebooking, VIP-aware compensation, notifications |
| LogisticsService | 9093 | Gate management, catering redirection, ground handling |
| ADROrchestrator | 9094 | Multi-service coordinator — the "Digital War Room" (REST API only) |
| AdminAgent | 9095 | AI-powered admin interface — MCP-only tool discovery (22 tools) via APIM MCP Gateway with OBO auth |
| MCPServer | 9096 | MCP Server — 22 tools proxying all backend services |
| CustomerServiceAgent | 9097 | Customer service copilot — keyword→MCP tool routing |
| NativeCustomerServiceAgent | 9098 | Ballerina-native AI agent using `ballerina/ai` module's `ai:Agent` pattern |

## Configuration

All services share `Config.toml` for database connectivity. Update this file with your MySQL credentials before running locally.

For Docker deployment, the `Config.docker.*.toml` files in the `FullyDockered/` directory provide container-specific configurations (Docker network hostnames, APIM URLs, etc.).

## Running Locally

```bash
# From each service directory:
bal run
```

> **Note:** Local development requires MySQL, Ollama, and optionally WSO2 APIM/IS running separately. For a fully self-contained deployment, use the [Dockerized setup](../Usecase_Autonomous_Disruption_Recovery/Readme.md#deployment-fully-dockerized) instead.
