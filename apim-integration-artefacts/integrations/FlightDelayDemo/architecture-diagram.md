# Flight Delay Demo — Architecture Diagrams

> All diagrams below use [Mermaid](https://mermaid.js.org/) syntax.
> Render with any Mermaid-compatible viewer (GitHub, VS Code Mermaid Preview, mermaid.live, etc.)

---

## 1. System Overview — All Services & Connections

```mermaid
graph TB
    subgraph "User Layer"
        Browser["🌐 User Browser<br/>http://localhost:3000"]
    end

    subgraph "Frontend"
        Dashboard["📊 ADR Dashboard<br/>React 18 + Vite + TailwindCSS<br/>nginx:alpine • Port 3000"]
    end

    subgraph "Identity & Access Management"
        IS["🔐 WSO2 Identity Server 7.2.0<br/>OAuth2 / OIDC / OBO / Agent Auth<br/>Port 9444 (HTTPS)"]
    end

    subgraph "API Gateway"
        APIM["🌐 WSO2 API Manager 4.6.0<br/>7 APIs Published<br/>Admin 9446 • GW 8246/8283"]
    end

    subgraph "AI / LLM Layer"
        Ollama["🤖 Ollama<br/>qwen3:1.7b (CPU)<br/>Port 11434"]
    end

    subgraph "Orchestration Layer"
        Orchestrator["🧠 ADR Orchestrator<br/>Ballerina • Port 9094 (REST) / 9095 (AI)"]
        MCP["🔌 MCP Server<br/>Streamable HTTP Transport<br/>22 Tools • Port 9096"]
    end

    subgraph "Microservices Layer"
        DD["✈️ Disruption Detection<br/>Ballerina • Port 9090<br/>/disruption"]
        CS["👥 Crew Service<br/>Ballerina • Port 9091<br/>/crew"]
        PS["🧳 Passenger Service<br/>Ballerina • Port 9092<br/>/passenger"]
        LS["🏗️ Logistics Service<br/>Ballerina • Port 9093<br/>/logistics"]
    end

    subgraph "Data Layer"
        MySQL[("🗄️ MySQL 8.0<br/>flight_delay_db<br/>13 Tables • Port 3306/3307")]
    end

    Browser -->|"OIDC PKCE Login"| IS
    Browser -->|"SPA"| Dashboard
    Dashboard -->|"Bearer Token"| APIM
    Dashboard -->|"Proxied /is/*"| IS

    APIM -->|"/disruption/1.0.0"| DD
    APIM -->|"/crew/1.0.0"| CS
    APIM -->|"/passenger/1.0.0"| PS
    APIM -->|"/logistics/1.0.0"| LS
    APIM -->|"/adr/1.0.0"| Orchestrator
    APIM -->|"/ai-agent/1.0.0"| Orchestrator
    APIM -->|"/ollama/1.0.0 (AI API)"| Ollama

    Orchestrator -->|"LLM via AI Gateway<br/>ApiKey Auth"| APIM
    Orchestrator -->|"MCP tool discovery<br/>& execution"| MCP
    Orchestrator -->|"OBO token flow"| IS
    Orchestrator -->|"Direct DB reads"| MySQL

    MCP -->|"Proxy"| DD
    MCP -->|"Proxy"| CS
    MCP -->|"Proxy"| PS
    MCP -->|"Proxy"| LS
    MCP -->|"Proxy /adr"| Orchestrator

    DD --> MySQL
    CS --> MySQL
    PS --> MySQL
    LS --> MySQL

    classDef frontend fill:#4FC3F7,stroke:#0288D1,color:#000
    classDef iam fill:#FFB74D,stroke:#F57C00,color:#000
    classDef gateway fill:#81C784,stroke:#388E3C,color:#000
    classDef ai fill:#CE93D8,stroke:#7B1FA2,color:#000
    classDef orch fill:#FFF176,stroke:#FBC02D,color:#000
    classDef service fill:#A5D6A7,stroke:#2E7D32,color:#000
    classDef data fill:#EF9A9A,stroke:#C62828,color:#000

    class Dashboard frontend
    class IS iam
    class APIM gateway
    class Ollama ai
    class Orchestrator,MCP orch
    class DD,CS,PS,LS service
    class MySQL data
```

---

## 2. Docker Compose — Container Topology

```mermaid
graph LR
    subgraph "Docker Network: adr-network (bridge)"

        subgraph "Data Tier"
            mysql["adr-mysql<br/>mysql:8.0<br/>3307:3306"]
        end

        subgraph "Platform Tier"
            is["adr-identity-server<br/>WSO2 IS 7.2.0<br/>9444:9444"]
            apim["adr-api-manager<br/>WSO2 APIM 4.6.0<br/>9446, 8246, 8283"]
            ollama["adr-ollama<br/>ollama/ollama<br/>11434:11434"]
        end

        subgraph "Services Tier"
            dd["adr-disruption-detection<br/>Ballerina<br/>9090:9090"]
            cs["adr-crew-service<br/>Ballerina<br/>9091:9091"]
            ps["adr-passenger-service<br/>Ballerina<br/>9092:9092"]
            ls["adr-logistics-service<br/>Ballerina<br/>9093:9093"]
        end

        subgraph "Orchestration Tier"
            mcp["adr-mcp-server<br/>Ballerina MCP<br/>9096:9096"]
            orch["adr-orchestrator<br/>Ballerina AI Agent<br/>9094, 9095"]
        end

        subgraph "Frontend Tier"
            dash["adr-dashboard<br/>React + nginx<br/>3000:3000"]
        end
    end

    mysql -.->|"depends_on"| dd
    mysql -.->|"depends_on"| cs
    mysql -.->|"depends_on"| ps
    mysql -.->|"depends_on"| ls

    dd -.->|"depends_on"| mcp
    cs -.->|"depends_on"| mcp
    ps -.->|"depends_on"| mcp
    ls -.->|"depends_on"| mcp

    mcp -.->|"depends_on"| orch
    mysql -.->|"depends_on"| orch
    ollama -.->|"depends_on"| orch

    orch -.->|"depends_on"| dash
    mcp -.->|"depends_on"| dash
```

---

## 3. API Manager — Published APIs & Gateway Routing

```mermaid
graph LR
    Client["Client<br/>(Dashboard / Postman)"]

    subgraph "WSO2 APIM 4.6.0 Gateway — Port 8246"
        GW{"API Gateway<br/>JWT Validation<br/>Rate Limiting<br/>AI Governance"}
    end

    subgraph "Backend Services"
        DD["/disruption → DD:9090"]
        CS["/crew → CS:9091"]
        PS["/passenger → PS:9092"]
        LS["/logistics → LS:9093"]
        ADR["/adr → Orch:9094"]
        AI["/ai-agent → Orch:9095"]
        LLM["/ollama (AIAPI) → Ollama:11434"]
    end

    Client -->|"Bearer JWT / ApiKey"| GW
    GW -->|"DisruptionDetectionAPI<br/>/disruption/1.0.0/*"| DD
    GW -->|"CrewServiceAPI<br/>/crew/1.0.0/*"| CS
    GW -->|"PassengerServiceAPI<br/>/passenger/1.0.0/*"| PS
    GW -->|"LogisticsServiceAPI<br/>/logistics/1.0.0/*"| LS
    GW -->|"ADROrchestratorAPI<br/>/adr/1.0.0/*"| ADR
    GW -->|"AIAgentAPI<br/>/ai-agent/1.0.0/*"| AI
    GW -->|"OllamaAIAPI<br/>/ollama/1.0.0/*"| LLM

    style GW fill:#81C784,stroke:#2E7D32,color:#000
    style LLM fill:#CE93D8,stroke:#7B1FA2,color:#000
```

---

## 4. AI Agent — LLM Reasoning Loop with MCP Tools

```mermaid
sequenceDiagram
    autonumber
    participant U as User (Dashboard)
    participant GW as APIM Gateway
    participant AI as AI Agent :9095
    participant LLM as Ollama (via APIM AI GW)
    participant MCP as MCP Server :9096
    participant SVC as Backend Services

    U->>GW: POST /ai-agent/1.0.0/chat<br/>{message, session_id}
    GW->>AI: Forward (JWT validated)

    alt No OBO Token
        AI-->>U: 401 → Redirect to OBO consent URL
    end

    AI->>AI: Build system prompt<br/>+ 22 MCP tool definitions

    loop Up to 10 iterations
        AI->>LLM: POST /ollama/1.0.0/api/chat<br/>{model, messages, tools}
        LLM-->>AI: Response (tool_calls or text)

        alt Tool Call Detected
            AI->>MCP: POST /mcp (callTool)
            MCP->>SVC: HTTP call to backend service
            SVC-->>MCP: JSON result
            MCP-->>AI: Tool result
            AI->>AI: Append tool result to messages
        else Final Text Response
            AI-->>GW: {response, function_called,<br/>function_result, tokens}
            GW-->>U: 200 OK
        end
    end
```

---

## 5. OAuth2 / OBO (On-Behalf-Of) Token Flow

```mermaid
sequenceDiagram
    autonumber
    participant U as User Browser
    participant D as Dashboard
    participant IS as WSO2 IS 7.2.0
    participant AI as AI Agent :9095

    Note over U,AI: Phase 1 — User Login (Standard OIDC)
    U->>D: Visit http://localhost:3000
    D->>IS: Authorization Code + PKCE
    IS-->>U: Login Page
    U->>IS: Credentials (adr_admin / Admin@123)
    IS-->>D: Authorization Code
    D->>IS: Exchange code → JWT tokens
    IS-->>D: access_token + id_token + refresh_token

    Note over U,AI: Phase 2 — AI Chat triggers OBO
    U->>D: Send chat message
    D->>AI: POST /ai/chat {message, session_id}
    AI-->>D: 401 → consent_url

    Note over U,AI: Phase 3 — Agent Self-Authentication
    AI->>IS: POST /oauth2/authorize<br/>(response_mode=direct, PKCE)
    IS-->>AI: flowId
    AI->>IS: POST /oauth2/authn<br/>(BasicAuthenticator, agent creds)
    IS-->>AI: authorization_code
    AI->>IS: POST /oauth2/token<br/>(code + code_verifier)
    IS-->>AI: agent_access_token

    Note over U,AI: Phase 4 — User Consent for Delegation
    D->>U: Open consent URL in popup
    U->>IS: Authorize + approve 6 ADR scopes
    IS-->>AI: GET /ai/callback?code=...

    Note over U,AI: Phase 5 — Delegated Token Exchange
    AI->>IS: POST /oauth2/token<br/>(actor_token=agent_token,<br/>code + code_verifier,<br/>resource=https://adr.wso2.com/api)
    IS-->>AI: OBO JWT (sub=user, act=agent,<br/>scope=6 ADR scopes)

    Note over U,AI: Phase 6 — Resume Chat with OBO Token
    AI->>AI: Cache OBO token per session
    D->>AI: Retry POST /ai/chat
    AI->>AI: Process with delegated identity
```

---

## 6. MCP Server — 22 Tools by Category

```mermaid
graph TB
    subgraph "MCP Server (Port 9096)"
        MCP["Streamable HTTP MCP Transport<br/>Stateless Sessions"]
    end

    subgraph "Recovery Tools (3)"
        T1["trigger_recovery"]
        T2["get_recovery_plan"]
        T3["list_recovery_plans"]
    end

    subgraph "Disruption Detection Tools (6)"
        T4["get_all_flights"]
        T5["get_flight_details"]
        T6["get_flight_seats"]
        T7["assess_disruption"]
        T8["get_active_delays"]
        T9["report_flight_delay"]
    end

    subgraph "Crew Management Tools (4)"
        T10["get_crew_assignments"]
        T11["get_available_crew"]
        T12["check_crew_compliance"]
        T13["reassign_crew"]
    end

    subgraph "Passenger Management Tools (5)"
        T14["get_passenger_bookings"]
        T15["get_alternative_flights"]
        T16["rebook_passenger"]
        T17["notify_passenger"]
        T18["process_compensation"]
    end

    subgraph "Logistics Tools (4)"
        T19["get_available_gates"]
        T20["assign_gate"]
        T21["redirect_catering"]
        T22["notify_ground_handling"]
    end

    MCP --- T1 & T2 & T3
    MCP --- T4 & T5 & T6 & T7 & T8 & T9
    MCP --- T10 & T11 & T12 & T13
    MCP --- T14 & T15 & T16 & T17 & T18
    MCP --- T19 & T20 & T21 & T22

    subgraph "Backend Routing"
        ORCH["Orchestrator :9094"]
        DD["Disruption Detection :9090"]
        CS["Crew Service :9091"]
        PS["Passenger Service :9092"]
        LS["Logistics Service :9093"]
    end

    T1 & T2 & T3 -->|"/adr"| ORCH
    T4 & T5 & T6 & T7 & T8 & T9 -->|"/disruption"| DD
    T10 & T11 & T12 & T13 -->|"/crew"| CS
    T14 & T15 & T16 & T17 & T18 -->|"/passenger"| PS
    T19 & T20 & T21 & T22 -->|"/logistics"| LS
```

---

## 7. Database Schema — Entity Relationships

```mermaid
erDiagram
    flights {
        INT id PK
        VARCHAR flight_number
        VARCHAR airline
        VARCHAR origin
        VARCHAR destination
        DATETIME departure_time
        DATETIME arrival_time
        VARCHAR status
        VARCHAR aircraft_type
        INT gate_number
    }

    disruptions {
        INT id PK
        INT flight_id FK
        VARCHAR disruption_type
        VARCHAR severity
        TEXT description
        DATETIME detected_at
        VARCHAR status
    }

    seat_inventory {
        INT id PK
        INT flight_id FK
        VARCHAR seat_class
        INT total_seats
        INT available_seats
    }

    flight_crew_requirements {
        INT id PK
        INT flight_id FK
        VARCHAR role
        INT required_count
    }

    crew_members {
        INT id PK
        VARCHAR name
        VARCHAR role
        VARCHAR base_airport
        VARCHAR status
        DECIMAL duty_hours
        DATETIME last_rest
    }

    crew_assignments {
        INT id PK
        INT crew_member_id FK
        INT flight_id FK
        VARCHAR role
        VARCHAR status
    }

    passengers {
        INT id PK
        VARCHAR name
        VARCHAR email
        VARCHAR phone
        VARCHAR loyalty_tier
    }

    bookings {
        INT id PK
        INT passenger_id FK
        INT flight_id FK
        VARCHAR seat_class
        VARCHAR booking_status
    }

    notifications {
        INT id PK
        INT passenger_id FK
        VARCHAR notification_type
        TEXT message
        DATETIME sent_at
    }

    compensations {
        INT id PK
        INT passenger_id FK
        INT flight_id FK
        VARCHAR compensation_type
        DECIMAL amount
        VARCHAR status
    }

    passenger_flight_history {
        INT id PK
        INT passenger_id FK
        INT flight_id FK
        VARCHAR status
    }

    gates {
        INT id PK
        VARCHAR airport
        VARCHAR gate_number
        VARCHAR gate_type
        VARCHAR status
        INT assigned_flight_id FK
    }

    catering_orders {
        INT id PK
        INT flight_id FK
        VARCHAR gate_number
        VARCHAR status
        DATETIME order_time
    }

    ground_handling_tasks {
        INT id PK
        INT flight_id FK
        VARCHAR task_type
        VARCHAR status
        DATETIME created_at
    }

    recovery_plans {
        INT id PK
        INT disruption_id FK
        TEXT plan_details
        VARCHAR status
        DATETIME created_at
    }

    flights ||--o{ disruptions : "has"
    flights ||--o{ seat_inventory : "has"
    flights ||--o{ flight_crew_requirements : "requires"
    flights ||--o{ crew_assignments : "assigned"
    flights ||--o{ bookings : "booked on"
    flights ||--o{ catering_orders : "catered"
    flights ||--o{ ground_handling_tasks : "handled"
    flights ||--o| gates : "assigned to"

    crew_members ||--o{ crew_assignments : "assigned"

    passengers ||--o{ bookings : "has"
    passengers ||--o{ notifications : "receives"
    passengers ||--o{ compensations : "compensated"
    passengers ||--o{ passenger_flight_history : "history"

    disruptions ||--o{ recovery_plans : "resolved by"

    bookings }o--|| flights : "for"
    compensations }o--|| flights : "for"
```

---

## 8. ADR Recovery Pipeline — 5-Step Orchestration

```mermaid
flowchart TD
    Start(["POST /adr/recover<br/>{disruption_id}"]) --> Step1

    subgraph "Step 1 — Assess Disruption"
        Step1["GET /disruption/delays<br/>GET /disruption/{id}"]
        Step1 --> Step1a["GET /disruption/flights/{id}/assess"]
        Step1a --> Step1b{"Severity?"}
    end

    Step1b -->|"Low / Medium / High"| Step2

    subgraph "Step 2 — Crew Recovery"
        Step2["GET /crew/assignments/{flightId}"]
        Step2 --> Step2a["POST /crew/check-compliance"]
        Step2a --> Step2b{"Compliance OK?"}
        Step2b -->|"No"| Step2c["GET /crew/available"]
        Step2c --> Step2d["POST /crew/reassign"]
        Step2b -->|"Yes"| Step3
        Step2d --> Step3
    end

    subgraph "Step 3 — Passenger Recovery"
        Step3["GET /passenger/bookings/{flightId}"]
        Step3 --> Step3a["GET /passenger/alternatives/{flightId}"]
        Step3a --> Step3b["POST /passenger/rebook<br/>(seat-aware, priority by loyalty)"]
        Step3b --> Step3c["POST /passenger/notify"]
        Step3c --> Step3d["POST /passenger/compensation<br/>(smart: loyalty + no-alternatives aware)"]
    end

    Step3d --> Step4

    subgraph "Step 4 — Logistics Recovery"
        Step4["GET /logistics/gates/available/{airport}"]
        Step4 --> Step4a["POST /logistics/gates/assign"]
        Step4a --> Step4b["POST /logistics/catering/redirect"]
        Step4b --> Step4c["POST /logistics/ground-handling/notify"]
    end

    Step4c --> Step5

    subgraph "Step 5 — Save Recovery Plan"
        Step5["INSERT recovery_plans<br/>(all actions + results)"]
    end

    Step5 --> Done(["200 OK<br/>Recovery Plan"])

    style Start fill:#4FC3F7,stroke:#0288D1,color:#000
    style Done fill:#81C784,stroke:#2E7D32,color:#000
```

---

## 9. Deployment Automation — One-Click Flow

```mermaid
flowchart TD
    Start(["docker compose up --build -d"])
    Start --> Build["Build 10+ containers<br/>from Dockerfiles"]
    Build --> Wait["Wait for IS + APIM<br/>health checks"]
    Wait --> Script(["./create_apis.sh"])

    subgraph "create_apis.sh (~1051 lines)"
        Script --> IS_Config["WSO2 IS Configuration"]
        IS_Config --> IS1["Create OIDC App<br/>(ADRFlightDelaySPA)"]
        IS1 --> IS2["Create AI Agent<br/>(SCIM2 /scim2/Agents)"]
        IS2 --> IS3["Register API Resource<br/>(https://adr.wso2.com/api)<br/>6 ADR scopes"]
        IS3 --> IS4["Authorize App → API Resource<br/>(No Policy)"]
        IS4 --> IS5["Create App Roles<br/>(adr_admin, adr_operator)"]
        IS5 --> IS6["Create Demo Users<br/>(adr_admin, adr_operator)"]
        IS6 --> IS7["Register OBO Credentials<br/>for AI Agent"]

        IS7 --> APIM_Config["WSO2 APIM Configuration"]
        APIM_Config --> AP1["Register IS as Key Manager"]
        AP1 --> AP2["Publish 7 APIs<br/>(6 REST + 1 AIAPI)"]
        AP2 --> AP3["Register Ollama as<br/>AI Service Provider"]
        AP3 --> AP4["Create Application<br/>+ Subscribe all APIs"]
        AP4 --> AP5["Generate API Key"]

        AP5 --> Inject["Inject Runtime Config"]
        Inject --> INJ1["Config.docker.orchestrator.toml<br/>(agentId, agentSecret,<br/>appClientId, aiGatewayToken)"]
        INJ1 --> INJ2["auth-config.js<br/>(clientID, IS URLs, scopes)"]
        INJ2 --> Restart["Restart orchestrator<br/>+ dashboard containers"]
    end

    Restart --> Done(["✅ All services ready<br/>http://localhost:3000"])

    style Start fill:#4FC3F7,stroke:#0288D1,color:#000
    style Done fill:#81C784,stroke:#2E7D32,color:#000
    style Script fill:#FFF176,stroke:#FBC02D,color:#000
```

---

## 10. Network & Port Map

```mermaid
graph LR
    subgraph "Host Machine Ports"
        H3000["3000 → Dashboard"]
        H3307["3307 → MySQL"]
        H8246["8246 → APIM GW HTTPS"]
        H8283["8283 → APIM GW HTTP"]
        H9090["9090 → Disruption Detection"]
        H9091["9091 → Crew Service"]
        H9092["9092 → Passenger Service"]
        H9093["9093 → Logistics Service"]
        H9094["9094 → Orchestrator REST"]
        H9095["9095 → Orchestrator AI"]
        H9096["9096 → MCP Server"]
        H9444["9444 → Identity Server"]
        H9446["9446 → APIM Admin"]
        H11434["11434 → Ollama"]
    end

    subgraph "Docker Internal DNS"
        D1["adr-mysql:3306"]
        D2["adr-identity-server:9444"]
        D3["adr-api-manager:9446/8246/8283"]
        D4["adr-ollama:11434"]
        D5["adr-disruption-detection:9090"]
        D6["adr-crew-service:9091"]
        D7["adr-passenger-service:9092"]
        D8["adr-logistics-service:9093"]
        D9["adr-mcp-server:9096"]
        D10["adr-orchestrator:9094/9095"]
        D11["adr-dashboard:3000"]
    end

    H3000 --- D11
    H3307 --- D1
    H8246 --- D3
    H8283 --- D3
    H9090 --- D5
    H9091 --- D6
    H9092 --- D7
    H9093 --- D8
    H9094 --- D10
    H9095 --- D10
    H9096 --- D9
    H9444 --- D2
    H9446 --- D3
    H11434 --- D4
```
