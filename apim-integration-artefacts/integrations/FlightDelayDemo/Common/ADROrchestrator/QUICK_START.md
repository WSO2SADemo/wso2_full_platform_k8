# Quick Start: AI Agent for ADR Orchestrator

## Setup (5 minutes)

### 1. Install and Start Ollama
1. Install Ollama from https://ollama.ai
2. Pull a model: `ollama pull llama3.2`
3. Verify it's running: `ollama list`
4. Ollama runs on http://localhost:11434 by default

### 2. Configure the AI Agent
Add to your `Config.toml`:

```toml
# Database Configuration (required for orchestrator)
username = "your-db-username"
password = "your-db-password"
host = "localhost"
port = 3306
database = "adr_db"

# Ollama Configuration (required for AI agent)
ollamaServiceUrl = "http://localhost:11434"
ollamaModel = "llama3.2"

# Service URLs (defaults shown)
orchestratorUrl = "http://localhost:9094"
disruptionServiceUrl = "http://localhost:9090"
crewServiceUrl = "http://localhost:9091"
passengerServiceUrl = "http://localhost:9092"
logisticsServiceUrl = "http://localhost:9093"
```

### 3. Start the Services

```bash
# Terminal 1: Start the orchestrator (if not already running)
bal run

# The AI Agent will start automatically on port 9095
```

## Try It Out (2 minutes)

### Example 1: Trigger Recovery
```bash
curl -X POST http://localhost:9095/ai/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Flight FL001 is delayed due to weather, please start recovery"
  }'
```

**Expected Response:**
```json
{
  "response": "I've initiated autonomous recovery for flight FL001 due to weather delay. Recovery plan [UUID] has been created. The system affected 150 passengers, successfully rebooked 145, and made 2 crew reassignments. Estimated cost: $12,500.",
  "function_called": "trigger_recovery",
  "function_result": {
    "success": true,
    "plan_id": "550e8400-e29b-41d4-a716-446655440000",
    "flight_id": "FL001",
    "status": "COMPLETED",
    "passengers_affected": 150,
    "passengers_rebooked": 145,
    "crew_reassignments": 2,
    "estimated_cost": 12500.00
  }
}
```

### Example 2: Check Status
```bash
curl -X POST http://localhost:9095/ai/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Show me all recovery plans"
  }'
```

### Example 3: Natural Variations
The AI understands many ways to ask the same thing:

```bash
# All of these work:
"Start recovery for FL001 - mechanical issue"
"FL001 has a delay, can you handle it?"
"Initiate disruption recovery for flight FL001"
"We need to recover FL001 due to crew shortage"
```

## What Can You Ask?

### Trigger Recovery
- "Flight FL001 is delayed due to weather, start recovery"
- "Handle disruption for FL002 - mechanical issue"
- "Initiate recovery for FL003"

### Query Status
- "Show me recovery plan abc-123"
- "What's the status of plan xyz-456?"
- "Get details for recovery abc-123"

### List Plans
- "Show me all recovery plans"
- "List recent recovery operations"
- "What recoveries have been executed?"

### General Questions
- "How does the recovery system work?"
- "What happens when a flight is delayed?"
- "Explain the recovery process"

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     User (Operations Staff)                  │
└────────────────────────┬────────────────────────────────────┘
                         │ Natural Language
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    AI Agent (Port 9095)                      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ OpenAI GPT-4o-mini                                   │   │
│  │ - Understands intent                                 │   │
│  │ - Calls appropriate functions                        │   │
│  │ - Formats responses                                  │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────────┘
                         │ API Calls
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              ADR Orchestrator (Port 9094)                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ POST /adr/recover                                    │   │
│  │ GET  /adr/recovery-plans                             │   │
│  │ GET  /adr/recovery-plans/{id}                        │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┬──────────────┐
         ▼               ▼               ▼              ▼
    ┌─────────┐    ┌─────────┐    ┌──────────┐   ┌──────────┐
    │Disruption│    │  Crew   │    │Passenger │   │Logistics │
    │  Agent  │    │  Agent  │    │  Agent   │   │  Agent   │
    └─────────┘    └─────────┘    └──────────┘   └──────────┘
```

## How It Works

### 1. Natural Language Understanding
The AI Agent uses OpenAI's GPT models to understand user intent:
- "Flight FL001 is delayed" → Extract flight ID and disruption type
- "Show me recovery plans" → List all plans
- "What's the status of plan abc-123?" → Get specific plan

### 2. Function Calling
OpenAI's function calling feature maps intent to actions:
```
User: "Start recovery for FL001"
  ↓
