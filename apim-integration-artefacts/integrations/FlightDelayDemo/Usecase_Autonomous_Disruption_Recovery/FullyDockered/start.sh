#!/bin/bash
# =============================================================================
# ADR Flight Delay Demo — Start (Fully Dockerized)
# =============================================================================
# Builds and starts all services via Docker Compose:
#   - MySQL 8.0 database
#   - WSO2 Identity Server 7.2.0 (port 9444)
#   - WSO2 API Manager 4.6.0 (port 9446/8283/8246)
#   - Ollama LLM (port 11434)
#   - Disruption Detection Service (port 9090)
#   - Crew Service (port 9091)
#   - Passenger Service (port 9092)
#   - Logistics Service (port 9093)
#   - ADR Orchestrator Service (port 9094)
#   - Admin Agent (port 9095)
#   - MCP Server (port 9096)
#   - Customer Service Agent (port 9097)
#   - ADR Dashboard (port 3000)
#
# Usage: ./start.sh
# Environment: OLLAMA_MODEL (default: qwen3:1.7b)
# =============================================================================

set -e

# ── Configurable Ollama model (override via environment variable) ──────────────
export OLLAMA_MODEL="${OLLAMA_MODEL:-qwen3:1.7b}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=============================================="
echo "  ADR Flight Delay Demo — Docker Deployment"
echo "=============================================="
echo ""

# ── Pre-flight checks ────────────────────────────────────────────────────────
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed.${NC}"
    exit 1
fi

if ! docker info &> /dev/null 2>&1; then
    echo -e "${RED}Error: Docker daemon is not running.${NC}"
    exit 1
fi

# ── Build & Start ─────────────────────────────────────────────────────────────
echo -e "${YELLOW}Building and starting all services...${NC}"
echo ""

docker compose up --build -d

echo ""
echo -e "${YELLOW}Waiting for services to become healthy...${NC}"

# Wait for all services (max ~5 minutes — APIM takes longer)
MAX_WAIT=300
ELAPSED=0
INTERVAL=10
TOTAL=11  # mysql + IS + APIM + ollama + 5 ballerina services + admin-agent + cs-agent

while [ $ELAPSED -lt $MAX_WAIT ]; do
    HEALTHY=$(docker compose ps --format json 2>/dev/null | grep -c '"healthy"' || true)

    echo "  [$ELAPSED s] Healthy: $HEALTHY / $TOTAL"

    if [ "$HEALTHY" -ge "$TOTAL" ]; then
        break
    fi

    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

echo ""

# ── Final Status ──────────────────────────────────────────────────────────────
echo "=============================================="
echo "  Service Status"
echo "=============================================="
docker compose ps
echo ""

