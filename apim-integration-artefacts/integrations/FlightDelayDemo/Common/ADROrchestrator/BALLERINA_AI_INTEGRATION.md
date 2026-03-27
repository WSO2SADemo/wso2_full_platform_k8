# Ballerina AI Framework Integration

## Overview

The ADR Orchestrator now uses the **native Ballerina AI framework** for the AI agent implementation. This provides a more integrated, type-safe, and maintainable solution compared to external LLM APIs.

## What Changed

### Before (Ollama-based)
- External HTTP calls to Ollama service
- Manual JSON handling for tool definitions
- Custom response parsing logic
- Separate configuration for Ollama

### After (Ballerina AI Framework)
- Native Ballerina AI agent with built-in tool support
- Type-safe tool definitions as Ballerina functions
- Automatic tool execution and response handling
- Integrated with Ballerina's AI model providers

## Architecture

```
User Query
    ↓
/ai/chat endpoint (ai:Listener)
    ↓
ai:Agent (with tools)
    ↓
AI Model Provider (WSO2 or custom)
    ↓
Tool Execution (trigger_recovery, get_recovery_plan, list_recovery_plans)
    ↓
Orchestrator APIs (/adr/recover, /adr/recovery-plans)
    ↓
Response to User
```

## Key Components

### 1. AI Model Provider (`connections.bal`)

```ballerina
import ballerina/ai;

// Initialize AI model provider for ADR orchestrator agent
final ai:Wso2ModelProvider adrAgentModel = check ai:getDefaultModelProvider();
```

**Purpose**: Provides the underlying LLM for the AI agent.

### 2. System Prompt (`ai_agent.bal`)

```ballerina
const ai:SystemPrompt SYSTEM_PROMPT = {
    role: "You are an AI assistant for an Autonomous Disruption Recovery (ADR) system for airlines.",
    instructions: string `You help operations staff manage flight disruptions through natural language.
    
Your capabilities:
1. Trigger recovery operations for disrupted flights
2. Query recovery plan status and details
3. List all recovery plans
...`
};
```

**Purpose**: Defines the AI agent's role and capabilities.

### 3. Tool Functions (`ai_agent.bal`)

#### Tool 1: trigger_recovery
```ballerina
isolated function trigger_recovery(
    string flight_id,
    string disruption_type
) returns json|error {
    json payload = {
        flightId: flight_id,
        disruptionType: disruption_type
    };
    
    RecoverySummary result = check orchestratorClient->/adr/recover.post(payload);
    
    return {
        success: true,
        plan_id: result.plan_id,
        flight_id: result.flight_id,
        status: result.status,
        passengers_affected: result.passengers.total_affected,
        passengers_rebooked: result.passengers.rebooked,
        crew_reassignments: result.crew.reassignments,
        estimated_cost: result.estimated_cost,
        message: result.message
    };
}
```

#### Tool 2: get_recovery_plan
```ballerina
isolated function get_recovery_plan(
    string plan_id
) returns json|error {
    RecoveryPlan|http:Response result = check orchestratorClient->/adr/recovery\-plans/[plan_id]();
    
    if result is http:Response {
        if result.statusCode == 404 {
            return {
                success: false,
                message: string `Recovery plan ${plan_id} not found`
            };
        }
        return error("Failed to fetch recovery plan");
    }
    
    return {
        success: true,
        plan: result
    };
}
```

#### Tool 3: list_recovery_plans
```ballerina
isolated function list_recovery_plans() returns json|error {
    RecoveryPlan[] plans = check orchestratorClient->/adr/recovery\-plans();
    
    return {
        success: true,
        total_plans: plans.length(),
        plans: plans
    };
}
```

**Purpose**: These functions are automatically discovered and used as tools by the AI agent.

### 4. AI Agent Service (`ai_agent.bal`)

