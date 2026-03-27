# AI Agent for ADR Orchestrator

## Overview

The AI Agent provides a **natural language interface** to your Autonomous Disruption Recovery (ADR) Orchestrator. Operations staff can now interact with the system using plain English instead of making direct API calls.

## What It Does

The AI Agent uses OpenAI's GPT models to:
1. **Understand natural language queries** about flight disruptions and recovery operations
2. **Translate user intent** into appropriate API calls to the orchestrator
3. **Execute recovery operations** autonomously based on conversational requests
4. **Provide human-friendly summaries** of complex recovery data

## Architecture

```
User Query (Natural Language)
    ↓
AI Agent (Port 9095)
    ↓ [OpenAI GPT Function Calling]
    ↓
ADR Orchestrator (Port 9094)
    ↓
[Disruption, Crew, Passenger, Logistics Agents]
```

## Configuration

Add these to your `Config.toml`:

```toml
# Ollama Configuration
ollamaServiceUrl = "http://localhost:11434"
ollamaModel = "llama3.2"  # or "llama3.1:8b" for better reasoning

# Orchestrator URL (if different from default)
orchestratorUrl = "http://localhost:9094"
```

**Available Models:**
- `llama3.2` (3B) - Fast, good for most tasks
- `llama3.2:1b` - Very fast, lighter reasoning
- `llama3.1:8b` - Better accuracy, slower
- `llama3.1:70b` - Best quality, requires 48GB RAM

## Available Capabilities

### 1. Trigger Recovery Operations
**Natural Language Examples:**
- "Flight FL001 is delayed due to weather, start recovery"
- "Initiate recovery for FL002 - mechanical issue"
- "Handle disruption for flight FL003"

**What it does:**
- Calls `/adr/recover` endpoint
- Initiates full autonomous recovery (crew, passengers, logistics)
- Returns recovery plan summary

### 2. Query Recovery Plans
**Natural Language Examples:**
- "Show me recovery plan abc-123-def"
- "What's the status of plan xyz-456?"
- "Get details for recovery abc-123"

**What it does:**
- Calls `/adr/recovery-plans/{id}` endpoint
- Returns detailed plan information
- Shows negotiation log and outcomes

### 3. List All Recovery Plans
**Natural Language Examples:**
- "Show me all recovery plans"
- "List recent recovery operations"
- "What recoveries have been executed?"

**What it does:**
- Calls `/adr/recovery-plans` endpoint
- Returns list of all plans with summaries

## API Endpoints

### POST /ai/chat
Send natural language queries to the AI agent.

**Request:**
```json
{
  "message": "Flight FL001 is delayed due to weather, start recovery"
}
```

**Response:**
```json
{
  "response": "I've initiated autonomous recovery for flight FL001 due to weather delay. Recovery plan abc-123 has been created. The system affected 150 passengers, successfully rebooked 145, and made 2 crew reassignments. Estimated cost: $12,500.",
  "function_called": "trigger_recovery",
  "function_result": {
    "success": true,
    "plan_id": "abc-123",
    "flight_id": "FL001",
    "status": "COMPLETED",
    "passengers_affected": 150,
    "passengers_rebooked": 145,
    "crew_reassignments": 2,
    "estimated_cost": 12500.00,
    "message": "Recovery plan abc-123 executed in 2.5s..."
  }
}
```

### GET /ai/health
Health check endpoint.

**Response:** `"AI Agent is running"`

## Example Conversations

### Example 1: Triggering Recovery
```
User: "We have a major delay on FL001 due to a mechanical issue. Can you handle it?"

AI Agent: "I've initiated autonomous recovery for flight FL001 due to mechanical issue. 
Recovery plan 550e8400-e29b-41d4-a716-446655440000 has been created. 

Summary:
- 180 passengers affected
- 175 successfully rebooked to alternative flights
- 5 passengers compensated (no available seats)
- 3 crew members reassigned due to duty hour limits
- 1 gate change coordinated
- Estimated cost: $18,750

The recovery completed in 3.2 seconds. All passengers have been notified."
```

### Example 2: Querying Status
```
User: "What's the status of recovery plan 550e8400-e29b-41d4-a716-446655440000?"

AI Agent: "Recovery plan 550e8400-e29b-41d4-a716-446655440000 is COMPLETED.

Details:
- Flight: FL001
- Disruption: Mechanical issue, 120 minute delay
- Passengers: 180 affected, 175 rebooked
- Crew: 3 reassignments
- Logistics: 1 gate change
- Total compensation: $18,750
- Status: All recovery actions completed successfully"
```

### Example 3: Listing Plans
```
User: "Show me all recovery operations from today"

AI Agent: "I found 5 recovery plans in the system:

1. Plan 550e8400... - FL001 - COMPLETED - 180 passengers
2. Plan 660f9511... - FL002 - COMPLETED - 95 passengers
3. Plan 770g0622... - FL003 - COMPLETED - 210 passengers
4. Plan 880h1733... - FL004 - COMPLETED - 145 passengers
5. Plan 990i2844... - FL005 - COMPLETED - 88 passengers

All recovery operations completed successfully."
```

