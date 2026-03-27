# ADR Flight Recovery — MCP Server

## Overview

The MCP (Model Context Protocol) Server exposes all flight disruption recovery capabilities as **MCP tools** that any MCP-compatible AI client can discover and invoke dynamically.

This enables:
- **Dynamic tool discovery** — AI agents discover available tools at runtime via MCP protocol
- **External AI integration** — Claude Desktop, VS Code Copilot, and other MCP clients can connect directly
- **Decoupled architecture** — Tool definitions are centralized in the MCP server, not hardcoded in each AI agent

## Architecture

```
┌──────────────┐     MCP Protocol      ┌─────────────────┐
│  AI Agent    │────(HTTP/SSE)────────>│   MCP Server    │
│  (port 9095) │  listTools/callTool   │  (port 9096)    │
└──────────────┘                       │  22 MCP Tools   │
                                       └────────┬────────┘
┌──────────────┐                                │
│ Claude Desktop│──── MCP ──────────────────────┤
│ VS Code, etc. │                               │
└──────────────┘                       HTTP proxy to services:
                                       ┌────────┼────────┐
                                       │        │        │
                                  ┌────▼──┐┌───▼──┐┌───▼────┐
                                  │Disrup-││Crew  ││Passen- │
                                  │tion   ││Agent ││ger Agt │
                                  │(9090) ││(9091)││(9092)  │
                                  └───────┘└──────┘└────────┘
                                       │
                                  ┌────▼────┐┌────────────┐
                                  │Logistics││Orchestrator│
                                  │ (9093)  ││  (9094)    │
                                  └─────────┘└────────────┘
```

## Available Tools (22)

### Recovery Operations
| Tool | Description |
|------|-------------|
| `trigger_recovery` | Full autonomous recovery for a disrupted flight |
| `get_recovery_plan` | Get recovery plan details by ID |
| `list_recovery_plans` | List all recovery plans |

### Disruption Detection
| Tool | Description |
|------|-------------|
| `get_all_flights` | List all flights with status |
| `get_flight_details` | Flight details by ID |
| `get_flight_seats` | Seat availability for a flight |
| `assess_disruption` | Disruption risk assessment |
| `get_active_delays` | All active delays/disruptions |
| `report_flight_delay` | Report or update a flight delay |

### Crew Management
| Tool | Description |
|------|-------------|
| `get_crew_assignments` | Crew assigned to a flight |
| `get_available_crew` | Available crew at an airport |
| `check_crew_compliance` | Crew duty compliance check |
| `reassign_crew` | Reassign crew to a flight |

### Passenger Management
| Tool | Description |
|------|-------------|
| `get_passenger_bookings` | Passenger bookings for a flight |
| `get_alternative_flights` | Alternative rebooking options |
| `rebook_passenger` | Rebook passenger to new flight |
| `notify_passenger` | Send passenger notification |
| `process_compensation` | Smart passenger compensation |

### Logistics
| Tool | Description |
|------|-------------|
| `get_available_gates` | Available gates at airport |
| `assign_gate` | Assign gate to flight |
| `redirect_catering` | Redirect catering to new gate |
| `notify_ground_handling` | Create ground handling task |

## Running

### With Docker (recommended)
The MCP server is automatically deployed as part of the docker-compose stack:
```bash
docker compose up --build -d
```

### Standalone (local dev)
```bash
cd Common/MCPServer
bal run
```

Default config connects to local services. Override via `Config.toml`:
```toml
disruptionServiceUrl = "http://localhost:9090"
crewServiceUrl = "http://localhost:9091"
passengerServiceUrl = "http://localhost:9092"
logisticsServiceUrl = "http://localhost:9093"
orchestratorUrl = "http://localhost:9094"
mcpPort = 9096
```

## Connecting External MCP Clients

### Claude Desktop
Add to `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "adr-flight-recovery": {
      "url": "http://localhost:9096/mcp"
    }
  }
}
```

### VS Code (Copilot MCP)
Add to `.vscode/mcp.json`:
```json
{
  "servers": {
    "adr-flight-recovery": {
      "type": "http",
      "url": "http://localhost:9096/mcp"
    }
  }
}
```

### Custom MCP Client (Ballerina)
```ballerina
import ballerina/mcp;

final mcp:StreamableHttpClient mcpClient = check new ("http://localhost:9096/mcp");

public function main() returns error? {
    check mcpClient->initialize({name: "My Client", version: "1.0.0"});
    
    // Discover tools
    mcp:ListToolsResult tools = check mcpClient->listTools();
    
    // Call a tool
    mcp:CallToolResult result = check mcpClient->callTool({
        name: "get_active_delays",
        arguments: {}
    });
}
```

## Technology
- **Runtime**: Ballerina 2201.13.1
- **MCP Module**: `ballerina/mcp` 1.0.3
- **Transport**: Streamable HTTP (HTTP + SSE)
- **Session Mode**: Stateless
