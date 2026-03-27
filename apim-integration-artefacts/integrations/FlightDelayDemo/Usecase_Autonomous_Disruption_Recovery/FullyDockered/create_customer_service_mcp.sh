#!/bin/bash
# =============================================================================
# Usecase 2: Customer Service Agent Copilot — MCP from Existing APIs
# =============================================================================
# Creates TWO MCP Servers by composing tools from EXISTING published REST APIs
# using WSO2 APIM 4.6.0's `generate-from-api` endpoint.
#
# Why two MCP servers?  APIM's generate-from-api only registers ONE source
# REST API per MCP server.  Operations referencing a different API get their
# apiOperationMapping silently stripped on PUT.  So we create:
#
#   CustomerServiceDisruptionMCP  — 4 tools  from DisruptionDetectionAPI
#   CustomerServicePassengerMCP   — 10 tools from PassengerServiceAPI
#
# The CS Agent connects to both and merges the tool lists at runtime.
#
# Unlike Usecase 1 (generate-from-mcp-server which proxies a dedicated MCP
# backend), this approach converts REST API endpoints directly into MCP tools
# — no separate MCP server process needed.
#
# Pre-requisites:
#   - Usecase 1 must be fully deployed (APIM + all REST APIs published)
#   - Both source APIs must be in PUBLISHED lifecycle state
#
# Usage: ./create_customer_service_mcp.sh
# =============================================================================

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

APIM_HOST="https://localhost:9446"
MCP_PUBLISHER_URL="${APIM_HOST}/api/am/publisher/v4/mcp-servers"
DEVPORTAL_URL="${APIM_HOST}/api/am/devportal/v3"

echo ""
echo "============================================================"
echo "= CUSTOMER SERVICE AGENT COPILOT"
echo "= MCP Servers from Existing APIs (generate-from-api)"
echo "============================================================"
echo ""

# ── Verify APIM is accessible ────────────────────────────────────────────────
printf "= Checking APIM accessibility..."
HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "${APIM_HOST}/api/am/publisher/v4/apis?limit=1" -u admin:admin 2>/dev/null || echo "000")
if [ "$HTTP_CODE" != "200" ]; then
    echo -e " ${RED}Failed (HTTP $HTTP_CODE).${NC}"
    echo "  APIM must be running. Deploy Usecase 1 first."
    exit 1
fi
echo -e " ${GREEN}OK${NC}"

# ── Discover source APIs by name ─────────────────────────────────────────────
echo ""
echo "= Discovering source APIs from Usecase 1..."

printf "  - Looking up DisruptionDetectionAPI..."
DISRUPTION_API_ID=$(curl -sk "${APIM_HOST}/api/am/publisher/v4/apis?query=name:DisruptionDetectionAPI" -u admin:admin \
    | python3 -c "import sys,json; apis=json.load(sys.stdin).get('list',[]); print(apis[0]['id'] if apis else '')" 2>/dev/null || echo "")
if [ -z "$DISRUPTION_API_ID" ]; then
    echo -e " ${RED}Not found.${NC} Deploy Usecase 1 first."
    exit 1
fi
echo -e " ${GREEN}Found${NC} (ID: $DISRUPTION_API_ID)"

printf "  - Looking up PassengerServiceAPI..."
PASSENGER_API_ID=$(curl -sk "${APIM_HOST}/api/am/publisher/v4/apis?query=name:PassengerServiceAPI" -u admin:admin \
    | python3 -c "import sys,json; apis=json.load(sys.stdin).get('list',[]); print(apis[0]['id'] if apis else '')" 2>/dev/null || echo "")
if [ -z "$PASSENGER_API_ID" ]; then
    echo -e " ${RED}Not found.${NC} Deploy Usecase 1 first."
    exit 1
fi
echo -e " ${GREEN}Found${NC} (ID: $PASSENGER_API_ID)"


# ══════════════════════════════════════════════════════════════════════════════
# HELPER: Create, revise, deploy, and publish a single MCP server
# ══════════════════════════════════════════════════════════════════════════════
# Usage: create_mcp_server <name> <context> <version> <payload_file>
# Returns: MCP server ID in $MCP_RESULT_ID
MCP_RESULT_ID=""