## How It Works: Function Calling

The AI Agent uses Ollama's **Function Calling** feature:

1. **System Prompt**: Defines the AI's role and capabilities
2. **Tool Definitions**: Describes available functions (trigger_recovery, get_recovery_plan, list_recovery_plans)
3. **Intent Recognition**: Ollama LLM analyzes user message and decides which function to call
4. **Execution**: Agent calls the orchestrator API
5. **Response Generation**: Ollama formats the result in natural language

## Benefits

### For Operations Staff
- ✅ **No API knowledge required** - just ask in plain English
- ✅ **Faster response** - no need to navigate multiple endpoints
- ✅ **Context-aware** - AI understands variations in phrasing
- ✅ **Conversational** - feels like talking to a colleague

### For the System
- ✅ **Audit trail** - all AI interactions logged
- ✅ **Extensible** - easy to add new capabilities
- ✅ **Safe** - AI can only call predefined functions
- ✅ **Intelligent** - learns from conversation context

## Future Enhancements

### 1. Predictive Disruption Agent
```ballerina
// Analyze patterns and predict disruptions before they happen
function predictDisruptions() returns Prediction[] {
    // ML model analyzing:
    // - Historical delay patterns
    // - Weather forecasts
    // - Aircraft maintenance schedules
    // - Crew availability trends
}
```

### 2. Sentiment Analysis Agent
```ballerina
// Analyze passenger communications and predict escalation risk
function analyzePassengerSentiment(string passengerId) returns SentimentScore {
    // NLP analysis of:
    // - Email responses
    // - Social media mentions
    // - Call center transcripts
}
```

### 3. Cost Optimization Agent
```ballerina
// Learn optimal compensation and rebooking strategies
function optimizeRecoveryCost(RecoveryScenario scenario) returns OptimizedPlan {
    // Reinforcement learning to minimize:
    // - Direct costs (compensation, rebooking)
    // - Indirect costs (reputation, future bookings)
    // - While maximizing customer satisfaction
}
```

### 4. Multi-Agent Collaboration
```ballerina
// Multiple AI agents negotiate optimal recovery strategy
function negotiateRecovery(DisruptionEvent event) returns ConsensusRecoveryPlan {
    // Agents debate:
    // - Cost Agent: minimize expenses
    // - Satisfaction Agent: maximize customer happiness
    // - Compliance Agent: ensure regulatory adherence
    // - Efficiency Agent: optimize resource utilization
}
```

### 5. Voice Interface
```ballerina
// Voice-activated recovery operations
service /ai/voice on voiceListener {
    resource function post command(audio:Stream audioStream) returns VoiceResponse {
        // Speech-to-text → AI Agent → Text-to-speech
    }
}
```

## Testing the AI Agent

### Using cURL
```bash
# Trigger recovery
curl -X POST http://localhost:9095/ai/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Flight FL001 is delayed due to weather, start recovery"}'

# Query status
curl -X POST http://localhost:9095/ai/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Show me recovery plan abc-123"}'

# List plans
curl -X POST http://localhost:9095/ai/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "List all recovery operations"}'
```

### Using Postman
1. Create POST request to `http://localhost:9095/ai/chat`
2. Set header: `Content-Type: application/json`
3. Body (raw JSON):
```json
{
  "message": "Your natural language query here"
}
```

## Security Considerations

1. **API Key Protection**: Store OpenAI API key securely in Config.toml (never commit)
2. **Rate Limiting**: Consider adding rate limits to prevent abuse
3. **Authentication**: Add auth middleware for production use
4. **Input Validation**: AI validates function parameters before execution
5. **Audit Logging**: All AI actions are logged for compliance

## Cost Management

OpenAI API costs depend on:
- **Model**: gpt-4o-mini is cheaper, gpt-4o is more capable
- **Token usage**: Longer conversations = higher cost
- **Function calls**: Each call uses tokens

**Estimated costs** (as of 2024):
- gpt-4o-mini: ~$0.01 per recovery operation
- gpt-4o: ~$0.05 per recovery operation

## Troubleshooting

### "No response from AI"
- Check OpenAI API key is valid
- Verify internet connectivity
- Check OpenAI service status

### "Failed to fetch recovery plan"
- Ensure orchestrator is running on port 9094
- Verify plan ID exists
- Check orchestrator logs

### "Unknown function"
- This shouldn't happen - indicates AI hallucination
- Report to development team
- Check OpenAI model version

## Summary

The AI Agent transforms your ADR Orchestrator from a **technical API** into a **conversational assistant**. Operations staff can now manage complex recovery operations using natural language, making the system more accessible and efficient.

**Next Steps:**
1. Configure OpenAI API key
2. Start the AI Agent service
3. Try example queries
4. Explore additional AI capabilities based on your needs