```ballerina
listener ai:Listener aiListener = new (listenOn = check new http:Listener(9095));

service /ai on aiListener {
    private final ai:Agent adrAgent;

    function init() returns error? {
        // Initialize AI agent with tools
        self.adrAgent = check new (
            systemPrompt = SYSTEM_PROMPT,
            model = adrAgentModel,
            tools = [trigger_recovery, get_recovery_plan, list_recovery_plans]
        );
        log:printInfo("ADR AI Agent initialized with tools");
    }

    resource function post chat(@http:Payload ai:ChatReqMessage request) returns ai:ChatRespMessage|error {
        log:printInfo(string `AI Agent received query: ${request.message}`);
        
        // Run the agent with the user message
        string response = check self.adrAgent.run(request.message, request.sessionId);
        
        log:printInfo(string `AI Agent response generated`);
        return {message: response};
    }

    resource function get health() returns string {
        return "AI Agent is running with Ballerina AI framework";
    }
}
```

**Purpose**: Exposes the AI agent as an HTTP service.

## API Usage

### Request Format

```json
POST /ai/chat
Content-Type: application/json

{
  "message": "Flight FL001 is delayed due to weather, start recovery",
  "sessionId": "optional-session-id"
}
```

### Response Format

```json
{
  "message": "I've initiated autonomous recovery for flight FL001 due to weather delay. Recovery plan abc-123 has been created. The system affected 150 passengers, successfully rebooked 145, and made 2 crew reassignments. Estimated cost: $12,500."
}
```

## Example Interactions

### Example 1: Trigger Recovery

**Request:**
```bash
curl -X POST http://localhost:9095/ai/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Flight FL001 is delayed due to weather, start recovery"
  }'
```

**What Happens:**
1. AI agent receives the message
2. Agent understands intent: trigger recovery
3. Agent calls `trigger_recovery("FL001", "weather delay")`
4. Tool executes `POST /adr/recover`
5. Agent formats response with results

**Response:**
```json
{
  "message": "I've initiated autonomous recovery for flight FL001 due to weather delay. Recovery plan 550e8400-e29b-41d4-a716-446655440000 has been created. Summary: 180 passengers affected, 175 successfully rebooked, 3 crew reassignments, estimated cost: $18,750."
}
```

### Example 2: Query Recovery Plan

**Request:**
```bash
curl -X POST http://localhost:9095/ai/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What is the status of recovery plan 550e8400-e29b-41d4-a716-446655440000?"
  }'
```

**What Happens:**
1. AI agent receives the message
2. Agent extracts plan ID from message
3. Agent calls `get_recovery_plan("550e8400-e29b-41d4-a716-446655440000")`
4. Tool executes `GET /adr/recovery-plans/{id}`
5. Agent formats response with plan details

**Response:**
```json
{
  "message": "Recovery plan 550e8400-e29b-41d4-a716-446655440000 is COMPLETED. Details: Flight FL001, 180 passengers affected, 175 rebooked, 3 crew reassignments, 1 gate change, total compensation: $18,750."
}
```

### Example 3: List All Plans

**Request:**
```bash
curl -X POST http://localhost:9095/ai/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Show me all recovery plans"
  }'
```

**What Happens:**
1. AI agent receives the message
2. Agent understands intent: list all plans
3. Agent calls `list_recovery_plans()`
4. Tool executes `GET /adr/recovery-plans`
5. Agent formats response with plan summaries

**Response:**
```json
{
  "message": "I found 5 recovery plans in the system: 1. Plan 550e8400... - FL001 - COMPLETED - 180 passengers, 2. Plan 660f9511... - FL002 - COMPLETED - 95 passengers, 3. Plan 770g0622... - FL003 - COMPLETED - 210 passengers, 4. Plan 880h1733... - FL004 - COMPLETED - 145 passengers, 5. Plan 990i2844... - FL005 - COMPLETED - 88 passengers."
}
```

## Benefits

### 1. Type Safety
- ✅ Tool functions are type-checked at compile time
- ✅ No runtime JSON parsing errors
- ✅ IDE autocomplete and validation

### 2. Maintainability
- ✅ Tools are regular Ballerina functions
- ✅ Easy to add new tools
- ✅ Clear separation of concerns

### 3. Integration
- ✅ Native Ballerina AI framework
- ✅ Works with any AI model provider
- ✅ Built-in session management

### 4. Simplicity
- ✅ No external dependencies (Ollama, OpenAI)
- ✅ Automatic tool discovery
- ✅ Simplified error handling

## Configuration

### Minimum Config.toml