create_mcp_server() {
    local MCP_NAME="$1"
    local MCP_CONTEXT="$2"
    local MCP_VERSION="$3"
    local PAYLOAD_FILE="$4"

    echo ""
    echo "------------------------------------------------------------"
    echo "= Creating ${MCP_NAME} (${MCP_CONTEXT}/${MCP_VERSION})"
    echo "------------------------------------------------------------"

    # Check if MCP server already exists
    local EXISTING_ID=$(curl -sk "${MCP_PUBLISHER_URL}?query=name:${MCP_NAME}" -u admin:admin \
        | python3 -c "import sys,json; s=json.load(sys.stdin).get('list',[]); print(s[0]['id'] if s else '')" 2>/dev/null || echo "")

    if [ -n "$EXISTING_ID" ]; then
        # Verify it has the right number of ops and is published
        local EXISTING_STATE=$(curl -sk "${MCP_PUBLISHER_URL}/${EXISTING_ID}" -u admin:admin \
            | python3 -c "
import sys,json
d=json.load(sys.stdin)
ops=d.get('operations',[])
mapped=sum(1 for o in ops if o.get('apiOperationMapping'))
state=d.get('lifeCycleStatus','?')
print(f'{state},{len(ops)},{mapped}')
" 2>/dev/null || echo "?,0,0")
        local STATE=$(echo "$EXISTING_STATE" | cut -d, -f1)
        local OPS=$(echo "$EXISTING_STATE" | cut -d, -f2)
        local MAPPED=$(echo "$EXISTING_STATE" | cut -d, -f3)

        local EXPECTED_OPS=$(python3 -c "import json; print(len(json.load(open('$PAYLOAD_FILE')).get('operations',[])))" 2>/dev/null || echo "0")

        if [ "$STATE" = "PUBLISHED" ] && [ "$MAPPED" = "$EXPECTED_OPS" ]; then
            echo -e "  ${YELLOW}Already exists${NC} (ID: $EXISTING_ID, $OPS ops, $MAPPED mapped, $STATE)"
            MCP_RESULT_ID="$EXISTING_ID"
            return 0
        else
            echo -e "  ${YELLOW}Exists but incomplete${NC} ($OPS ops, $MAPPED mapped, state=$STATE). Deleting..."
            # Delete subscriptions first
            curl -sk "${DEVPORTAL_URL}/subscriptions?apiId=${EXISTING_ID}" -u admin:admin \
                | python3 -c "import sys,json; [print(s['subscriptionId']) for s in json.load(sys.stdin).get('list',[])]" 2>/dev/null \
                | while read SUB_ID; do
                    curl -sk -X DELETE "${DEVPORTAL_URL}/subscriptions/${SUB_ID}" -u admin:admin > /dev/null 2>&1
                done
            curl -sk -X DELETE "${MCP_PUBLISHER_URL}/${EXISTING_ID}" -u admin:admin > /dev/null 2>&1
            echo -e "    ${GREEN}Deleted.${NC} Recreating..."
        fi
    fi

    # Step 1: Create via generate-from-api
    printf "  - Creating via generate-from-api..."
    local CREATE_RESP=$(curl -sk -X POST "${MCP_PUBLISHER_URL}/generate-from-api" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d @"$PAYLOAD_FILE")

    local NEW_ID=$(echo "$CREATE_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
    if [ -z "$NEW_ID" ]; then
        echo -e " ${RED}Failed.${NC}"
        echo "  DEBUG: ${CREATE_RESP:0:300}"
        return 1
    fi
    local OPS_CREATED=$(echo "$CREATE_RESP" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('operations',[])))" 2>/dev/null || echo "0")
    echo -e " ${GREEN}Created${NC} (ID: $NEW_ID, $OPS_CREATED ops)"

    # Step 2: If generate-from-api only created a subset, PUT the full set
    local EXPECTED_OPS=$(python3 -c "import json; print(len(json.load(open('$PAYLOAD_FILE')).get('operations',[])))" 2>/dev/null || echo "0")
    if [ "$OPS_CREATED" -lt "$EXPECTED_OPS" ] 2>/dev/null; then
        printf "  - Injecting all $EXPECTED_OPS operations via PUT..."
        local CURRENT_DATA_FILE="/tmp/mcp_current_$$.json"
        curl -sk "${MCP_PUBLISHER_URL}/${NEW_ID}" -u admin:admin > "$CURRENT_DATA_FILE"
        local UPDATE_FILE="/tmp/mcp_update_$$.json"
        python3 -c "
import json
with open('$CURRENT_DATA_FILE') as f:
    current = json.load(f)
with open('$PAYLOAD_FILE') as f:
    payload = json.load(f)
current['operations'] = payload['operations']
current['policies'] = ['Unlimited']
with open('$UPDATE_FILE', 'w') as f:
    json.dump(current, f)
" 2>/dev/null
        local PUT_RESP=$(curl -sk -X PUT "${MCP_PUBLISHER_URL}/${NEW_ID}" \
            -u admin:admin \
            -H "Content-Type: application/json" \
            -d @"$UPDATE_FILE")
        rm -f "$UPDATE_FILE" "$CURRENT_DATA_FILE"
        local PUT_OPS=$(echo "$PUT_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); mapped=sum(1 for o in d.get('operations',[]) if o.get('apiOperationMapping')); print(f\"{len(d.get('operations',[]))} ops, {mapped} mapped\")" 2>/dev/null || echo "check failed")
        echo -e " ${GREEN}Done${NC} ($PUT_OPS)"
    fi

    # Step 3: Verify mappings
    printf "  - Verifying operation mappings..."
    local VERIFY=$(curl -sk "${MCP_PUBLISHER_URL}/${NEW_ID}" -u admin:admin \
        | python3 -c "
import sys, json
d = json.load(sys.stdin)
ops = d.get('operations', [])
mapped = sum(1 for o in ops if o.get('apiOperationMapping'))
print(f'{mapped}/{len(ops)} mapped')
" 2>/dev/null || echo "unknown")
    echo -e " ${GREEN}${VERIFY}${NC}"

    # Step 4: Create revision
    printf "  - Creating revision..."
    local REV_RESP=$(curl -sk -X POST "${MCP_PUBLISHER_URL}/${NEW_ID}/revisions" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d '{"description":"Automated deployment"}')
    local REV_ID=$(echo "$REV_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
    if [ -z "$REV_ID" ]; then
        echo -e " ${RED}Failed.${NC}"
        echo "  DEBUG: $REV_RESP"
        MCP_RESULT_ID="$NEW_ID"
        return 1
    fi
    echo -e " ${GREEN}Done${NC} (Revision: $REV_ID)"

    # Step 5: Deploy to gateway
    printf "  - Deploying to gateway..."
    curl -sk -X POST "${MCP_PUBLISHER_URL}/${NEW_ID}/deploy-revision?revisionId=${REV_ID}" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d '[{"name":"Default","vhost":"localhost"}]' > /dev/null 2>&1
    echo -e " ${GREEN}Done.${NC}"

    # Step 6: Publish
    printf "  - Publishing..."
    curl -sk -X POST "${MCP_PUBLISHER_URL}/change-lifecycle?action=Publish&mcpServerId=${NEW_ID}" \
        -u admin:admin > /dev/null 2>&1
    echo -e " ${GREEN}Done.${NC}"

    MCP_RESULT_ID="$NEW_ID"
}


# ══════════════════════════════════════════════════════════════════════════════
# BUILD PAYLOADS AND CREATE BOTH MCP SERVERS
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "============================================================"
echo "= CREATING MCP SERVERS"
echo "============================================================"

# ── Build DisruptionMCP payload (4 tools) ─────────────────────────────────────
DISRUPTION_PAYLOAD="/tmp/cs_disruption_mcp_payload_$$.json"
python3 -c "
import json

api_id = '$DISRUPTION_API_ID'

operations = [
    {
        'target': 'getFlights',
        'feature': 'TOOL',
        'authType': 'Any',
        'throttlingPolicy': 'Unlimited',
        'scopes': [],
        'description': 'List all flights with status, schedule, and gate information. Use this to get an overview of current flights when a customer asks about their flight.',
        'apiOperationMapping': {
            'apiId': api_id,
            'apiName': 'DisruptionDetectionAPI',
            'apiVersion': '1.0.0',
            'apiContext': '/disruption',
            'backendOperation': {'target': '/flights', 'verb': 'GET'}
        }
    },
    {
        'target': 'getFlightById',
        'feature': 'TOOL',
        'authType': 'Any',
        'throttlingPolicy': 'Unlimited',
        'scopes': [],
        'description': 'Get detailed information about a specific flight by its ID (e.g., FL001). Returns schedule, gate, status, and passenger count.',
        'apiOperationMapping': {
            'apiId': api_id,
            'apiName': 'DisruptionDetectionAPI',
            'apiVersion': '1.0.0',
            'apiContext': '/disruption',
            'backendOperation': {'target': '/flights/{id}', 'verb': 'GET'}
        }
    },
    {
        'target': 'getFlightSeats',
        'feature': 'TOOL',
        'authType': 'Any',
        'throttlingPolicy': 'Unlimited',
        'scopes': [],
        'description': 'Check seat availability and capacity for a specific flight. Useful to verify available seats before rebooking.',
        'apiOperationMapping': {
            'apiId': api_id,
            'apiName': 'DisruptionDetectionAPI',
            'apiVersion': '1.0.0',
            'apiContext': '/disruption',
            'backendOperation': {'target': '/flights/{id}/seats', 'verb': 'GET'}
        }
    },
    {
        'target': 'getActiveDisruptions',
        'feature': 'TOOL',
        'authType': 'Any',
        'throttlingPolicy': 'Unlimited',
        'scopes': [],
        'description': 'Get all active flight disruptions including delays, cancellations, and their severity. Essential for understanding why a customer\\'s flight is affected.',
        'apiOperationMapping': {
            'apiId': api_id,
            'apiName': 'DisruptionDetectionAPI',
            'apiVersion': '1.0.0',
            'apiContext': '/disruption',
            'backendOperation': {'target': '/delays', 'verb': 'GET'}
        }
    }
]

payload = {
    'name': 'CustomerServiceDisruptionMCP',
    'context': '/cs-disruption-mcp',
    'version': '1.0.0',
    'policies': ['Unlimited'],
    'operations': operations
}
with open('$DISRUPTION_PAYLOAD', 'w') as f:
    json.dump(payload, f)
print('  DisruptionMCP payload: 4 tools')
"

# ── Build PassengerMCP payload (10 tools) ─────────────────────────────────────
PASSENGER_PAYLOAD="/tmp/cs_passenger_mcp_payload_$$.json"
python3 -c "
import json

api_id = '$PASSENGER_API_ID'

operations = [
    {
        'target': 'getBookingsByFlight',
        'feature': 'TOOL',
        'authType': 'Any',
        'throttlingPolicy': 'Unlimited',
        'scopes': [],
        'description': 'Get all passenger bookings for a specific flight. Returns booking details, seat assignments, and class information.',
        'apiOperationMapping': {
            'apiId': api_id,
            'apiName': 'PassengerServiceAPI',
            'apiVersion': '1.0.0',
            'apiContext': '/passenger',
            'backendOperation': {'target': '/bookings/{flightId}', 'verb': 'GET'}
        }
    },
    {
        'target': 'getAllBookings',
        'feature': 'TOOL',
        'authType': 'Any',
        'throttlingPolicy': 'Unlimited',
        'scopes': [],
        'description': 'Retrieve all bookings across all flights. Returns comprehensive list of passenger reservations.',
        'apiOperationMapping': {
            'apiId': api_id,
            'apiName': 'PassengerServiceAPI',
            'apiVersion': '1.0.0',
            'apiContext': '/passenger',
            'backendOperation': {'target': '/all-bookings', 'verb': 'GET'}
        }
    },
    {
        'target': 'getPassengerById',
        'feature': 'TOOL',
        'authType': 'Any',
        'throttlingPolicy': 'Unlimited',
        'scopes': [],
        'description': 'Get detailed profile information for a specific passenger by their ID (e.g., PAX001). Returns name, loyalty tier, contact info, and preferences.',
        'apiOperationMapping': {
            'apiId': api_id,
            'apiName': 'PassengerServiceAPI',
            'apiVersion': '1.0.0',
            'apiContext': '/passenger',
            'backendOperation': {'target': '/{id}', 'verb': 'GET'}
        }
    },
    {
        'target': 'getPassengerHistory',
        'feature': 'TOOL',
        'authType': 'Any',
        'throttlingPolicy': 'Unlimited',
        'scopes': [],
        'description': 'Get the flight history for a passenger. Shows past flights, delays encountered, and rebooking history.',
        'apiOperationMapping': {
            'apiId': api_id,
            'apiName': 'PassengerServiceAPI',
            'apiVersion': '1.0.0',
            'apiContext': '/passenger',
            'backendOperation': {'target': '/history/{passengerId}', 'verb': 'GET'}
        }
    },
    {
        'target': 'getAlternativeFlights',
        'feature': 'TOOL',
        'authType': 'Any',
        'throttlingPolicy': 'Unlimited',
        'scopes': [],
        'description': 'Find alternative flights for rebooking from a disrupted flight. Returns available options with schedule and capacity info.',
        'apiOperationMapping': {
            'apiId': api_id,
            'apiName': 'PassengerServiceAPI',
            'apiVersion': '1.0.0',
            'apiContext': '/passenger',
            'backendOperation': {'target': '/alternatives/{flightId}', 'verb': 'GET'}
        }
    },
    {
        'target': 'getAlternativeFlightsDetailed',
        'feature': 'TOOL',
        'authType': 'Any',
        'throttlingPolicy': 'Unlimited',
        'scopes': [],
        'description': 'Get detailed alternative flight options including seat availability breakdown by class and estimated delays.',
        'apiOperationMapping': {
            'apiId': api_id,
            'apiName': 'PassengerServiceAPI',
            'apiVersion': '1.0.0',
            'apiContext': '/passenger',
            'backendOperation': {'target': '/alternatives-detailed/{flightId}', 'verb': 'GET'}
        }
    },
    {
        'target': 'evaluateRebook',
        'feature': 'TOOL',
        'authType': 'Any',
        'throttlingPolicy': 'Unlimited',
        'scopes': [],
        'description': 'Evaluate rebooking options for a specific passenger on a specific flight. Returns ranked options with recommendations based on loyalty tier.',
        'apiOperationMapping': {
            'apiId': api_id,
            'apiName': 'PassengerServiceAPI',
            'apiVersion': '1.0.0',
            'apiContext': '/passenger',
            'backendOperation': {'target': '/evaluate-rebook/{passengerId}/{flightId}', 'verb': 'GET'}
        }
    },
    {
        'target': 'rebookPassenger',
        'feature': 'TOOL',
        'authType': 'Any',
        'throttlingPolicy': 'Unlimited',
        'scopes': [],
        'description': 'Rebook a passenger from their original flight to a new flight. Requires passenger_id, original_flight_id, new_flight_id. Optionally specify preferred_class.',
        'apiOperationMapping': {
            'apiId': api_id,
            'apiName': 'PassengerServiceAPI',
            'apiVersion': '1.0.0',
            'apiContext': '/passenger',
            'backendOperation': {'target': '/rebook', 'verb': 'POST'}
        }
    },
    {
        'target': 'notifyPassenger',
        'feature': 'TOOL',
        'authType': 'Any',
        'throttlingPolicy': 'Unlimited',
        'scopes': [],
        'description': 'Send a notification to a passenger. Specify passenger_id, notification_type (e.g., delay, rebooking, compensation), and message text.',
        'apiOperationMapping': {
            'apiId': api_id,
            'apiName': 'PassengerServiceAPI',
            'apiVersion': '1.0.0',
            'apiContext': '/passenger',
            'backendOperation': {'target': '/notify', 'verb': 'POST'}
        }
    },
    {
        'target': 'processCompensation',
        'feature': 'TOOL',
        'authType': 'Any',
        'throttlingPolicy': 'Unlimited',
        'scopes': [],
        'description': 'Process compensation for a passenger affected by a delay. Requires passenger_id, flight_id, delay_minutes, current_hour. Returns compensation breakdown based on loyalty tier.',
        'apiOperationMapping': {
            'apiId': api_id,
            'apiName': 'PassengerServiceAPI',
            'apiVersion': '1.0.0',
            'apiContext': '/passenger',
            'backendOperation': {'target': '/compensation', 'verb': 'POST'}
        }
    }
]

payload = {
    'name': 'CustomerServicePassengerMCP',
    'context': '/cs-passenger-mcp',
    'version': '1.0.0',
    'policies': ['Unlimited'],
    'operations': operations
}
with open('$PASSENGER_PAYLOAD', 'w') as f:
    json.dump(payload, f)
print('  PassengerMCP payload: 10 tools')
"

# ── Create both MCP servers ──────────────────────────────────────────────────
create_mcp_server "CustomerServiceDisruptionMCP" "/cs-disruption-mcp" "1.0.0" "$DISRUPTION_PAYLOAD"
DISRUPTION_MCP_ID="$MCP_RESULT_ID"

create_mcp_server "CustomerServicePassengerMCP" "/cs-passenger-mcp" "1.0.0" "$PASSENGER_PAYLOAD"
PASSENGER_MCP_ID="$MCP_RESULT_ID"

# Clean up payload files
rm -f "$DISRUPTION_PAYLOAD" "$PASSENGER_PAYLOAD"


# ══════════════════════════════════════════════════════════════════════════════
# CREATE APPLICATION + OAUTH2 KEYS + SUBSCRIBE
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "============================================================"
echo "= CREATING APPLICATION & SUBSCRIBING TO MCP SERVERS"
echo "============================================================"
echo ""

CS_APP_NAME="CustomerServiceCopilot"

# Check if application already exists
EXISTING_APP=$(curl -sk "${DEVPORTAL_URL}/applications?query=${CS_APP_NAME}" -u admin:admin \
    | python3 -c "import sys,json; apps=json.load(sys.stdin).get('list',[]); print(next((a['applicationId'] for a in apps if a['name']=='${CS_APP_NAME}'), ''))" 2>/dev/null || echo "")

if [ -n "$EXISTING_APP" ]; then
    echo -e "= Application ${YELLOW}already exists${NC} (ID: $EXISTING_APP)"
    CS_APP_ID="$EXISTING_APP"
else
    printf "= Creating application '${CS_APP_NAME}'..."
    APP_RESP=$(curl -sk -X POST "${DEVPORTAL_URL}/applications" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"${CS_APP_NAME}\",
            \"throttlingPolicy\": \"Unlimited\",
            \"description\": \"Customer Service Agent Copilot — uses MCP tools from existing REST APIs\",
            \"tokenType\": \"JWT\"
        }")
    CS_APP_ID=$(echo "$APP_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('applicationId',''))" 2>/dev/null || echo "")

    if [ -z "$CS_APP_ID" ]; then
        echo -e " ${RED}Failed.${NC}"
        echo "  DEBUG: $APP_RESP"
        exit 1
    fi
    echo -e " ${GREEN}Created${NC} (ID: $CS_APP_ID)."
fi

# Generate OAuth2 keys
printf "= Generating OAuth2 keys..."
EXISTING_KEYS=$(curl -sk "${DEVPORTAL_URL}/applications/${CS_APP_ID}/oauth-keys" -u admin:admin \
    | python3 -c "import sys,json; keys=json.load(sys.stdin).get('list',[]); print(keys[0].get('consumerKey','') if keys else '')" 2>/dev/null || echo "")

if [ -n "$EXISTING_KEYS" ]; then
    echo -e " ${YELLOW}Already exist.${NC}"
    CS_CONSUMER_KEY="$EXISTING_KEYS"
    CS_CONSUMER_SECRET=$(curl -sk "${DEVPORTAL_URL}/applications/${CS_APP_ID}/oauth-keys" -u admin:admin \
        | python3 -c "import sys,json; keys=json.load(sys.stdin).get('list',[]); print(keys[0].get('consumerSecret','') if keys else '')" 2>/dev/null || echo "")
else
    KEYS_RESP=$(curl -sk -X POST "${DEVPORTAL_URL}/applications/${CS_APP_ID}/generate-keys" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d '{
            "keyType": "PRODUCTION",
            "grantTypesToBeSupported": ["client_credentials", "password"],
            "keyManager": "ADRFlightDelaySPA",
            "validityTime": 3600,
            "scopes": ["default"]
        }')
    CS_CONSUMER_KEY=$(echo "$KEYS_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('consumerKey',''))" 2>/dev/null || echo "")
    CS_CONSUMER_SECRET=$(echo "$KEYS_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('consumerSecret',''))" 2>/dev/null || echo "")

    if [ -n "$CS_CONSUMER_KEY" ]; then
        echo -e " ${GREEN}Done${NC} (Key: ${CS_CONSUMER_KEY:0:10}...)."
    else
        echo -e " ${RED}Failed.${NC}"
        echo "  DEBUG: $KEYS_RESP"
    fi
fi

# Subscribe to both MCP Servers
for MCP_INFO in "DisruptionMCP:$DISRUPTION_MCP_ID" "PassengerMCP:$PASSENGER_MCP_ID"; do
    MCP_LABEL=$(echo "$MCP_INFO" | cut -d: -f1)
    MCP_ID=$(echo "$MCP_INFO" | cut -d: -f2)

    if [ -z "$MCP_ID" ]; then
        echo -e "  ${RED}Skipping subscription to $MCP_LABEL — no MCP ID.${NC}"
        continue
    fi

    printf "= Subscribing to ${MCP_LABEL}..."
    SUB_RESP=$(curl -sk -X POST "${DEVPORTAL_URL}/subscriptions" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d "{\"applicationId\":\"$CS_APP_ID\",\"apiId\":\"$MCP_ID\",\"throttlingPolicy\":\"Unlimited\"}")

    if echo "$SUB_RESP" | grep -q '"subscriptionId"'; then
        echo -e " ${GREEN}Done.${NC}"
    elif echo "$SUB_RESP" | grep -q 'already exists'; then
        echo -e " ${YELLOW}Already subscribed.${NC}"
    else
        echo -e " ${RED}Failed.${NC}"
        echo "  DEBUG: $SUB_RESP"
    fi
done


# ── Wait for gateway sync ────────────────────────────────────────────────────
echo ""
printf "= Waiting for gateway to sync..."
sleep 15
echo -e " ${GREEN}Done.${NC}"


# ── Inject MCP OAuth credentials into CS Agent config ─────────────────────────
CS_CONFIG="Config.docker.csagent.toml"
if [ -n "$CS_CONSUMER_KEY" ] && [ -n "$CS_CONSUMER_SECRET" ]; then
    echo ""
    printf "= Injecting MCP OAuth credentials into CS Agent config..."
    sed -i.bak "s|^mcpOauthConsumerKey=.*|mcpOauthConsumerKey=\"${CS_CONSUMER_KEY}\"|" "$CS_CONFIG"
    sed -i.bak "s|^mcpOauthConsumerSecret=.*|mcpOauthConsumerSecret=\"${CS_CONSUMER_SECRET}\"|" "$CS_CONFIG"
    rm -f "${CS_CONFIG}.bak"
    echo -e " ${GREEN}Done${NC}"
    echo "    Consumer Key : ${CS_CONSUMER_KEY:0:10}..."

    # Restart CS Agent to pick up new credentials
    printf "= Restarting CS Agent to apply new credentials..."
    docker compose stop cs-agent  > /dev/null 2>&1
    docker compose rm -f cs-agent > /dev/null 2>&1
    docker compose up -d cs-agent > /dev/null 2>&1
    echo -e " ${GREEN}Done${NC}"

    # Wait for CS Agent to be ready
    printf "= Waiting for CS Agent to start..."
    sleep 10
    echo -e " ${GREEN}Done${NC}"
else
    echo ""
    echo -e "= ${YELLOW}Skipping CS Agent config injection — no OAuth keys available.${NC}"
fi


# ══════════════════════════════════════════════════════════════════════════════
# SMOKE TESTS
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "============================================================"
echo "= SMOKE TEST: CUSTOMER SERVICE MCP SERVERS"
echo "============================================================"
echo ""

# Generate Internal-Key for the application (for smoke tests)
printf "= Generating Internal-Key for smoke tests..."
INTERNAL_KEY=$(curl -sk -X POST "${DEVPORTAL_URL}/applications/${CS_APP_ID}/api-keys/PRODUCTION/generate" \
    -u admin:admin \
    -H "Content-Type: application/json" \
    -d '{"validityPeriod":-1,"additionalProperties":{}}' \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('apikey',''))" 2>/dev/null || echo "")

if [ -n "$INTERNAL_KEY" ]; then
    echo -e " ${GREEN}Done${NC} (length: ${#INTERNAL_KEY})"
else
    echo -e " ${YELLOW}Could not generate key — skipping smoke tests.${NC}"
fi

if [ -n "$INTERNAL_KEY" ]; then
    for MCP_INFO in "DisruptionMCP:/cs-disruption-mcp/1.0.0/mcp:getFlights" "PassengerMCP:/cs-passenger-mcp/1.0.0/mcp:getAllBookings"; do
        MCP_LABEL=$(echo "$MCP_INFO" | cut -d: -f1)
        MCP_PATH=$(echo "$MCP_INFO" | cut -d: -f2)
        MCP_TOOL=$(echo "$MCP_INFO" | cut -d: -f3)
        MCP_GW="http://localhost:8283${MCP_PATH}"

        echo ""
        echo "  Testing ${MCP_LABEL} at ${MCP_GW}..."

        # Test 1: Initialize
        printf "    - MCP initialize..."
        INIT_RESP=$(curl -sk -X POST "$MCP_GW" \
            -H "Content-Type: application/json" \
            -H "Internal-Key: $INTERNAL_KEY" \
            -H "Accept: application/json, text/event-stream" \
            -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke-test","version":"1.0.0"}}}')

        if echo "$INIT_RESP" | grep -q '"protocolVersion"'; then
            echo -e " ${GREEN}PASS${NC}"
        else
            echo -e " ${RED}FAIL${NC}"
            echo "      Response: ${INIT_RESP:0:200}"
            continue
        fi

        # Test 2: tools/list
        printf "    - MCP tools/list..."
        TOOLS_RESP=$(curl -sk -X POST "$MCP_GW" \
            -H "Content-Type: application/json" \
            -H "Internal-Key: $INTERNAL_KEY" \
            -H "Accept: application/json, text/event-stream" \
            -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}')

        TOOL_COUNT=$(echo "$TOOLS_RESP" | python3 -c "
import sys, json
raw = sys.stdin.read()
tools = []
for line in raw.split('\n'):
    line = line.strip()
    if line.startswith('data:'):
        try:
            data = json.loads(line[5:].strip())
            tools = data.get('result', data).get('tools', [])
            if tools: break
        except: pass
if not tools:
    try:
        data = json.loads(raw)
        tools = data.get('result', data).get('tools', [])
    except: pass
print(len(tools))
" 2>/dev/null || echo "0")

        if [ "$TOOL_COUNT" -gt 0 ] 2>/dev/null; then
            echo -e " ${GREEN}PASS${NC} ($TOOL_COUNT tools)"
        else
            echo -e " ${RED}FAIL${NC} (0 tools)"
            echo "      Response: ${TOOLS_RESP:0:300}"
        fi

        # Test 3: tools/call
        printf "    - MCP tools/call (${MCP_TOOL})..."
        CALL_RESP=$(curl -sk -X POST "$MCP_GW" \
            -H "Content-Type: application/json" \
            -H "Internal-Key: $INTERNAL_KEY" \
            -H "Accept: application/json, text/event-stream" \
            -d "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"${MCP_TOOL}\",\"arguments\":{}}}")

        if echo "$CALL_RESP" | grep -q '"content"'; then
            echo -e " ${GREEN}PASS${NC}"
        else
            CALL_STATUS=$(echo "$CALL_RESP" | head -c 200)
            echo -e " ${YELLOW}Response: $CALL_STATUS${NC}"
        fi
    done
fi


# ══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "============================================================"
echo "= CUSTOMER SERVICE AGENT COPILOT — DEPLOYMENT COMPLETE"
echo "============================================================"
echo ""
echo "  MCP Server Details:"
echo "    ── DisruptionMCP ──"
echo "    Name         : CustomerServiceDisruptionMCP"
echo "    ID           : $DISRUPTION_MCP_ID"
echo "    Gateway HTTP : http://localhost:8283/cs-disruption-mcp/1.0.0/mcp"
echo "    Tools        : 4 (flights, disruptions)"
echo ""
echo "    ── PassengerMCP ──"
echo "    Name         : CustomerServicePassengerMCP"
echo "    ID           : $PASSENGER_MCP_ID"
echo "    Gateway HTTP : http://localhost:8283/cs-passenger-mcp/1.0.0/mcp"
echo "    Tools        : 10 (bookings, passengers, rebook, notify, compensate)"
echo ""
echo "  Application Details:"
echo "    Name         : $CS_APP_NAME"
echo "    ID           : $CS_APP_ID"
if [ -n "$CS_CONSUMER_KEY" ]; then
    echo "    Consumer Key : $CS_CONSUMER_KEY"
    echo "    Consumer Sec : $CS_CONSUMER_SECRET"
fi
echo ""
echo "  Source APIs (Usecase 1):"
echo "    DisruptionDetectionAPI : $DISRUPTION_API_ID (4 tools)"
echo "    PassengerServiceAPI    : $PASSENGER_API_ID (10 tools)"
echo ""
echo "  MCP Tools Available (14 total):"
echo "    ── Flight & Disruption Info (DisruptionMCP) ──"
echo "    1.  getFlights              - List all flights"
echo "    2.  getFlightById           - Get flight details by ID"
echo "    3.  getFlightSeats          - Check seat availability"
echo "    4.  getActiveDisruptions    - View active disruptions"
echo ""
echo "    ── Passenger Management (PassengerMCP) ──"
echo "    5.  getBookingsByFlight     - Bookings for a flight"
echo "    6.  getAllBookings           - All bookings across flights"
echo "    7.  getPassengerById        - Passenger details"
echo "    8.  getPassengerHistory     - Passenger flight history"
echo "    9.  getAlternativeFlights   - Find rebooking options"
echo "    10. getAlternativeFlightsDetailed - Detailed rebooking options"
echo "    11. evaluateRebook          - Evaluate rebooking for a passenger"
echo "    12. rebookPassenger         - Execute passenger rebooking"
echo "    13. notifyPassenger         - Send passenger notification"
echo "    14. processCompensation     - Process delay compensation"
echo ""
echo "  How this differs from Usecase 1 (ADR MCP Server):"
echo "    Usecase 1: generate-from-mcp-server (proxies a dedicated Ballerina MCP backend)"
echo "    Usecase 2: generate-from-api (composes MCP tools from published REST APIs)"
echo "    Note: Two MCP servers needed because generate-from-api only supports"
echo "          one source REST API per MCP server."
echo ""
