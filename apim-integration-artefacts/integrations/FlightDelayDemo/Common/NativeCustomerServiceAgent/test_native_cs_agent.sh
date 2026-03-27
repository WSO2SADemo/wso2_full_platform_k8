#!/bin/bash
# ============================================================================
# NativeCustomerServiceAgent — Manual Test & Validation Script
# ============================================================================
# Usage:
#   chmod +x test_native_cs_agent.sh
#   ./test_native_cs_agent.sh [PORT] [JWT_TOKEN]
#
# Defaults:
#   PORT=9098
#   JWT_TOKEN=<test token> (will skip auth-required tests if not provided)
# ============================================================================

set -euo pipefail

PORT="${1:-9098}"
JWT_TOKEN="${2:-}"
BASE_URL="http://localhost:${PORT}/cs"
PASS=0
FAIL=0
SKIP=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE} NativeCustomerServiceAgent Test Suite${NC}"
echo -e "${BLUE} Base URL: ${BASE_URL}${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# ── Helper Functions ────────────────────────────────────────────────────────

assert_status() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    if [ "$actual" -eq "$expected" ]; then
        echo -e "  ${GREEN}✓ PASS${NC} - $test_name (HTTP $actual)"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗ FAIL${NC} - $test_name (expected HTTP $expected, got HTTP $actual)"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    if echo "$actual" | grep -qi "$expected"; then
        echo -e "  ${GREEN}✓ PASS${NC} - $test_name (contains '$expected')"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗ FAIL${NC} - $test_name (missing '$expected')"
        echo -e "    Response: ${actual:0:200}"
        FAIL=$((FAIL + 1))
    fi
}

skip_test() {
    local test_name="$1"
    local reason="$2"
    echo -e "  ${YELLOW}○ SKIP${NC} - $test_name ($reason)"
    SKIP=$((SKIP + 1))
}

# ── Test 1: Service Reachability ────────────────────────────────────────────

echo -e "${BLUE}[1/8] Service Reachability${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/health" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "000" ]; then
    echo -e "  ${RED}✗ Service is not reachable at ${BASE_URL}${NC}"
    echo -e "  Make sure the service is running: cd NativeCustomerServiceAgent && bal run"
    echo ""
    echo -e "${RED}Cannot continue — service not running.${NC}"
    exit 1
fi
assert_status "Health endpoint reachable" 200 "$HTTP_CODE"
echo ""

# ── Test 2: Health Check Response Structure ─────────────────────────────────

echo -e "${BLUE}[2/8] Health Check Response${NC}"
HEALTH_RESPONSE=$(curl -s "${BASE_URL}/health")
assert_contains "Has 'status' field" "running" "$HEALTH_RESPONSE"
assert_contains "Has agent name" "Native Customer Service Agent" "$HEALTH_RESPONSE"
assert_contains "Has AI Agent mode" "AI Agent" "$HEALTH_RESPONSE"
assert_contains "Has mcp_tools field" "mcp_tools" "$HEALTH_RESPONSE"
assert_contains "Has mcp_enabled field" "mcp_enabled" "$HEALTH_RESPONSE"
assert_contains "Has agent_initialized field" "agent_initialized" "$HEALTH_RESPONSE"
assert_contains "Has obo_enabled field" "obo_enabled" "$HEALTH_RESPONSE"
echo -e "  Full response: ${HEALTH_RESPONSE:0:300}"
echo ""

# ── Test 3: Chat Without Authorization ──────────────────────────────────────

echo -e "${BLUE}[3/8] Chat Without Authorization${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${BASE_URL}/chat" \
    -H "Content-Type: application/json" \
    -d '{"message": "Show me all flights"}')
assert_status "Rejects request without auth" 401 "$HTTP_CODE"
echo ""

# ── Test 4: Chat With Invalid JWT ───────────────────────────────────────────

echo -e "${BLUE}[4/8] Chat With Invalid JWT${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "${BASE_URL}/chat" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer invalid_jwt_token" \
    -d '{"message": "Show me all flights"}')
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)
# Should be 403 (invalid JWT) or 401
if [ "$HTTP_CODE" -eq 403 ] || [ "$HTTP_CODE" -eq 401 ]; then
    echo -e "  ${GREEN}✓ PASS${NC} - Rejects invalid JWT (HTTP $HTTP_CODE)"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}✗ FAIL${NC} - Expected 401 or 403, got HTTP $HTTP_CODE"
    FAIL=$((FAIL + 1))
fi
echo ""

# ── Test 5: OBO Callback Without Params ─────────────────────────────────────

echo -e "${BLUE}[5/8] OBO Callback Without Params${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/callback")
assert_status "Callback rejects missing params" 400 "$HTTP_CODE"
echo ""

# ── Test 6: OBO Callback With Invalid State ─────────────────────────────────

echo -e "${BLUE}[6/8] OBO Callback With Invalid State${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/callback?code=fake&state=fake")
assert_status "Callback rejects invalid state" 500 "$HTTP_CODE"
echo ""

# ── Test 7: Chat With Valid JWT (if provided) ──────────────────────────────

echo -e "${BLUE}[7/8] Chat With Valid JWT${NC}"
if [ -n "$JWT_TOKEN" ]; then
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        --max-time 60 \
        -X POST "${BASE_URL}/chat" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${JWT_TOKEN}" \
        -d '{"message": "Show me all flights", "session_id": "test-session-001"}')
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | head -n -1)

    assert_status "Chat accepts valid JWT" 200 "$HTTP_CODE"
    assert_contains "Has response field" "response" "$BODY"
    assert_contains "Has session_id field" "session_id" "$BODY"
    echo -e "  Response preview: ${BODY:0:300}"
else
    skip_test "Chat with valid JWT" "No JWT_TOKEN provided as second argument"
fi
echo ""

# ── Test 8: Chat Session Continuity (if JWT provided) ──────────────────────

echo -e "${BLUE}[8/8] Chat Session Continuity${NC}"
if [ -n "$JWT_TOKEN" ]; then
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        --max-time 60 \
        -X POST "${BASE_URL}/chat" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${JWT_TOKEN}" \
        -d '{"message": "What disruptions are active?", "session_id": "test-session-001"}')
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | head -n -1)

    assert_status "Follow-up chat succeeds" 200 "$HTTP_CODE"
    assert_contains "Has response field" "response" "$BODY"
    echo -e "  Response preview: ${BODY:0:300}"
else
    skip_test "Session continuity" "No JWT_TOKEN provided as second argument"
fi
echo ""

# ── Summary ─────────────────────────────────────────────────────────────────

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE} Test Summary${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "  ${GREEN}Passed: ${PASS}${NC}"
echo -e "  ${RED}Failed: ${FAIL}${NC}"
echo -e "  ${YELLOW}Skipped: ${SKIP}${NC}"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. ✗${NC}"
    exit 1
fi
