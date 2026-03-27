#!/bin/bash
# =============================================================================
# ADR Flight Delay Demo — Create and Deploy APIs to WSO2 API Manager
# =============================================================================
# This script imports OpenAPI definitions for all services into APIM,
# registers Ollama as an AI Service Provider, creates an AI API,
# creates revisions, deploys to gateway, and publishes them.
#
# Pre-requisites: WSO2 API Manager must be running and healthy.
# Usage: ./create_apis.sh
# =============================================================================

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

APIM_HOST="https://localhost:9446"
OLLAMA_MODEL="${OLLAMA_MODEL:-qwen3:1.7b}"

echo ""
echo "============================================================"
echo "= CREATING AND DEPLOYING APIs TO WSO2 API MANAGER"
echo "============================================================"

# ── Wait for APIM REST APIs to be ready ───────────────────────────────────────
echo "= Checking APIM REST API readiness..."
RETRY=0
MAX_RETRY=24
while [ $RETRY -lt $MAX_RETRY ]; do
    HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "${APIM_HOST}/api/am/publisher/v4/apis?limit=1" -u admin:admin 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "  ${GREEN}APIM REST APIs are ready.${NC}"
        break
    fi
    RETRY=$((RETRY + 1))
    echo "  [$RETRY/$MAX_RETRY] Not ready yet (HTTP $HTTP_CODE). Waiting 10s..."
    sleep 10
done

if [ $RETRY -ge $MAX_RETRY ]; then
    echo -e "  ${RED}APIM REST APIs did not become ready in time.${NC}"
    exit 1
fi

# ── Import IS certificate into APIM truststore ───────────────────────────────
# IS generates a fresh 10-year self-signed cert at build time (Dockerfile.is).
# APIM needs this cert in its truststore so it trusts IS as Key Manager.
echo ""
echo "= Importing IS certificate into APIM truststore..."
IS_CERT_IMPORTED=false

# Export cert from IS container
docker exec adr-identity-server keytool -exportcert -alias wso2carbon \
    -keystore /home/wso2carbon/wso2is-7.2.0/repository/resources/security/wso2carbon.p12 \
    -storepass wso2carbon -storetype PKCS12 -file /tmp/is_export.crt 2>/dev/null

if docker cp adr-identity-server:/tmp/is_export.crt /tmp/is_export.crt 2>/dev/null && \
   docker cp /tmp/is_export.crt adr-api-manager:/tmp/is_export.crt 2>/dev/null; then

    # Remove old IS cert alias if exists
    docker exec adr-api-manager keytool -delete -alias wso2is \
        -keystore /home/wso2carbon/wso2am-4.6.0/repository/resources/security/client-truststore.jks \
        -storepass wso2carbon 2>/dev/null || true

    # Import the fresh IS cert
    if docker exec adr-api-manager keytool -importcert -alias wso2is -file /tmp/is_export.crt \
        -keystore /home/wso2carbon/wso2am-4.6.0/repository/resources/security/client-truststore.jks \
        -storepass wso2carbon -noprompt 2>/dev/null; then
        IS_CERT_IMPORTED=true
        echo -e "  ${GREEN}IS certificate imported into APIM truststore.${NC}"
    fi
    rm -f /tmp/is_export.crt
fi

if [ "$IS_CERT_IMPORTED" = false ]; then
    echo -e "  ${YELLOW}Warning: Could not import IS cert. APIM may not trust IS tokens.${NC}"
fi

# ── Ensure Ollama model is available ─────────────────────────────────────────
echo ""
printf "= Ensuring Ollama model ${OLLAMA_MODEL} is available..."
if docker exec adr-ollama ollama list 2>/dev/null | grep -q "${OLLAMA_MODEL}"; then
    echo -e " ${GREEN}Already available.${NC}"
else
    echo " Pulling..."
    docker exec adr-ollama ollama pull "${OLLAMA_MODEL}" 2>&1 | tail -3
    echo -e "  ${GREEN}Model ${OLLAMA_MODEL} pulled successfully.${NC}"
fi

# Reset AI Gateway token in orchestrator config (will be re-injected after key generation)
ORCH_CONFIG="${DIR}/Config.docker.orchestrator.toml"
if [ -f "$ORCH_CONFIG" ]; then
    python3 -c "
with open('$ORCH_CONFIG', 'r') as f:
    lines = f.readlines()
with open('$ORCH_CONFIG', 'w') as f:
    for line in lines:
        if line.strip().startswith('aiGatewayToken='):
            f.write('aiGatewayToken=\"\"\n')
        elif line.strip().startswith('agentId='):
            f.write('agentId=\"\"\n')
        elif line.strip().startswith('agentSecret='):
            f.write('agentSecret=\"\"\n')
        elif line.strip().startswith('appClientId='):
            f.write('appClientId=\"\"\n')
        elif line.strip().startswith('mcpApiKey='):
            f.write('mcpApiKey=\"\"\n')
        elif line.strip().startswith('mcpServerUrl='):
            f.write('mcpServerUrl=\"http://adr-mcp-server:9096/mcp\"\n')
        else:
            f.write(line)
"
fi

# Reset CS Agent config tokens (will be re-injected after key generation)
CS_AGENT_CONFIG="${DIR}/Config.docker.csagent.toml"
if [ -f "$CS_AGENT_CONFIG" ]; then
    python3 -c "
with open('$CS_AGENT_CONFIG', 'r') as f:
    lines = f.readlines()
with open('$CS_AGENT_CONFIG', 'w') as f:
    for line in lines:
        if line.strip().startswith('aiGatewayToken='):
            f.write('aiGatewayToken=\"\"\n')
        elif line.strip().startswith('agentId='):
            f.write('agentId=\"\"\n')
        elif line.strip().startswith('agentSecret='):
            f.write('agentSecret=\"\"\n')
        elif line.strip().startswith('appClientId='):
            f.write('appClientId=\"\"\n')
        elif line.strip().startswith('mcpApiKey='):
            f.write('mcpApiKey=\"\"\n')
        else:
            f.write(line)
"
fi

# Reset Admin Agent config tokens (will be re-injected after key generation)
ADMIN_AGENT_CONFIG="${DIR}/Config.docker.adminagent.toml"
if [ -f "$ADMIN_AGENT_CONFIG" ]; then
    python3 -c "
with open('$ADMIN_AGENT_CONFIG', 'r') as f:
    lines = f.readlines()
with open('$ADMIN_AGENT_CONFIG', 'w') as f:
    for line in lines:
        if line.strip().startswith('aiGatewayToken='):
            f.write('aiGatewayToken=\"\"\n')
        elif line.strip().startswith('agentId='):
            f.write('agentId=\"\"\n')
        elif line.strip().startswith('agentSecret='):
            f.write('agentSecret=\"\"\n')
        elif line.strip().startswith('appClientId='):
            f.write('appClientId=\"\"\n')
        elif line.strip().startswith('mcpApiKey='):
            f.write('mcpApiKey=\"\"\n')
        elif line.strip().startswith('mcpServerUrl='):
            f.write('mcpServerUrl=\"https://adr-api-manager:8246/adr-mcp/1.0.0/mcp\"\n')
        else:
            f.write(line)
"
fi

# ── Register Ollama as AI Service Provider ────────────────────────────────────
echo ""
echo "============================================================"
echo "= REGISTERING OLLAMA AS AI SERVICE PROVIDER"
echo "============================================================"
echo ""

OPENAPI_DIR="$DIR/API_Definitions"
OLLAMA_OPENAPI="$OPENAPI_DIR/OllamaAI_API/ollama_openapi.yaml"