AI: Calls trigger_recovery(flight_id="FL001", disruption_type="delay")
  ↓
Agent: Executes POST /adr/recover
  ↓
AI: Formats response in natural language
```

### 3. Context-Aware Responses
The AI provides human-friendly summaries:
```json
{
  "response": "Recovery complete! 145 passengers rebooked, 2 crew reassignments, estimated cost $12,500."
}
```

## Benefits

### For Operations Staff
✅ **No technical knowledge required** - just ask in plain English  
✅ **Faster operations** - no need to remember API endpoints  
✅ **Natural interaction** - like talking to a colleague  
✅ **Flexible phrasing** - AI understands variations  

### For the System
✅ **Audit trail** - all interactions logged  
✅ **Safe** - AI can only call predefined functions  
✅ **Extensible** - easy to add new capabilities  
✅ **Intelligent** - learns from context  

## Cost Estimation

Ollama runs locally - **completely free!**
- ✅ No API costs
- ✅ No usage limits
- ✅ Complete data privacy
- ✅ Works offline

**Hardware Requirements:**
- **llama3.2** (3B): 4GB RAM, runs on CPU
- **llama3.2** (1B): 2GB RAM, very fast
- **llama3.1** (8B): 8GB RAM, better accuracy
- **llama3.1** (70B): 48GB RAM, best quality

## Troubleshooting

### "No response from AI"
**Problem**: AI Agent can't reach Ollama  
**Solution**: 
- Check Ollama is running: `ollama list`
- Verify Ollama service URL: http://localhost:11434
- Check model is pulled: `ollama pull llama3.2`
- Restart Ollama if needed

### "Failed to fetch recovery plan"
**Problem**: Can't connect to orchestrator  
**Solution**:
- Ensure orchestrator is running on port 9094
- Check `orchestratorUrl` in Config.toml
- Verify network connectivity

### "Unknown function"
**Problem**: AI tried to call a function that doesn't exist  
**Solution**:
- This is rare (AI hallucination)
- Try rephrasing your question
- Report to development team

## Next Steps

### 1. Explore Advanced Features
See `AI_AGENT_GUIDE.md` for:
- Predictive disruption analysis
- Sentiment analysis
- Multi-agent negotiation
- Cost optimization

### 2. Extend the AI Agent
See `ai_extensions_example.bal` for:
- Adding new capabilities
- Custom function definitions
- Integration patterns

### 3. Production Deployment
Consider:
- Add authentication/authorization
- Implement rate limiting
- Set up monitoring and logging
- Configure backup OpenAI keys

## Example Conversation Flow

```
User: "We have a major delay on FL001 due to mechanical issues"

AI Agent: "I've initiated autonomous recovery for flight FL001 due to 
mechanical issue. Recovery plan 550e8400-e29b-41d4-a716-446655440000 
has been created.

Summary:
- 180 passengers affected
- 175 successfully rebooked to alternative flights
- 5 passengers compensated (no available seats)
- 3 crew members reassigned due to duty hour limits
- 1 gate change coordinated
- Estimated cost: $18,750

The recovery completed in 3.2 seconds. All passengers have been notified."

User: "What's the status of that plan?"

AI Agent: "Recovery plan 550e8400-e29b-41d4-a716-446655440000 is COMPLETED.

Details:
- Flight: FL001
- Disruption: Mechanical issue, 120 minute delay
- Passengers: 180 affected, 175 rebooked
- Crew: 3 reassignments
- Logistics: 1 gate change
- Total compensation: $18,750
- Status: All recovery actions completed successfully"

User: "Show me all recovery operations"

AI Agent: "I found 5 recovery plans in the system:

1. Plan 550e8400... - FL001 - COMPLETED - 180 passengers
2. Plan 660f9511... - FL002 - COMPLETED - 95 passengers
3. Plan 770g0622... - FL003 - COMPLETED - 210 passengers
4. Plan 880h1733... - FL004 - COMPLETED - 145 passengers
5. Plan 990i2844... - FL005 - COMPLETED - 88 passengers

All recovery operations completed successfully."
```

## Summary

The AI Agent transforms your ADR Orchestrator from a technical API into a conversational assistant. Operations staff can now manage complex recovery operations using natural language, making the system more accessible and efficient.

**Ready to try it?** Just install Ollama, pull a model, and start asking questions - completely free and private!