# Check if all healthy
HEALTHY=$(docker compose ps --format json 2>/dev/null | grep -c '"healthy"' || true)
if [ "$HEALTHY" -ge "$TOTAL" ]; then
    echo -e "${GREEN}✅ All services are HEALTHY!${NC}"
    echo ""

    # ── Pull Ollama LLM model ──────────────────────────────────────
    echo -e "${YELLOW}Pulling Ollama LLM model (${OLLAMA_MODEL})...${NC}"
    echo -e "  This may take several minutes on first run (downloading model weights)."
    echo ""
    # Stream progress directly to terminal so the user sees download %
    docker exec adr-ollama ollama pull "${OLLAMA_MODEL}" 2>&1
    PULL_EXIT=$?
    echo ""
    if [ $PULL_EXIT -eq 0 ]; then
        echo -e "  ${GREEN}✅ Ollama model '${OLLAMA_MODEL}' ready.${NC}"
    else
        echo -e "  ${RED}⚠️  Ollama model pull failed (exit $PULL_EXIT). You can retry manually:${NC}"
        echo "     docker exec adr-ollama ollama pull ${OLLAMA_MODEL}"
    fi

    # ── Wait for IS REST APIs to be ready ─────────────────────────────
    echo -e "${YELLOW}Waiting for WSO2 Identity Server to be ready...${NC}"
    IS_WAIT=0
    IS_MAX_WAIT=180
    while [ $IS_WAIT -lt $IS_MAX_WAIT ]; do
        IS_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" "https://localhost:9444/scim2/Users?count=1" -u admin:admin 2>/dev/null || echo "000")
        if [ "$IS_STATUS" = "200" ]; then
            echo -e "  ${GREEN}Identity Server is ready.${NC}"
            break
        fi
        echo "  [$IS_WAIT s] IS not ready yet (HTTP $IS_STATUS)..."
        sleep 15
        IS_WAIT=$((IS_WAIT + 15))
    done

    if [ $IS_WAIT -ge $IS_MAX_WAIT ]; then
        echo -e "  ${RED}Identity Server did not become ready in time.${NC}"
    fi

    # ── Wait for APIM REST APIs to be fully ready ───────────────────────
    echo -e "${YELLOW}Waiting for WSO2 API Manager REST APIs to be fully ready...${NC}"
    APIM_WAIT=0
    APIM_MAX_WAIT=180
    while [ $APIM_WAIT -lt $APIM_MAX_WAIT ]; do
        # Check if the Publisher REST API is responding (not just the health check port)
        APIM_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" "https://localhost:9446/api/am/publisher/v4/apis?limit=1" -u admin:admin 2>/dev/null || echo "000")
        if [ "$APIM_STATUS" = "200" ]; then
            echo -e "  ${GREEN}APIM REST APIs are ready.${NC}"
            break
        fi
        echo "  [$APIM_WAIT s] APIM REST APIs not ready yet (HTTP $APIM_STATUS)..."
        sleep 15
        APIM_WAIT=$((APIM_WAIT + 15))
    done

    if [ $APIM_WAIT -ge $APIM_MAX_WAIT ]; then
        echo -e "  ${RED}APIM REST APIs did not become ready in time. You can run ./create_apis.sh manually later.${NC}"
    fi

    # ── Deploy APIs to APIM ───────────────────────────────────────────────
    echo ""
    echo -e "${YELLOW}Deploying APIs to WSO2 API Manager...${NC}"
    chmod +x "$SCRIPT_DIR/create_apis.sh"
    "$SCRIPT_DIR/create_apis.sh"

    # ── Create Customer Service MCP Servers ─────────────────────────────
    MCP_SCRIPT="$SCRIPT_DIR/create_customer_service_mcp.sh"
    if [ -f "$MCP_SCRIPT" ]; then
        echo ""
        echo -e "${YELLOW}Creating Customer Service MCP Servers...${NC}"
        chmod +x "$MCP_SCRIPT"
        bash "$MCP_SCRIPT"

        # Restart CS Agent so it discovers the newly-created MCP tools
        # (CS Agent starts before the MCPs are deployed and fails initialization)
        echo ""
        echo -e "${YELLOW}Restarting CS Agent to pick up MCP tools...${NC}"
        docker restart cs-agent > /dev/null 2>&1
        sleep 8
        CS_TOOLS=$(docker logs cs-agent 2>&1 | grep -o "[0-9]* total tools from [0-9]* server" | tail -1)
        if [ -n "$CS_TOOLS" ]; then
            echo -e "  ${GREEN}CS Agent restarted — ${CS_TOOLS}(s).${NC}"
        else
            echo -e "  ${YELLOW}CS Agent restarted — check logs if tools are not available.${NC}"
        fi
    fi

    # ── Restart Admin Agent to pick up MCP tools ──────────────────────────
    echo ""
    echo -e "${YELLOW}Restarting Admin Agent to pick up MCP tools...${NC}"
    docker restart admin-agent > /dev/null 2>&1
    sleep 8
    ADMIN_TOOLS=$(docker logs admin-agent 2>&1 | grep -o "MCP client initialized" | tail -1)
    if [ -n "$ADMIN_TOOLS" ]; then
        echo -e "  ${GREEN}Admin Agent restarted — MCP client initialized.${NC}"
    else
        echo -e "  ${YELLOW}Admin Agent restarted — check logs if MCP is not available.${NC}"
    fi

    echo ""
    echo "  Direct Service Endpoints:"
    echo "    Disruption Detection : http://localhost:9090/disruption/flights"
    echo "    Crew Service           : http://localhost:9091/crew/members"
    echo "    Passenger Service      : http://localhost:9092/passenger/bookings/FL001"
    echo "    Logistics Service      : http://localhost:9093/logistics/resources/LHR"
    echo "    ADR Orchestrator     : http://localhost:9094/adr/recovery-plans"
    echo "    Admin Agent          : http://localhost:9095/ai/health"
    echo "    MCP Server           : http://localhost:9096/mcp"
    echo "    CS Agent             : http://localhost:9097/cs/health"
    echo ""
    echo "  APIM Console:"
    echo "    Publisher            : https://localhost:9446/publisher"
    echo "    DevPortal            : https://localhost:9446/devportal"
    echo "    Admin                : https://localhost:9446/admin"
    echo ""
    echo "  IS Console:"
    echo "    Identity Server      : https://localhost:9444/console"
    echo ""
    echo "  ADR Dashboard:"
    echo "    http://localhost:3000"
    echo ""
    echo "  Trigger a recovery (via APIM Gateway):"
    echo '    # First get a token from APIM DevPortal, then:'
    echo '    curl -s -X POST http://localhost:8283/adr/1.0.0/recover \'
    echo '      -H "Content-Type: application/json" \'
    echo '      -H "Authorization: Bearer <ACCESS_TOKEN>" \'
    echo '      -d '\''{"flightId":"FL001","disruptionType":"DELAY","severity":"HIGH"}'\'' | jq'
    echo ""
    echo "  Trigger a recovery (direct):"
    echo '    curl -s -X POST http://localhost:9094/adr/recover \'
    echo '      -H "Content-Type: application/json" \'
    echo '      -d '\''{"flightId":"FL001","disruptionType":"DELAY","severity":"HIGH"}'\'' | jq'
    echo ""
    echo "  Stop all services:"
    echo "    ./stop.sh"
else
    echo -e "${RED}⚠️  Some services may not be healthy yet. Check logs:${NC}"
    echo "    docker compose logs -f"
fi