# Check if Ollama AI SP already exists
printf "= Checking for existing Ollama AI Service Provider..."
OLLAMA_SP_ID=$(curl -sk "${APIM_HOST}/api/am/admin/v4/ai-service-providers" -u admin:admin \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
for sp in data.get('list', []):
    if sp.get('name') == 'Ollama':
        print(sp['id'])
        break
" 2>/dev/null || echo "")

if [ -n "$OLLAMA_SP_ID" ]; then
    echo -e " ${GREEN}Already exists${NC} (ID: $OLLAMA_SP_ID)."
else
    echo " Not found. Registering..."

    # Build configurations JSON (uses JSONPath for Ollama's native response format)
    OLLAMA_SP_CONFIGS=$(python3 -c "
import json
cfg = {
    'connectorType': 'default',
    'metadata': [
        {'attributeName': 'requestModel',       'inputSource': 'payload', 'attributeIdentifier': '\$.model',             'required': False},
        {'attributeName': 'responseModel',       'inputSource': 'payload', 'attributeIdentifier': '\$.model',             'required': True},
        {'attributeName': 'promptTokenCount',    'inputSource': 'payload', 'attributeIdentifier': '\$.prompt_eval_count', 'required': False},
        {'attributeName': 'completionTokenCount','inputSource': 'payload', 'attributeIdentifier': '\$.eval_count',        'required': False},
        {'attributeName': 'totalTokenCount',     'inputSource': 'payload', 'attributeIdentifier': '\$.prompt_eval_count', 'required': False}
    ],
    'authHeader': '',
    'authenticationConfiguration': {
        'enabled': False,
        'type': 'apikey',
        'parameters': {
            'headerEnabled': False,
            'headerName': '',
            'queryParameterEnabled': False
        }
    }
}
print(json.dumps(cfg))
")

    OLLAMA_SP_MODELS="[{\"models\":[\"${OLLAMA_MODEL}\"],\"name\":\"Ollama\"}]"

    printf "  - Registering Ollama AI Service Provider..."
    SP_RESP=$(curl -sk -X POST "${APIM_HOST}/api/am/admin/v4/ai-service-providers" \
        -u admin:admin \
        -F "name=Ollama" \
        -F "apiVersion=1.0.0" \
        -F "description=Local Ollama LLM server for chat completions" \
        -F "configurations=${OLLAMA_SP_CONFIGS}" \
        -F "apiDefinition=@${OLLAMA_OPENAPI}" \
        -F "multipleModelProviderSupport=false" \
        -F "modelProviders=${OLLAMA_SP_MODELS}")

    OLLAMA_SP_ID=$(echo "$SP_RESP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")

    if [ -n "$OLLAMA_SP_ID" ]; then
        echo -e " ${GREEN}Done${NC} (ID: $OLLAMA_SP_ID)."
    else
        echo -e " ${RED}Failed to register AI Service Provider.${NC}"
        echo "  DEBUG: $SP_RESP"
    fi
fi

# ── Function to import OpenAPI and create/deploy/publish API ──────────────────
import_openapi_api() {
    local SWAGGER_FILE="$1"
    local API_NAME="$2"
    local API_CONTEXT="$3"
    local API_VERSION="$4"
    local ENDPOINT_URL="$5"

    printf "= Creating API '${API_NAME}'..."

    # Step 1: Import OpenAPI with additional properties
    ADDITIONAL_PROPS=$(cat <<EOF
{"name":"${API_NAME}","version":"${API_VERSION}","context":"${API_CONTEXT}","gatewayType":"wso2/synapse","policies":["Unlimited"],"endpointConfig":{"endpoint_type":"http","sandbox_endpoints":{"url":"${ENDPOINT_URL}"},"production_endpoints":{"url":"${ENDPOINT_URL}"}}}
EOF
)

    API_CREATE_RESP=$(curl -sk -X POST "${APIM_HOST}/api/am/publisher/v4/apis/import-openapi" \
        -u admin:admin \
        -F "file=@${SWAGGER_FILE}" \
        -F "additionalProperties=${ADDITIONAL_PROPS}")

    API_ID=$(echo "$API_CREATE_RESP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")

    if [ -z "$API_ID" ]; then
        # Check if API already exists — look it up by name
        if echo "$API_CREATE_RESP" | grep -q "already exists"; then
            API_ID=$(curl -sk "${APIM_HOST}/api/am/publisher/v4/apis?query=name:${API_NAME}" -u admin:admin \
                | python3 -c "import sys,json; apis=json.load(sys.stdin).get('list',[]); print(apis[0]['id'] if apis else '')" 2>/dev/null || echo "")
            if [ -n "$API_ID" ]; then
                echo -e " ${YELLOW}Already exists${NC} (ID: $API_ID)."
                echo "$API_ID"
                return 0
            fi
        fi
        echo -e " ${RED}Failed to create API.${NC}"
        echo "  DEBUG: $API_CREATE_RESP" >&2
        return 1
    fi
    echo -e " ${GREEN}Created${NC} (ID: $API_ID)."

    # Step 2: Update API configuration (CORS, OAuth2)
    printf "  - Updating API configuration (CORS, OAuth2)..."

    CURRENT_API=$(curl -sk "${APIM_HOST}/api/am/publisher/v4/apis/$API_ID" -u admin:admin)

    UPDATED_API=$(echo "$CURRENT_API" | python3 -c "
import sys, json
api = json.load(sys.stdin)
api['securityScheme'] = ['basic_auth', 'oauth_basic_auth_api_key_mandatory', 'oauth2']
api['corsConfiguration'] = {
    'corsConfigurationEnabled': True,
    'accessControlAllowCredentials': True,
    'accessControlAllowOrigins': ['*'],
    'accessControlAllowHeaders': ['Authorization', 'Access-Control-Allow-Origin', 'Content-Type', 'SOAPAction', 'apikey', 'Internal-Key'],
    'accessControlAllowMethods': ['GET', 'PUT', 'POST', 'DELETE', 'PATCH', 'OPTIONS']
}
for field in ['id', 'createdTime', 'lastUpdatedTime', 'lastUpdatedTimestamp', 'createdTimestamp', 'provider']:
    api.pop(field, None)
print(json.dumps(api))
")

    curl -sk -X PUT "${APIM_HOST}/api/am/publisher/v4/apis/$API_ID" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d "$UPDATED_API" > /dev/null
    echo -e " ${GREEN}Done.${NC}"

    # Step 3: Create Revision
    printf "  - Creating revision..."
    REVISION_RESP=$(curl -sk -X POST "${APIM_HOST}/api/am/publisher/v4/apis/$API_ID/revisions" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d '{"description":"Initial deployment"}')

    REVISION_ID=$(echo $REVISION_RESP | python3 -c "import sys, json; print(json.load(sys.stdin).get('id',''))")

    if [ -z "$REVISION_ID" ]; then
        echo -e " ${RED}Failed.${NC}"
        echo "  DEBUG: $REVISION_RESP"
        return 1
    fi
    echo -e " ${GREEN}Done${NC} (Revision: $REVISION_ID)."

    # Step 4: Deploy Revision to Gateway
    printf "  - Deploying to gateway..."
    DEPLOY_RESP=$(curl -sk -X POST "${APIM_HOST}/api/am/publisher/v4/apis/$API_ID/deploy-revision?revisionId=$REVISION_ID" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d '[{"name":"Default","vhost":"localhost","displayOnDevportal":true}]')

    DEPLOY_STATUS=$(echo $DEPLOY_RESP | python3 -c "import sys, json; r=json.load(sys.stdin); print(r[0].get('status','') if isinstance(r,list) and len(r)>0 else '')" 2>/dev/null || echo "")

    if [ "$DEPLOY_STATUS" == "APPROVED" ]; then
        echo -e " ${GREEN}Done${NC} (Status: APPROVED)."
    else
        echo -e " Status: $DEPLOY_STATUS"
    fi

    # Step 5: Publish the API
    printf "  - Publishing API..."
    PUBLISH_RESP=$(curl -sk -X POST "${APIM_HOST}/api/am/publisher/v4/apis/change-lifecycle?apiId=$API_ID&action=Publish" \
        -u admin:admin)

    if echo "$PUBLISH_RESP" | grep -q '"workflowStatus":"APPROVED"'; then
        echo -e " ${GREEN}Done${NC} (Status: PUBLISHED)."
    else
        echo -e " ${RED}Failed.${NC}"
        echo "  DEBUG: $PUBLISH_RESP"
    fi

    # Return API_ID for subscription
    echo "$API_ID"
}

# ── Function to create an AI API (subtype AIAPI) and deploy/publish ───────────
import_ai_api() {
    local API_NAME="$1"
    local API_CONTEXT="$2"
    local API_VERSION="$3"
    local ENDPOINT_URL="$4"
    local LLM_PROVIDER_ID="$5"

    printf "= Creating AI API '${API_NAME}'..."

    # Step 1: Get the API definition from the AI Service Provider
    local API_DEF
    API_DEF=$(curl -sk "${APIM_HOST}/api/am/publisher/v4/ai-service-providers/${LLM_PROVIDER_ID}/api-definition" -u admin:admin)

    if [ -z "$API_DEF" ] || echo "$API_DEF" | grep -q '"code"'; then
        echo -e " ${RED}Failed to get API definition from AI Service Provider.${NC}"
        echo "  DEBUG: $API_DEF"
        return 1
    fi

    # Step 2: Build additionalProperties with subtypeConfiguration for AIAPI
    local ADDITIONAL_PROPS
    ADDITIONAL_PROPS=$(python3 -c "
import json
props = {
    'name': '${API_NAME}',
    'displayName': '${API_NAME}',
    'version': '${API_VERSION}',
    'context': '${API_CONTEXT}',
    'gatewayType': 'wso2/synapse',
    'policies': ['Unlimited'],
    'securityScheme': ['oauth2', 'api_key', 'oauth_basic_auth_api_key_mandatory'],
    'subtypeConfiguration': {
        'subtype': 'AIAPI',
        'configuration': {
            'llmProviderId': '${LLM_PROVIDER_ID}'
        }
    },
    'egress': True,
    'endpointConfig': {
        'endpoint_type': 'http',
        'production_endpoints': {
            'url': '${ENDPOINT_URL}',
            'config': {
                'actionDuration': '120000'
            }
        }
    }
}
print(json.dumps(props))
")

    # Step 3: Create API via import-openapi with inline definition
    API_CREATE_RESP=$(curl -sk -X POST "${APIM_HOST}/api/am/publisher/v4/apis/import-openapi" \
        -u admin:admin \
        -F "additionalProperties=${ADDITIONAL_PROPS}" \
        -F "inlineAPIDefinition=${API_DEF}")

    API_ID=$(echo "$API_CREATE_RESP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")

    if [ -z "$API_ID" ]; then
        # Check if API already exists — look it up by name
        if echo "$API_CREATE_RESP" | grep -q "already exists"; then
            API_ID=$(curl -sk "${APIM_HOST}/api/am/publisher/v4/apis?query=name:${API_NAME}" -u admin:admin \
                | python3 -c "import sys,json; apis=json.load(sys.stdin).get('list',[]); print(apis[0]['id'] if apis else '')" 2>/dev/null || echo "")
            if [ -n "$API_ID" ]; then
                echo -e " ${YELLOW}Already exists${NC} (ID: $API_ID)."
                echo "$API_ID"
                return 0
            fi
        fi
        echo -e " ${RED}Failed to create AI API.${NC}"
        echo "  DEBUG: $API_CREATE_RESP" >&2
        return 1
    fi
    echo -e " ${GREEN}Created${NC} (ID: $API_ID)."

    # Step 4: Create Revision
    printf "  - Creating revision..."
    REVISION_RESP=$(curl -sk -X POST "${APIM_HOST}/api/am/publisher/v4/apis/$API_ID/revisions" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d '{"description":"Initial deployment"}')

    REVISION_ID=$(echo $REVISION_RESP | python3 -c "import sys, json; print(json.load(sys.stdin).get('id',''))")

    if [ -z "$REVISION_ID" ]; then
        echo -e " ${RED}Failed.${NC}"
        echo "  DEBUG: $REVISION_RESP"
        return 1
    fi
    echo -e " ${GREEN}Done${NC} (Revision: $REVISION_ID)."

    # Step 5: Deploy Revision to Gateway
    printf "  - Deploying to gateway..."
    DEPLOY_RESP=$(curl -sk -X POST "${APIM_HOST}/api/am/publisher/v4/apis/$API_ID/deploy-revision?revisionId=$REVISION_ID" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d '[{"name":"Default","vhost":"localhost","displayOnDevportal":true}]')

    DEPLOY_STATUS=$(echo $DEPLOY_RESP | python3 -c "import sys, json; r=json.load(sys.stdin); print(r[0].get('status','') if isinstance(r,list) and len(r)>0 else '')" 2>/dev/null || echo "")

    if [ "$DEPLOY_STATUS" == "APPROVED" ]; then
        echo -e " ${GREEN}Done${NC} (Status: APPROVED)."
    else
        echo -e " Status: $DEPLOY_STATUS"
    fi

    # Step 6: Publish the API
    printf "  - Publishing API..."
    PUBLISH_RESP=$(curl -sk -X POST "${APIM_HOST}/api/am/publisher/v4/apis/change-lifecycle?apiId=$API_ID&action=Publish" \
        -u admin:admin)

    if echo "$PUBLISH_RESP" | grep -q '"workflowStatus":"APPROVED"'; then
        echo -e " ${GREEN}Done${NC} (Status: PUBLISHED)."
    else
        echo -e " ${RED}Failed.${NC}"
        echo "  DEBUG: $PUBLISH_RESP"
    fi

    # Return API_ID for subscription
    echo "$API_ID"
}

# ── OpenAPI Definitions Path ──────────────────────────────────────────────────
if [ ! -d "$OPENAPI_DIR" ]; then
    echo -e "${RED}Error: API_Definitions directory not found at $OPENAPI_DIR${NC}"
    exit 1
fi

echo ""
echo "= Using OpenAPI definitions from: $OPENAPI_DIR"
echo ""

# ── Create All APIs ───────────────────────────────────────────────────────────
echo "============================================================"
echo "= IMPORTING APIs FROM OPENAPI/SWAGGER FILES"
echo "============================================================"
echo ""

# Disruption Detection API
DISRUPTION_API_ID=$(import_openapi_api \
    "$OPENAPI_DIR/DisruptionDetection_API/swagger.yaml" \
    "DisruptionDetectionAPI" \
    "/disruption" \
    "1.0.0" \
    "http://disruption-detection:9090/disruption" | tail -1)

echo ""

# Crew Service API
CREW_API_ID=$(import_openapi_api \
    "$OPENAPI_DIR/CrewService_API/swagger.yaml" \
    "CrewServiceAPI" \
    "/crew" \
    "1.0.0" \
    "http://crew-service:9091/crew" | tail -1)

echo ""

# Passenger Service API
PASSENGER_API_ID=$(import_openapi_api \
    "$OPENAPI_DIR/PassengerService_API/swagger.yaml" \
    "PassengerServiceAPI" \
    "/passenger" \
    "1.0.0" \
    "http://passenger-service:9092/passenger" | tail -1)

echo ""

# Logistics Service API
LOGISTICS_API_ID=$(import_openapi_api \
    "$OPENAPI_DIR/LogisticsService_API/swagger.yaml" \
    "LogisticsServiceAPI" \
    "/logistics" \
    "1.0.0" \
    "http://logistics-service:9093/logistics" | tail -1)

echo ""

# ADR Orchestrator API
ORCHESTRATOR_API_ID=$(import_openapi_api \
    "$OPENAPI_DIR/ADROrchestrator_API/swagger.yaml" \
    "ADROrchestratorAPI" \
    "/adr" \
    "1.0.0" \
    "http://adr-orchestrator:9094/adr" | tail -1)

echo ""

# AI Agent API (LLM-powered natural language interface — restricted to user/OBO tokens only)
AI_AGENT_API_ID=$(import_openapi_api \
    "$OPENAPI_DIR/AIAgent_API/swagger.yaml" \
    "AIAgentAPI" \
    "/ai-agent" \
    "1.0.0" \
    "http://adr-orchestrator:9095/ai" | tail -1)

# Restrict AI Agent API to OAuth2 only (no API key) — enforces scope-based access control.
# Only user JWTs and OBO tokens carry ADR scopes; agent-only tokens are blocked at the gateway.
if [ -n "$AI_AGENT_API_ID" ]; then
    printf "  - Restricting AIAgentAPI to OAuth2 only (scope-protected)..."
    AI_AGENT_CURRENT=$(curl -sk "${APIM_HOST}/api/am/publisher/v4/apis/$AI_AGENT_API_ID" -u admin:admin)
    AI_AGENT_UPDATED=$(echo "$AI_AGENT_CURRENT" | python3 -c "
import sys, json
api = json.load(sys.stdin)
# OAuth2 only — no API key, no basic auth → forces scope validation
api['securityScheme'] = ['oauth2', 'oauth_basic_auth_api_key_mandatory']
# Ensure resource-level scopes are preserved from the swagger import
for field in ['id', 'createdTime', 'lastUpdatedTime', 'lastUpdatedTimestamp', 'createdTimestamp', 'provider']:
    api.pop(field, None)
print(json.dumps(api))
")
    curl -sk -X PUT "${APIM_HOST}/api/am/publisher/v4/apis/$AI_AGENT_API_ID" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d "$AI_AGENT_UPDATED" > /dev/null
    echo -e " ${GREEN}Done.${NC}"

    # Re-create revision and deploy after security update
    printf "  - Re-deploying AIAgentAPI with scope restrictions..."
    AI_REV_RESP=$(curl -sk -X POST "${APIM_HOST}/api/am/publisher/v4/apis/$AI_AGENT_API_ID/revisions" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d '{"description":"Scope-protected deployment"}')
    AI_REV_ID=$(echo $AI_REV_RESP | python3 -c "import sys, json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
    if [ -n "$AI_REV_ID" ]; then
        curl -sk -X POST "${APIM_HOST}/api/am/publisher/v4/apis/$AI_AGENT_API_ID/deploy-revision?revisionId=$AI_REV_ID" \
            -u admin:admin \
            -H "Content-Type: application/json" \
            -d '[{"name":"Default","vhost":"localhost","displayOnDevportal":true}]' > /dev/null
        echo -e " ${GREEN}Done.${NC}"
    else
        echo -e " ${YELLOW}Revision already at latest.${NC}"
    fi
fi

echo ""

# CS Agent API (Customer Service AI agent — restricted to OAuth2 only, customer-facing scopes)
CS_AGENT_API_ID=$(import_openapi_api \
    "$OPENAPI_DIR/CSAgent_API/swagger.yaml" \
    "CSAgentAPI" \
    "/cs-agent" \
    "1.0.0" \
    "http://cs-agent:9097/cs" | tail -1)

# Restrict CS Agent API to OAuth2 only (same as AIAgentAPI)
if [ -n "$CS_AGENT_API_ID" ]; then
    printf "  - Restricting CSAgentAPI to OAuth2 only (scope-protected)..."
    CS_AGENT_CURRENT=$(curl -sk "${APIM_HOST}/api/am/publisher/v4/apis/$CS_AGENT_API_ID" -u admin:admin)
    CS_AGENT_UPDATED=$(echo "$CS_AGENT_CURRENT" | python3 -c "
import sys, json
api = json.load(sys.stdin)
api['securityScheme'] = ['oauth2', 'oauth_basic_auth_api_key_mandatory']
for field in ['id', 'createdTime', 'lastUpdatedTime', 'lastUpdatedTimestamp', 'createdTimestamp', 'provider']:
    api.pop(field, None)
print(json.dumps(api))
")
    curl -sk -X PUT "${APIM_HOST}/api/am/publisher/v4/apis/$CS_AGENT_API_ID" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d "$CS_AGENT_UPDATED" > /dev/null
    echo -e " ${GREEN}Done.${NC}"

    # Re-create revision and deploy after security update
    printf "  - Re-deploying CSAgentAPI with scope restrictions..."
    CS_REV_RESP=$(curl -sk -X POST "${APIM_HOST}/api/am/publisher/v4/apis/$CS_AGENT_API_ID/revisions" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d '{"description":"Scope-protected deployment"}')
    CS_REV_ID=$(echo $CS_REV_RESP | python3 -c "import sys, json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
    if [ -n "$CS_REV_ID" ]; then
        curl -sk -X POST "${APIM_HOST}/api/am/publisher/v4/apis/$CS_AGENT_API_ID/deploy-revision?revisionId=$CS_REV_ID" \
            -u admin:admin \
            -H "Content-Type: application/json" \
            -d '[{"name":"Default","vhost":"localhost","displayOnDevportal":true}]' > /dev/null
        echo -e " ${GREEN}Done.${NC}"
    else
        echo -e " ${YELLOW}Revision already at latest.${NC}"
    fi
fi

echo ""

# Ollama AI API (AI Gateway — registered as AIAPI subtype)
if [ -n "$OLLAMA_SP_ID" ]; then
    OLLAMA_AI_API_ID=$(import_ai_api \
        "OllamaAIAPI" \
        "/ollama" \
        "1.0.0" \
        "http://ollama:11434" \
        "$OLLAMA_SP_ID" | tail -1)
    echo ""
else
    echo -e "  ${YELLOW}Skipping Ollama AI API — AI Service Provider not registered.${NC}"
    OLLAMA_AI_API_ID=""
    echo ""
fi

echo "============================================================"
echo "= API IMPORT COMPLETE"
echo "============================================================"

# ── IS Endpoints ──────────────────────────────────────────────────────────────
IS_HOST="https://localhost:9444"

# ── Register IS as Key Manager in APIM ────────────────────────────────────────
echo ""
echo "============================================================"
echo "= REGISTERING WSO2 IS AS KEY MANAGER"
echo "============================================================"
echo ""

# Delete existing Key Manager if present
printf "= Checking for existing Key Manager..."
EXISTING_KM=$(curl -sk "${APIM_HOST}/api/am/admin/v4/key-managers" -u admin:admin \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
for km in data.get('list', []):
    if km.get('name') == 'ADRFlightDelaySPA':
        print(km['id'])
        break
" 2>/dev/null || echo "")

if [ -n "$EXISTING_KM" ]; then
    echo -e " Found (ID: $EXISTING_KM). Deleting..."
    curl -sk -X DELETE "${APIM_HOST}/api/am/admin/v4/key-managers/$EXISTING_KM" -u admin:admin > /dev/null
    echo -e "  ${GREEN}Deleted.${NC}"
else
    echo -e " Not found."
fi

printf "= Registering IS Key Manager (WSO2-IS-7)..."
KM_RESP=$(curl -sk -X POST "${APIM_HOST}/api/am/admin/v4/key-managers" \
    -u admin:admin \
    -H "Content-Type: application/json" \
    -d @"$DIR/key_manager.json")

KM_ID=$(echo "$KM_RESP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")

if [ -z "$KM_ID" ]; then
    echo -e " ${RED}Failed.${NC}"
    echo "  DEBUG: $KM_RESP"
else
    echo -e " ${GREEN}Done${NC} (ID: $KM_ID)."
fi

# Wait for the Key Manager to be fully initialized (IS7 connector loadConfiguration)
echo "= Waiting for Key Manager to be fully initialized..."
sleep 15

# ── Create Application and Generate Keys via IS KM ───────────────────────────
echo ""
echo "============================================================"
echo "= CREATING APPLICATION & GENERATING KEYS"
echo "============================================================"
echo ""

# Delete existing application if present
printf "= Checking for existing application..."
EXISTING_APP=$(curl -sk "${APIM_HOST}/api/am/devportal/v3/applications?query=ADR%20Flight%20Delay%20Application" \
    -u admin:admin | python3 -c "
import sys, json
data = json.load(sys.stdin)
for app in data.get('list', []):
    if app.get('name') == 'ADR Flight Delay Application':
        print(app['applicationId'])
        break
" 2>/dev/null || echo "")

if [ -n "$EXISTING_APP" ]; then
    echo -e " Found (ID: $EXISTING_APP). Deleting..."
    curl -sk -X DELETE "${APIM_HOST}/api/am/devportal/v3/applications/$EXISTING_APP" -u admin:admin > /dev/null
    sleep 2
    echo -e "  ${GREEN}Deleted.${NC}"
else
    echo -e " Not found."
fi

printf "= Creating ADR Flight Delay Application..."
APP_RESP=$(curl -sk -X POST "${APIM_HOST}/api/am/devportal/v3/applications" \
    -u admin:admin \
    -H "Content-Type: application/json" \
    -d '{"name":"ADR Flight Delay Application","throttlingPolicy":"Unlimited","description":"Application for the ADR Flight Delay Demo with IS-based authentication","tokenType":"JWT"}')

APP_ID=$(echo "$APP_RESP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('applicationId',''))" 2>/dev/null || echo "")

if [ -z "$APP_ID" ]; then
    echo -e " ${RED}Failed.${NC}"
    echo "  DEBUG: $APP_RESP"
    exit 1
fi
echo -e " ${GREEN}Done${NC} (ID: $APP_ID)."

# Generate keys via the IS Key Manager (ADRFlightDelaySPA) with PKCE + public client
printf "= Generating OAuth2 keys via IS Key Manager..."
KEYS_RESP=$(curl -sk -X POST "${APIM_HOST}/api/am/devportal/v3/applications/$APP_ID/generate-keys" \
    -u admin:admin \
    -H "Content-Type: application/json" \
    -d "{
        \"keyType\": \"PRODUCTION\",
        \"keyManager\": \"ADRFlightDelaySPA\",
        \"grantTypesToBeSupported\": [\"client_credentials\", \"password\", \"authorization_code\", \"refresh_token\"],
        \"callbackUrl\": \"http://localhost:3000\",
        \"additionalProperties\": {
            \"ext_pkce_mandatory\": \"true\",
            \"ext_pkce_support_plain\": \"false\",
            \"ext_public_client\": \"true\",
            \"application_access_token_expiry_time\": \"3600\",
            \"user_access_token_expiry_time\": \"3600\"
        },
        \"validityTime\": 3600
    }")

CONSUMER_KEY=$(echo "$KEYS_RESP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('consumerKey',''))" 2>/dev/null || echo "")
CONSUMER_SECRET=$(echo "$KEYS_RESP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('consumerSecret',''))" 2>/dev/null || echo "")

if [ -n "$CONSUMER_KEY" ]; then
    echo -e " ${GREEN}Done.${NC}"
    echo "  Consumer Key: $CONSUMER_KEY"
else
    echo -e " ${RED}Failed.${NC}"
    echo "  DEBUG: $KEYS_RESP"
fi

# ── Subscribe APIs to the Application ─────────────────────────────────────────
echo ""
echo "= Subscribing APIs to ADR Flight Delay Application..."

for API_INFO in \
    "DisruptionDetectionAPI:$DISRUPTION_API_ID" \
    "CrewServiceAPI:$CREW_API_ID" \
    "PassengerServiceAPI:$PASSENGER_API_ID" \
    "LogisticsServiceAPI:$LOGISTICS_API_ID" \
    "ADROrchestratorAPI:$ORCHESTRATOR_API_ID" \
    "AIAgentAPI:$AI_AGENT_API_ID" \
    "CSAgentAPI:$CS_AGENT_API_ID" \
    "OllamaAIAPI:$OLLAMA_AI_API_ID"; do

    API_NAME="${API_INFO%%:*}"
    API_ID="${API_INFO##*:}"

    if [ -n "$API_ID" ] && [ "$API_ID" != "Failed" ]; then
        printf "  - Subscribing $API_NAME..."
        SUB_RESP=$(curl -sk -X POST "${APIM_HOST}/api/am/devportal/v3/subscriptions" \
            -u admin:admin \
            -H "Content-Type: application/json" \
            -d "{\"applicationId\":\"$APP_ID\",\"apiId\":\"$API_ID\",\"throttlingPolicy\":\"Unlimited\"}")

        if echo "$SUB_RESP" | grep -q '"subscriptionId"'; then
            echo -e " ${GREEN}Done.${NC}"
        else
            echo -e " ${RED}Failed.${NC}"
            echo "   DEBUG: $SUB_RESP"
        fi
    fi
done

# ── Generate Internal Key for Orchestrator to call Ollama AI API ──────────────
echo ""
echo "= Generating Internal Key for Ollama AI API access..."

if [ -n "$APP_ID" ]; then
    printf "  - Generating internal key for PRODUCTION..."

    # Generate keys for Resident Key Manager (may already exist — ignore errors)
    curl -sk -X POST "${APIM_HOST}/api/am/devportal/v3/applications/${APP_ID}/generate-keys" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d '{"keyType":"PRODUCTION","keyManager":"Resident Key Manager","grantTypesToBeSupported":["client_credentials"],"callbackUrl":"","validityTime":3600}' >/dev/null 2>&1 || true

    # Generate an API key (internal key) for the application — no expiry
    APIKEY_RESP=$(curl -sk -X POST "${APIM_HOST}/api/am/devportal/v3/applications/${APP_ID}/api-keys/PRODUCTION/generate" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d '{"validityPeriod":-1,"additionalProperties":{}}')

    INTERNAL_KEY=$(echo "$APIKEY_RESP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('apikey',''))" 2>/dev/null || echo "")

    if [ -n "$INTERNAL_KEY" ]; then
        echo -e " ${GREEN}Done.${NC}"

        # Inject the internal key into the host Config.toml (bind-mounted into orchestrator)
        printf "  - Injecting AI Gateway token into orchestrator config..."
        ORCH_CONFIG="${DIR}/Config.docker.orchestrator.toml"
        if [ -f "$ORCH_CONFIG" ]; then
            python3 -c "
import sys
key = sys.argv[1]
with open(sys.argv[2], 'r') as f:
    content = f.read()
content = content.replace('aiGatewayToken=\"\"', 'aiGatewayToken=\"' + key + '\"')
with open(sys.argv[2], 'w') as f:
    f.write(content)
" "$INTERNAL_KEY" "$ORCH_CONFIG"
        fi
        echo -e " ${GREEN}Done.${NC}"

        # Inject the internal key into CS agent config (bind-mounted into cs-agent)
        printf "  - Injecting AI Gateway token into CS agent config..."
        CS_AGENT_CONFIG="${DIR}/Config.docker.csagent.toml"
        if [ -f "$CS_AGENT_CONFIG" ]; then
            python3 -c "
import sys
key = sys.argv[1]
with open(sys.argv[2], 'r') as f:
    content = f.read()
content = content.replace('aiGatewayToken=\"\"', 'aiGatewayToken=\"' + key + '\"')
with open(sys.argv[2], 'w') as f:
    f.write(content)
" "$INTERNAL_KEY" "$CS_AGENT_CONFIG"
        fi
        echo -e " ${GREEN}Done.${NC}"

        # Inject the internal key into Admin Agent config (bind-mounted into admin-agent)
        printf "  - Injecting AI Gateway token into Admin Agent config..."
        ADMIN_AGENT_CONFIG="${DIR}/Config.docker.adminagent.toml"
        if [ -f "$ADMIN_AGENT_CONFIG" ]; then
            python3 -c "
import sys
key = sys.argv[1]
with open(sys.argv[2], 'r') as f:
    content = f.read()
content = content.replace('aiGatewayToken=\"\"', 'aiGatewayToken=\"' + key + '\"')
with open(sys.argv[2], 'w') as f:
    f.write(content)
" "$INTERNAL_KEY" "$ADMIN_AGENT_CONFIG"
        fi
        echo -e " ${GREEN}Done.${NC}"

        # Restart orchestrator to pick up the new token
        printf "  - Restarting orchestrator to apply token..."
        docker restart adr-orchestrator >/dev/null 2>&1 || true
        echo -e " ${GREEN}Done.${NC}"
    else
        echo -e " ${YELLOW}Could not generate internal key. Orchestrator will use direct Ollama connection.${NC}"
        echo "  DEBUG: $APIKEY_RESP"
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# APIM MCP SERVER PROXY — Secure MCP tool traffic through APIM Gateway
# ══════════════════════════════════════════════════════════════════════════════
# Creates a proper MCP Server Proxy in APIM under /mcp-servers namespace.
# The AI Agent connects through APIM instead of directly, adding:
#   - API governance (throttling, monitoring, analytics)
#   - MCP protocol-aware proxy (MCP Streamable HTTP transport)
#   - Tool call audit trail via APIM
#
# Uses generate-from-mcp-server endpoint which creates the proxy with proper
# backend/API operation mappings (backendOperationMapping & apiOperationMapping).
# This is required for tools/call to work correctly through the gateway.
# Note: generate-from-api leaves operation mappings null causing NPE on tools/call.
echo ""
echo "============================================================"
echo "= CREATING APIM MCP SERVER PROXY"
echo "============================================================"
echo ""

MCP_PUBLISHER_URL="${APIM_HOST}/api/am/publisher/v4/mcp-servers"

# Check if MCP server already exists
EXISTING_MCP=$(curl -sk "${MCP_PUBLISHER_URL}?query=name:ADRMCPServer" -u admin:admin \
    | python3 -c "import sys,json; s=json.load(sys.stdin).get('list',[]); print(s[0]['id'] if s else '')" 2>/dev/null || echo "")

if [ -n "$EXISTING_MCP" ]; then
    echo -e "= MCP Server Proxy ${YELLOW}already exists${NC} (ID: $EXISTING_MCP)"
    MCP_SERVER_ID="$EXISTING_MCP"
else
    # Step 1: Discover MCP tools via validate-mcp-server
    printf "= Discovering MCP tools from backend server..."
    VALIDATE_RESP=$(curl -sk -X POST "${MCP_PUBLISHER_URL}/validate-mcp-server" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d '{"url":"http://adr-mcp-server:9096","securityInfo":{"isSecure":false}}')

    IS_VALID=$(echo "$VALIDATE_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('isValid',''))" 2>/dev/null || echo "")

    if [ "$IS_VALID" != "True" ]; then
        echo -e " ${RED}Failed. MCP server not reachable or invalid.${NC}"
        echo "  DEBUG: $VALIDATE_RESP"
    else
        # Extract operations and count
        TOOL_COUNT=$(echo "$VALIDATE_RESP" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('toolInfo',{}).get('operations',[])))" 2>/dev/null || echo "0")
        echo -e " ${GREEN}Done${NC} ($TOOL_COUNT tools discovered)."

        # Build the generate-from-mcp-server payload with operation mappings
        # Each operation must include backendOperationMapping and apiOperationMapping
        # for tools/call to work through the gateway (APIM 4.6.0 requirement)
        MCP_PAYLOAD=$(echo "$VALIDATE_RESP" | python3 -c "
import sys, json
val = json.load(sys.stdin)
ops = val.get('toolInfo', {}).get('operations', [])
formatted = []
for op in ops:
    t = op['target']
    formatted.append({
        'target': t,
        'feature': 'TOOL',
        'authType': 'Any',
        'throttlingPolicy': 'Unlimited',
        'scopes': [],
        'schemaDefinition': op.get('schemaDefinition', ''),
        'description': op.get('description', ''),
        'backendOperationMapping': {
            'backendOperation': {'target': t, 'verb': 'TOOL'}
        },
        'apiOperationMapping': {
            'apiName': 'ADRMCPServer',
            'apiVersion': '1.0.0',
            'apiContext': '/adr-mcp',
            'backendOperation': {'target': t, 'verb': 'TOOL'}
        }
    })
payload = {
    'url': 'http://adr-mcp-server:9096',
    'securityInfo': {'isSecure': False},
    'additionalProperties': {
        'name': 'ADRMCPServer',
        'context': '/adr-mcp',
        'version': '1.0.0',
        'operations': formatted
    }
}
print(json.dumps(payload))
")

        # Step 2: Create MCP Server Proxy via generate-from-mcp-server
        printf "  - Creating MCP Server Proxy..."
        CREATE_RESP=$(curl -sk -X POST "${MCP_PUBLISHER_URL}/generate-from-mcp-server" \
            -u admin:admin \
            -H "Content-Type: application/json" \
            -d "$MCP_PAYLOAD")

        MCP_SERVER_ID=$(echo "$CREATE_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")

        if [ -z "$MCP_SERVER_ID" ]; then
            echo -e " ${RED}Failed.${NC}"
            echo "  DEBUG: $CREATE_RESP"
        else
            MCP_OPS=$(echo "$CREATE_RESP" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('operations',[])))" 2>/dev/null || echo "0")
            echo -e " ${GREEN}Created${NC} (ID: $MCP_SERVER_ID, $MCP_OPS operations)."

            # Step 3: Set endpoint configuration and subscription policies
            # generate-from-mcp-server creates with null endpointConfig and
            # DefaultSubscriptionless policy; fix both via PUT
            printf "  - Configuring endpoint and subscription policies..."
            MCP_SERVER_DATA=$(curl -sk "${MCP_PUBLISHER_URL}/${MCP_SERVER_ID}" \
                -u admin:admin -H "Accept: application/json")
            UPDATED_PAYLOAD=$(echo "$MCP_SERVER_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
data['endpointConfig'] = {
    'endpoint_type': 'http',
    'production_endpoints': {'url': 'http://adr-mcp-server:9096'},
    'sandbox_endpoints': {'url': 'http://adr-mcp-server:9096'}
}
data['policies'] = ['Unlimited']
print(json.dumps(data))
")
            PUT_RESP=$(curl -sk -X PUT "${MCP_PUBLISHER_URL}/${MCP_SERVER_ID}" \
                -u admin:admin \
                -H "Content-Type: application/json" \
                -d "$UPDATED_PAYLOAD")
            EP_CHECK=$(echo "$PUT_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); ep='set' if d.get('endpointConfig') else 'null'; pol=','.join(d.get('policies',[])); print(f'{ep} policies={pol}')" 2>/dev/null || echo "failed")
            echo -e " ${GREEN}Done${NC} ($EP_CHECK)."

            # Step 4: Create revision
            printf "  - Creating revision..."
            REV_RESP=$(curl -sk -X POST "${MCP_PUBLISHER_URL}/${MCP_SERVER_ID}/revisions" \
                -u admin:admin \
                -H "Content-Type: application/json" \
                -d '{"description":"Initial revision"}')
            MCP_REV_ID=$(echo "$REV_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
            echo -e " ${GREEN}Done${NC} (Revision: $MCP_REV_ID)."

            # Step 5: Deploy revision to gateway
            printf "  - Deploying to gateway..."
            DEPLOY_RESP=$(curl -sk -X POST "${MCP_PUBLISHER_URL}/${MCP_SERVER_ID}/deploy-revision?revisionId=${MCP_REV_ID}" \
                -u admin:admin \
                -H "Content-Type: application/json" \
                -d "[{\"revisionUuid\":\"${MCP_REV_ID}\",\"name\":\"Default\",\"vhost\":\"localhost\",\"displayOnDevportal\":true}]")
            DEPLOY_STATUS=$(echo "$DEPLOY_RESP" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r[0].get('status','') if isinstance(r,list) and len(r)>0 else '')" 2>/dev/null || echo "")
            echo -e " ${GREEN}Done${NC} (Status: $DEPLOY_STATUS)."

            # Step 6: Publish MCP Server
            printf "  - Publishing MCP Server..."
            PUB_RESP=$(curl -sk -X POST "${MCP_PUBLISHER_URL}/change-lifecycle?mcpServerId=${MCP_SERVER_ID}&action=Publish" \
                -u admin:admin \
                -H "Content-Type: application/json")

            MCP_STATUS=$(curl -sk "${MCP_PUBLISHER_URL}/${MCP_SERVER_ID}" -u admin:admin \
                | python3 -c "import sys,json; print(json.load(sys.stdin).get('lifeCycleStatus',''))" 2>/dev/null || echo "")
            echo -e " ${GREEN}Done${NC} (Status: $MCP_STATUS)."

            # Step 7: Subscribe MCP Server to the application
            # generate-from-mcp-server does not auto-subscribe (unlike generate-from-api)
            if [ -n "$APP_ID" ]; then
                printf "  - Subscribing MCP Server to application..."
                MCP_SUB_RESP=$(curl -sk -X POST "${APIM_HOST}/api/am/devportal/v3/subscriptions" \
                    -u admin:admin \
                    -H "Content-Type: application/json" \
                    -d "{\"applicationId\":\"$APP_ID\",\"apiId\":\"$MCP_SERVER_ID\",\"throttlingPolicy\":\"Unlimited\"}")

                if echo "$MCP_SUB_RESP" | grep -q '"subscriptionId"'; then
                    echo -e " ${GREEN}Done.${NC}"
                else
                    echo -e " ${YELLOW}Warning: Subscription may already exist or failed.${NC}"
                    echo "  DEBUG: $MCP_SUB_RESP"
                fi
            fi

            echo ""
            echo "  MCP Server Proxy Details:"
            echo "    Gateway URL  : https://localhost:8246/adr-mcp/1.0.0/mcp"
            echo "    Tools        : $MCP_OPS MCP tools proxied"
            echo "    Auth         : OAuth2 Bearer token required for tools/call"
            echo "    Note: Orchestrator connects directly (same Docker network)."
            echo "          APIM MCP proxy is for external clients."
        fi
    fi
fi

# ── Configure IS Application (rename, set allowed origins) ───────────────────
echo ""
echo "============================================================"
echo "= CONFIGURING IDENTITY SERVER APPLICATION"
echo "============================================================"
echo ""

# Find the auto-created IS application (pattern: admin_{APP_ID}_PRODUCTION)
IS_APP_NAME="admin_${APP_ID}_PRODUCTION"
printf "= Finding IS application ($IS_APP_NAME)..."
sleep 5  # Give IS time to create the app via KM integration

IS_APP_RESP=$(curl -sk "${IS_HOST}/api/server/v1/applications?filter=name+eq+${IS_APP_NAME}" \
    -u admin:admin -H "Accept: application/json")

IS_APP_ID=$(echo "$IS_APP_RESP" | python3 -c "
import sys, json
data = json.load(sys.stdin)
apps = data.get('applications', [])
if len(apps) > 0:
    print(apps[0]['id'])
" 2>/dev/null || echo "")

if [ -z "$IS_APP_ID" ]; then
    echo -e " ${YELLOW}Warning: Could not find IS application. Some configuration may need to be done manually.${NC}"
else
    echo -e " ${GREEN}Found${NC} (ID: $IS_APP_ID)."

    # Rename the IS application
    printf "  - Renaming to 'ADR Flight Delay Application'..."
    curl -sk -X PATCH "${IS_HOST}/api/server/v1/applications/$IS_APP_ID" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d '{"name":"ADR Flight Delay Application"}' > /dev/null
    echo -e " ${GREEN}Done.${NC}"

    # Configure claim configuration: set subject to username and request user profile claims
    printf "  - Configuring claims (subject=username, profile claims)..."
    curl -sk -X PATCH "${IS_HOST}/api/server/v1/applications/$IS_APP_ID" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d '{
            "claimConfiguration": {
                "dialect": "LOCAL",
                "requestedClaims": [
                    {"claim": {"uri": "http://wso2.org/claims/username"}, "mandatory": false},
                    {"claim": {"uri": "http://wso2.org/claims/emailaddress"}, "mandatory": false},
                    {"claim": {"uri": "http://wso2.org/claims/givenname"}, "mandatory": false},
                    {"claim": {"uri": "http://wso2.org/claims/lastname"}, "mandatory": false},
                    {"claim": {"uri": "http://wso2.org/claims/displayName"}, "mandatory": false},
                    {"claim": {"uri": "http://wso2.org/claims/groups"}, "mandatory": false},
                    {"claim": {"uri": "http://wso2.org/claims/roles"}, "mandatory": false}
                ],
                "subject": {
                    "claim": {"uri": "http://wso2.org/claims/username"},
                    "includeUserDomain": false,
                    "includeTenantDomain": false,
                    "useMappedLocalSubject": false,
                    "mappedLocalSubjectMandatory": false
                },
                "role": {
                    "includeUserDomain": true,
                    "claim": {"uri": "http://wso2.org/claims/roles"}
                }
            }
        }' > /dev/null
    echo -e " ${GREEN}Done.${NC}"

    # Update OIDC config with allowed origins
    printf "  - Setting allowed origins..."
    OIDC_CONFIG=$(curl -sk "${IS_HOST}/api/server/v1/applications/$IS_APP_ID/inbound-protocols/oidc" \
        -u admin:admin -H "Accept: application/json")

    UPDATED_OIDC=$(echo "$OIDC_CONFIG" | python3 -c "
import sys, json
cfg = json.load(sys.stdin)
cfg['allowedOrigins'] = ['http://localhost:3000', 'http://localhost:9095']
cfg['callbackURLs'] = ['http://localhost:3000', 'http://localhost:9095/ai/callback']
cfg['publicClient'] = True
cfg['pkce'] = {'mandatory': True, 'supportPlainTransformAlgorithm': False}
print(json.dumps(cfg))
")

    curl -sk -X PUT "${IS_HOST}/api/server/v1/applications/$IS_APP_ID/inbound-protocols/oidc" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d "$UPDATED_OIDC" > /dev/null
    echo -e " ${GREEN}Done.${NC}"

    # Enable APPLICATION audience for roles
    printf "  - Enabling APPLICATION audience for roles..."
    curl -sk -X PUT "${IS_HOST}/api/server/v1/applications/$IS_APP_ID/associated-roles" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d '{"allowedAudience":"APPLICATION","roles":[]}' > /dev/null
    echo -e " ${GREEN}Done.${NC}"

    # Create application roles
    echo "  - Creating application roles..."
    for ROLE_NAME in "adr_admin_role" "adr_operator_role"; do
        printf "    - Creating role '$ROLE_NAME'..."
        ROLE_RESP=$(curl -sk -X POST "${IS_HOST}/scim2/v2/Roles" \
            -u admin:admin \
            -H "Content-Type: application/json" \
            -d "{\"displayName\":\"$ROLE_NAME\",\"audience\":{\"value\":\"$IS_APP_ID\",\"type\":\"application\"},\"schemas\":[\"urn:ietf:params:scim:schemas:core:2.0:Role\"]}")
        if echo "$ROLE_RESP" | grep -q '"id"'; then
            echo -e " ${GREEN}Done.${NC}"
        else
            echo -e " ${YELLOW}May already exist.${NC}"
        fi
    done

    # ── Register API Resource (controls aud claim in JWT) ─────────────────────
    echo ""
    echo "  - Registering ADR API Resource (for aud + scopes in OBO token)..."
    printf "    - Creating API Resource..."
    API_RESOURCE_RESP=$(curl -sk -X POST "${IS_HOST}/api/server/v1/api-resources" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d '{
            "name": "ADR Flight Management API",
            "identifier": "https://adr.wso2.com/api",
            "description": "Autonomous Disruption Recovery API — flight ops, crew, passenger, logistics",
            "requiresAuthorization": false,
            "scopes": [
                {"name": "adr:flights:read",     "displayName": "Read Flight Data",       "description": "View flight schedules, status, and delay info"},
                {"name": "adr:flights:write",    "displayName": "Modify Flight Data",     "description": "Update flight schedules and assignments"},
                {"name": "adr:recovery:manage",  "displayName": "Manage Recovery",        "description": "Trigger and manage disruption recovery operations"},
                {"name": "adr:crew:read",        "displayName": "Read Crew Data",         "description": "View crew availability and assignments"},
                {"name": "adr:passenger:read",   "displayName": "Read Passenger Data",    "description": "View passenger bookings and rebooking options"},
                {"name": "adr:logistics:read",   "displayName": "Read Logistics Data",    "description": "View gate and aircraft logistics"}
            ]
        }')
    API_RESOURCE_ID=$(echo "$API_RESOURCE_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || echo "")
    if [ -n "$API_RESOURCE_ID" ]; then
        echo -e " ${GREEN}Done.${NC} (ID: $API_RESOURCE_ID)"
    else
        # May already exist — look it up
        EXISTING_RES=$(curl -sk -u admin:admin "${IS_HOST}/api/server/v1/api-resources?filter=identifier+eq+https://adr.wso2.com/api")
        API_RESOURCE_ID=$(echo "$EXISTING_RES" | python3 -c "
import sys, json
d = json.load(sys.stdin)
resources = d.get('APIResources', d.get('apiResources', []))
if resources:
    print(resources[0].get('id',''))
" 2>/dev/null || echo "")
        if [ -n "$API_RESOURCE_ID" ]; then
            echo -e " ${YELLOW}Already exists.${NC} (ID: $API_RESOURCE_ID)"
        else
            echo -e " ${RED}Failed.${NC}"
            echo "    DEBUG: $API_RESOURCE_RESP"
        fi
    fi

    # Authorize the application to consume the ADR API Resource
    if [ -n "$API_RESOURCE_ID" ]; then
        printf "    - Authorizing application to use ADR API..."
        AUTH_API_RESP=$(curl -sk -X POST "${IS_HOST}/api/server/v1/applications/$IS_APP_ID/authorized-apis" \
            -u admin:admin \
            -H "Content-Type: application/json" \
            -d "{
                \"id\": \"$API_RESOURCE_ID\",
                \"policyIdentifier\": \"No Policy\",
                \"scopes\": [\"adr:flights:read\", \"adr:flights:write\", \"adr:recovery:manage\", \"adr:crew:read\", \"adr:passenger:read\", \"adr:logistics:read\"]
            }")
        if echo "$AUTH_API_RESP" | grep -q '"error"'; then
            echo -e " ${YELLOW}May already be authorized.${NC}"
        else
            echo -e " ${GREEN}Done.${NC}"
        fi
    fi

    # ── Register MCP Server as API Resource (for MCP authorization) ───────────
    # This registers the MCP server in IS so it can be authorized to MCP client apps.
    # IS uses this to validate MCP client tokens and enforce scoped access to tools.
    echo ""
    echo "  - Registering MCP Server as API Resource (for MCP tool authorization)..."
    printf "    - Creating MCP Server resource..."
    MCP_RESOURCE_RESP=$(curl -sk -X POST "${IS_HOST}/api/server/v1/api-resources" \
        -u admin:admin \
        -H "Content-Type: application/json" \
        -d '{
            "name": "ADR MCP Server",
            "identifier": "https://adr.wso2.com/mcp-server",
            "description": "ADR Flight Recovery MCP Server — 22 tools for autonomous disruption recovery",
            "requiresAuthorization": true,
            "scopes": [
                {"name": "mcp:tools:execute",  "displayName": "Execute MCP Tools",  "description": "Permission to call MCP tools for flight recovery operations"},
                {"name": "mcp:tools:read",     "displayName": "Read MCP Tools",     "description": "Permission to list and discover available MCP tool definitions"}
            ]
        }')
    MCP_RESOURCE_ID=$(echo "$MCP_RESOURCE_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || echo "")
    if [ -n "$MCP_RESOURCE_ID" ]; then
        echo -e " ${GREEN}Done.${NC} (ID: $MCP_RESOURCE_ID)"
    else
        # May already exist — look it up
        EXISTING_MCP=$(curl -sk -u admin:admin "${IS_HOST}/api/server/v1/api-resources?filter=identifier+eq+https://adr.wso2.com/mcp-server")
        MCP_RESOURCE_ID=$(echo "$EXISTING_MCP" | python3 -c "
import sys, json
d = json.load(sys.stdin)
resources = d.get('APIResources', d.get('apiResources', []))
if resources:
    print(resources[0].get('id',''))
" 2>/dev/null || echo "")
        if [ -n "$MCP_RESOURCE_ID" ]; then
            echo -e " ${YELLOW}Already exists.${NC} (ID: $MCP_RESOURCE_ID)"
        else
            echo -e " ${RED}Failed.${NC}"
            echo "    DEBUG: $MCP_RESOURCE_RESP"
        fi
    fi

    # Authorize the application to access the MCP Server resource
    if [ -n "$MCP_RESOURCE_ID" ]; then
        printf "    - Authorizing application to access MCP Server..."
        MCP_AUTH_RESP=$(curl -sk -X POST "${IS_HOST}/api/server/v1/applications/$IS_APP_ID/authorized-apis" \
            -u admin:admin \
            -H "Content-Type: application/json" \
            -d "{
                \"id\": \"$MCP_RESOURCE_ID\",
                \"policyIdentifier\": \"No Policy\",
                \"scopes\": [\"mcp:tools:execute\", \"mcp:tools:read\"]
            }")
        if echo "$MCP_AUTH_RESP" | grep -q '"error"'; then
            echo -e " ${YELLOW}May already be authorized.${NC}"
        else
            echo -e " ${GREEN}Done.${NC}"
        fi
    fi
fi

# ── Create Users in IS ───────────────────────────────────────────────────────
echo ""
echo "= Creating demo users in Identity Server..."

create_user() {
    local USERNAME="$1"
    local PASSWORD="$2"
    local FIRSTNAME="$3"
    local LASTNAME="$4"
    local EMAIL="$5"

    printf "  - Creating user '$USERNAME'..."
    USER_RESP=$(curl -sk -X POST "${IS_HOST}/scim2/Users" \
        -u admin:admin \
        -H "Content-Type: application/scim+json" \
        -d "{
            \"schemas\": [\"urn:ietf:params:scim:schemas:core:2.0:User\"],
            \"userName\": \"$USERNAME\",
            \"password\": \"$PASSWORD\",
            \"name\": {\"givenName\": \"$FIRSTNAME\", \"familyName\": \"$LASTNAME\"},
            \"emails\": [{\"value\": \"$EMAIL\", \"primary\": true}]
        }")

    if echo "$USER_RESP" | grep -q '"id"'; then
        echo -e " ${GREEN}Done.${NC}"
    else
        echo -e " ${YELLOW}May already exist.${NC}"
    fi
}

create_user "adr_admin"    "Admin@123"    "ADR"    "Admin"    "admin@adr-demo.com"
create_user "adr_operator" "Operator@123" "ADR"    "Operator" "operator@adr-demo.com"

# ── Create Groups & Assign Users ─────────────────────────────────────────────
echo ""
echo "= Creating user groups..."

create_group_with_member() {
    local GROUP_NAME="$1"
    local USERNAME="$2"

    printf "  - Creating group '$GROUP_NAME' with member '$USERNAME'..."

    # Find SCIM user ID
    USER_ID=$(curl -sk -u admin:admin \
        "${IS_HOST}/scim2/Users?filter=userName+eq+$USERNAME" \
        -H "Accept: application/json" | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d['Resources'][0]['id'] if d.get('totalResults',0)>0 else '')" 2>/dev/null)

    if [ -z "$USER_ID" ]; then
        echo -e " ${YELLOW}User not found, skipping.${NC}"
        return
    fi

    GROUP_RESP=$(curl -sk -X POST "${IS_HOST}/scim2/Groups" \
        -u admin:admin \
        -H "Content-Type: application/scim+json" \
        -d "{
            \"schemas\": [\"urn:ietf:params:scim:schemas:core:2.0:Group\"],
            \"displayName\": \"$GROUP_NAME\",
            \"members\": [{\"value\": \"$USER_ID\", \"display\": \"$USERNAME\"}]
        }")

    if echo "$GROUP_RESP" | grep -q '"id"'; then
        echo -e " ${GREEN}Done.${NC}"
    else
        echo -e " ${YELLOW}May already exist.${NC}"
    fi
}

create_group_with_member "adr_admins"    "adr_admin"
create_group_with_member "adr_operators" "adr_operator"

# ── Register AI Agent in Identity Server (via SCIM2 Agents API) ───────────────
echo ""
echo "============================================================"
echo "= REGISTERING AI AGENT (OBO FLOW)"
echo "============================================================"
echo ""

AGENT_PASSWORD="AgentSecret@123"

printf "= Creating AI Agent identity in IS (SCIM2)..."
AGENT_RESP=$(curl -sk -X POST "${IS_HOST}/scim2/Agents" \
    -u admin:admin \
    -H "Content-Type: application/json" \
    -d '{
        "schemas": ["urn:scim:wso2:agent:schema"],
        "userName": "adr-ai-assistant",
        "password": "'"${AGENT_PASSWORD}"'",
        "displayName": "ADR AI Assistant"
    }')

AGENT_ID=$(echo "$AGENT_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || echo "")

if [ -n "$AGENT_ID" ]; then
    echo -e " ${GREEN}Done.${NC} (Agent ID: $AGENT_ID)"
else
    # Agent may already exist — look it up
    EXISTING=$(curl -sk -u admin:admin "${IS_HOST}/scim2/Agents?filter=userName+eq+adr-ai-assistant")
    AGENT_ID=$(echo "$EXISTING" | python3 -c "import sys,json; d=json.load(sys.stdin); r=d.get('Resources',[]); print(r[0]['id'] if r else '')" 2>/dev/null || echo "")
    if [ -n "$AGENT_ID" ]; then
        echo -e " ${YELLOW}Already exists.${NC} (Agent ID: $AGENT_ID)"
    else
        echo -e " ${RED}Failed.${NC}"
        echo "  DEBUG: $AGENT_RESP"
    fi
fi

if [ -n "$AGENT_ID" ]; then

    # Enable API-based authentication on the IS application (required for App Native Auth)
    if [ -n "$IS_APP_ID" ]; then
        printf "  - Enabling API-based authentication on application..."
        curl -sk -X PATCH "${IS_HOST}/api/server/v1/applications/$IS_APP_ID" \
            -u admin:admin \
            -H "Content-Type: application/json" \
            -d '{"advancedConfigurations":{"enableAPIBasedAuthentication":true}}' > /dev/null
        echo -e " ${GREEN}Done.${NC}"

        # Add OBO callback URL to application OIDC config (using regex for multiple URLs)
        printf "  - Adding OBO callback URL to OIDC config..."
        OIDC_CONF=$(curl -sk -u admin:admin "${IS_HOST}/api/server/v1/applications/$IS_APP_ID/inbound-protocols/oidc")
        UPDATED_OIDC=$(echo "$OIDC_CONF" | python3 -c "
import sys, json
d = json.load(sys.stdin)
cb = d.get('callbackURLs', [])
obo_cb_adr = 'http://localhost:9095/ai/callback'
obo_cb_cs = 'http://localhost:9097/cs/callback'
# Collect all required callback URLs
required = ['http://localhost:3000', obo_cb_adr, obo_cb_cs]
# Build regex pattern with all URLs
existing = set()
if len(cb) == 1 and cb[0].startswith('regexp='):
    inner = cb[0][len('regexp=('):-1]
    existing = set(inner.split('|'))
elif len(cb) >= 1:
    existing = set(cb)
for url in required:
    existing.add(url)
d['callbackURLs'] = ['regexp=(' + '|'.join(sorted(existing)) + ')']
print(json.dumps(d))
")
        curl -sk -u admin:admin -X PUT "${IS_HOST}/api/server/v1/applications/$IS_APP_ID/inbound-protocols/oidc" \
            -H "Content-Type: application/json" \
            -d "$UPDATED_OIDC" > /dev/null
        echo -e " ${GREEN}Done.${NC}"
    fi

    # Inject OBO credentials into admin agent config (Admin Agent now handles OBO, not Orchestrator)
    printf "  - Injecting OBO credentials into admin agent config..."
    ADMIN_AGENT_CONFIG="${DIR}/Config.docker.adminagent.toml"
    if [ -f "$ADMIN_AGENT_CONFIG" ]; then
        python3 -c "
import sys
agent_id = sys.argv[1]
agent_secret = sys.argv[2]
client_id = sys.argv[3]
with open(sys.argv[4], 'r') as f:
    content = f.read()
content = content.replace('agentId=\"\"', 'agentId=\"' + agent_id + '\"')
content = content.replace('agentSecret=\"\"', 'agentSecret=\"' + agent_secret + '\"')
content = content.replace('appClientId=\"\"', 'appClientId=\"' + client_id + '\"')
with open(sys.argv[4], 'w') as f:
    f.write(content)
" "$AGENT_ID" "$AGENT_PASSWORD" "$CONSUMER_KEY" "$ADMIN_AGENT_CONFIG"
    fi
    echo -e " ${GREEN}Done.${NC}"

    # Restart admin-agent to pick up OBO credentials (stop+rm+up to reload volume-mounted config)
    printf "  - Restarting admin-agent to apply OBO config..."
    docker compose -f "${DIR}/docker-compose.yml" stop admin-agent >/dev/null 2>&1 || true
    docker compose -f "${DIR}/docker-compose.yml" rm -f admin-agent >/dev/null 2>&1 || true
    docker compose -f "${DIR}/docker-compose.yml" up -d admin-agent >/dev/null 2>&1 || true
    echo -e " ${GREEN}Done.${NC}"
else
    echo -e " ${YELLOW}Warning: Could not register AI Agent. OBO flow will be disabled.${NC}"
    echo "  (This requires WSO2 IS 7.2.0+ with SCIM2 Agents support)"
fi

# ── Register Customer Service AI Agent in Identity Server ─────────────────────
echo ""
echo "============================================================"
echo "= REGISTERING CS AI AGENT (OBO FLOW)"
echo "============================================================"
echo ""

CS_AGENT_PASSWORD="CSAgentSecret@123"

printf "= Creating CS AI Agent identity in IS (SCIM2)..."
CS_AGENT_RESP=$(curl -sk -X POST "${IS_HOST}/scim2/Agents" \
    -u admin:admin \
    -H "Content-Type: application/json" \
    -d '{
        "schemas": ["urn:scim:wso2:agent:schema"],
        "userName": "cs-ai-assistant",
        "password": "'"${CS_AGENT_PASSWORD}"'",
        "displayName": "Customer Service AI Assistant"
    }')

CS_AGENT_ID=$(echo "$CS_AGENT_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || echo "")

if [ -n "$CS_AGENT_ID" ]; then
    echo -e " ${GREEN}Done.${NC} (CS Agent ID: $CS_AGENT_ID)"
else
    # Agent may already exist — look it up
    EXISTING_CS=$(curl -sk -u admin:admin "${IS_HOST}/scim2/Agents?filter=userName+eq+cs-ai-assistant")
    CS_AGENT_ID=$(echo "$EXISTING_CS" | python3 -c "import sys,json; d=json.load(sys.stdin); r=d.get('Resources',[]); print(r[0]['id'] if r else '')" 2>/dev/null || echo "")
    if [ -n "$CS_AGENT_ID" ]; then
        echo -e " ${YELLOW}Already exists.${NC} (CS Agent ID: $CS_AGENT_ID)"
    else
        echo -e " ${RED}Failed.${NC}"
        echo "  DEBUG: $CS_AGENT_RESP"
    fi
fi

if [ -n "$CS_AGENT_ID" ]; then
    # Inject OBO credentials into CS agent config
    printf "  - Injecting OBO credentials into CS agent config..."
    CS_AGENT_CONFIG="${DIR}/Config.docker.csagent.toml"
    if [ -f "$CS_AGENT_CONFIG" ]; then
        python3 -c "
import sys
agent_id = sys.argv[1]
agent_secret = sys.argv[2]
client_id = sys.argv[3]
with open(sys.argv[4], 'r') as f:
    content = f.read()
content = content.replace('agentId=\"\"', 'agentId=\"' + agent_id + '\"')
content = content.replace('agentSecret=\"\"', 'agentSecret=\"' + agent_secret + '\"')
content = content.replace('appClientId=\"\"', 'appClientId=\"' + client_id + '\"')
with open(sys.argv[4], 'w') as f:
    f.write(content)
" "$CS_AGENT_ID" "$CS_AGENT_PASSWORD" "$CONSUMER_KEY" "$CS_AGENT_CONFIG"
    fi
    echo -e " ${GREEN}Done.${NC}"

    # Restart CS agent to pick up OBO credentials
    printf "  - Restarting CS agent to apply OBO config..."
    docker compose -f "${DIR}/docker-compose.yml" stop cs-agent >/dev/null 2>&1 || true
    docker compose -f "${DIR}/docker-compose.yml" rm -f cs-agent >/dev/null 2>&1 || true
    docker compose -f "${DIR}/docker-compose.yml" up -d cs-agent >/dev/null 2>&1 || true
    echo -e " ${GREEN}Done.${NC}"
else
    echo -e " ${YELLOW}Warning: Could not register CS AI Agent. OBO flow will be disabled for CS agent.${NC}"
fi
# ── Update Dashboard .env with Client ID ──────────────────────────────────────
if [ -n "$CONSUMER_KEY" ]; then
    echo ""
    printf "= Updating dashboard with OAuth2 client ID..."
    # Write the client ID to a file that the dashboard entrypoint will pick up
    # We inject it via docker exec into the running container's nginx config
    docker exec adr-dashboard sh -c "cat > /usr/share/nginx/html/auth-config.js << 'JSEOF'
window.__AUTH_CONFIG__ = {
    clientID: \"$CONSUMER_KEY\",
    baseUrl: \"https://localhost:9444\",
    signInRedirectURL: \"http://localhost:3000\",
    signOutRedirectURL: \"http://localhost:3000\",
    scope: [\"openid\", \"email\", \"profile\", \"roles\", \"groups\", \"adr:flights:read\", \"adr:flights:write\", \"adr:recovery:manage\", \"adr:crew:read\", \"adr:passenger:read\", \"adr:logistics:read\"],
    gatewayUrl: \"https://localhost:8246\",
    endpoints: {
        authorizationEndpoint: \"https://localhost:9444/oauth2/authorize\",
        tokenEndpoint: \"http://localhost:3000/is/oauth2/token\",
        endSessionEndpoint: \"http://localhost:3000/is/oidc/logout\",
        jwksUri: \"http://localhost:3000/is/oauth2/jwks\",
        revocationEndpoint: \"http://localhost:3000/is/oauth2/revoke\",
        userinfoEndpoint: \"http://localhost:3000/is/oauth2/userinfo\"
    }
};
JSEOF" 2>/dev/null || true
    echo -e " ${GREEN}Done.${NC}"
fi

echo ""
echo "============================================================"
echo "= ALL API OPERATIONS COMPLETE"
echo "============================================================"
echo ""
echo "  APIM Publisher : ${APIM_HOST}/publisher"
echo "  APIM DevPortal : ${APIM_HOST}/devportal"
echo "  IS Console     : ${IS_HOST}/console"
echo ""
echo "  ADR Dashboard  : http://localhost:3000"
echo ""
echo "  Demo Users:"
echo "    adr_admin    / Admin@123"
echo "    adr_operator / Operator@123"
echo ""
echo "  OBO (On-Behalf-Of) Flow:"
echo "    AI Agent callback : http://localhost:9095/ai/callback"
echo "    CS Agent callback : http://localhost:9097/cs/callback"
echo "    Agent health      : http://localhost:9095/ai/health"
echo "    CS Agent health   : http://localhost:9097/cs/health"
echo ""
if [ -n "$INTERNAL_KEY" ]; then
echo "  APIM AI Gateway ApiKey (for testing):"
echo "    $INTERNAL_KEY"
echo ""
fi
if [ -n "$MCP_SERVER_ID" ]; then
echo "  MCP Server Proxy (via APIM):"
echo "    MCP Endpoint (HTTPS): https://localhost:8246/adr-mcp/1.0.0/mcp"
echo "    MCP Endpoint (HTTP) : http://localhost:8283/adr-mcp/1.0.0/mcp"
echo "    MCP Server ID       : $MCP_SERVER_ID"
echo ""
fi
echo "  APIs available via Gateway (HTTP) :"
echo "    DisruptionDetection : http://localhost:8283/disruption/1.0.0/"
echo "    CrewService           : http://localhost:8283/crew/1.0.0/"
echo "    PassengerService      : http://localhost:8283/passenger/1.0.0/"
echo "    LogisticsService      : http://localhost:8283/logistics/1.0.0/"
echo "    ADROrchestrator     : http://localhost:8283/adr/1.0.0/"
echo "    AIAgent             : http://localhost:8283/ai-agent/1.0.0/"
echo "    CSAgent             : http://localhost:8283/cs-agent/1.0.0/"
echo "    OllamaAI (AI API)   : http://localhost:8283/ollama/1.0.0/"
echo "    ADR MCP Server      : http://localhost:8283/adr-mcp/1.0.0/mcp"
echo ""
echo "  APIs available via Gateway (HTTPS):"
echo "    DisruptionDetection : https://localhost:8246/disruption/1.0.0/"
echo "    CrewService           : https://localhost:8246/crew/1.0.0/"
echo "    PassengerService      : https://localhost:8246/passenger/1.0.0/"
echo "    LogisticsService      : https://localhost:8246/logistics/1.0.0/"
echo "    ADROrchestrator     : https://localhost:8246/adr/1.0.0/"
echo "    AIAgent             : https://localhost:8246/ai-agent/1.0.0/"
echo "    CSAgent             : https://localhost:8246/cs-agent/1.0.0/"
echo "    OllamaAI (AI API)   : https://localhost:8246/ollama/1.0.0/"
echo "    ADR MCP Server      : https://localhost:8246/adr-mcp/1.0.0/mcp"
echo ""