```toml
# Database (required for orchestrator)
username = "adr_user"
password = "secure_password"
host = "localhost"
port = 3306
database = "adr_db"

# Orchestrator URL (for AI agent)
orchestratorUrl = "http://localhost:9094"

# Service URLs (for orchestrator)
disruptionServiceUrl = "http://localhost:9090"
crewServiceUrl = "http://localhost:9091"
passengerServiceUrl = "http://localhost:9092"
logisticsServiceUrl = "http://localhost:9093"
```

**Note**: No LLM-specific configuration needed! The AI framework uses the default model provider.

## Adding New Tools

To add a new tool to the AI agent:

### Step 1: Define the Tool Function

```ballerina
// Tool: Cancel a recovery plan
isolated function cancel_recovery_plan(
    string plan_id,
    string reason
) returns json|error {
    // Implementation
    json payload = {
        planId: plan_id,
        reason: reason
    };
    
    json result = check orchestratorClient->/adr/recovery\-plans/[plan_id]/cancel.post(payload);
    
    return {
        success: true,
        message: string `Recovery plan ${plan_id} cancelled: ${reason}`
    };
}
```

### Step 2: Add to Agent Tools

```ballerina
self.adrAgent = check new (
    systemPrompt = SYSTEM_PROMPT,
    model = adrAgentModel,
    tools = [
        trigger_recovery,
        get_recovery_plan,
        list_recovery_plans,
        cancel_recovery_plan  // Add new tool
    ]
);
```

### Step 3: Update System Prompt (Optional)

```ballerina
const ai:SystemPrompt SYSTEM_PROMPT = {
    role: "You are an AI assistant for an Autonomous Disruption Recovery (ADR) system for airlines.",
    instructions: string `...
4. Cancel recovery plans if needed
...
- Use cancel_recovery_plan tool to cancel an active recovery plan
...`
};
```

That's it! The AI agent will automatically discover and use the new tool.

## Session Management

The AI agent supports session management for multi-turn conversations:

```bash
# First message in session
curl -X POST http://localhost:9095/ai/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Show me all recovery plans",
    "sessionId": "user-123-session"
  }'

# Follow-up message in same session
curl -X POST http://localhost:9095/ai/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Tell me more about the first one",
    "sessionId": "user-123-session"
  }'
```

The agent maintains context across messages in the same session.

## Error Handling

The AI agent handles errors gracefully:

### Tool Execution Error
```json
{
  "message": "I encountered an error while trying to fetch the recovery plan: Recovery plan abc-123 not found. Please check the plan ID and try again."
}
```

### Invalid Request
```json
{
  "message": "I need more information to help you. Could you please specify which flight you'd like to recover?"
}
```

### Service Unavailable
```json
{
  "message": "I'm unable to connect to the orchestrator service at the moment. Please try again later or contact support."
}
```

## Testing

### Health Check
```bash
curl http://localhost:9095/ai/health
# Response: "AI Agent is running with Ballerina AI framework"
```

### Basic Chat
```bash
curl -X POST http://localhost:9095/ai/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello, what can you do?"
  }'
```

### Tool Execution
```bash
curl -X POST http://localhost:9095/ai/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "List all recovery plans"
  }'
```

## Comparison: Ollama vs Ballerina AI

| Feature | Ollama | Ballerina AI |
|---------|--------|--------------|
| **Setup** | Install Ollama + pull model | Built-in, no external deps |
| **Configuration** | Service URL + model name | Default model provider |
| **Tool Definition** | JSON schemas | Ballerina functions |
| **Type Safety** | Runtime JSON parsing | Compile-time checking |
| **Error Handling** | Manual | Automatic |
| **Integration** | HTTP client | Native framework |
| **Maintenance** | External service | Integrated |
| **Deployment** | Separate service | Single deployment |

## Summary

The Ballerina AI framework integration provides:

✅ **Native Integration** - No external LLM services required  
✅ **Type Safety** - Compile-time validation of tools  
✅ **Simplicity** - Tools are just Ballerina functions  
✅ **Maintainability** - Easy to add/modify tools  
✅ **Reliability** - Built-in error handling  
✅ **Flexibility** - Works with any AI model provider  

The ADR Orchestrator now has a production-ready AI agent that seamlessly integrates with the Ballerina ecosystem!
