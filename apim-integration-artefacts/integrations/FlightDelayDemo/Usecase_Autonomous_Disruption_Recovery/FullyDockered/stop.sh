#!/bin/bash
# =============================================================================
# ADR Flight Delay Demo — Stop All Services
# =============================================================================
# Usage: ./stop.sh          — stop and remove containers (keep data)
#        ./stop.sh --clean  — stop, remove containers AND volumes (fresh start)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$1" = "--clean" ]; then
    echo -e "${YELLOW}Stopping and removing all containers + volumes...${NC}"
    docker compose down -v
    echo -e "${GREEN}✅ All services stopped. Database volumes removed (clean slate).${NC}"
else
    echo -e "${YELLOW}Stopping and removing all containers...${NC}"
    docker compose down
    echo -e "${GREEN}✅ All services stopped. Database volume preserved.${NC}"
    echo "   Use './stop.sh --clean' to also remove the database volume."
fi
