#!/bin/bash
# Usage:
#   bash test-api.sh [--server=<url>]
#
# Arguments:
#   --server=<url> : (optional) API server URL (default: http://localhost:3015)
#
# Examples:
#   bash test-api.sh
#   bash test-api.sh --server=http://192.168.0.10:3015

set -euo pipefail

BASE_URL="http://localhost:3015"

for arg in "$@"; do
  case "$arg" in
    --server=*) BASE_URL="${arg#--server=}" ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

# Server health check before running tests
echo "Checking server connectivity..."
if ! curl -sf "${BASE_URL}/" > /dev/null 2>&1; then
  echo "ERROR: Cannot connect to server at ${BASE_URL}"
  echo "Please ensure fSnippet is running with REST API enabled."
  exit 1
fi
echo "Server is reachable. Starting tests..."
echo ""

PASS=0
FAIL=0
TOTAL=0

test_endpoint() {
  local description="$1"
  local method="$2"
  local url="$3"
  local expected_status="$4"
  local body="${5:-}"
  local check_field="${6:-}"

  TOTAL=$((TOTAL + 1))

  if [ "$method" = "POST" ] && [ -n "$body" ]; then
    response=$(curl -s -w "\n%{http_code}" -X POST "$url" \
      -H "Content-Type: application/json" \
      -d "$body" 2>/dev/null) || true
  else
    response=$(curl -s -w "\n%{http_code}" "$url" 2>/dev/null) || true
  fi

  status_code=$(echo "$response" | tail -1)
  response_body=$(echo "$response" | sed '$d')

  if [ -z "$status_code" ]; then
    FAIL=$((FAIL + 1))
    echo "  FAIL [$TOTAL] $description (no response - server may be down)"
    return
  fi

  if [ "$status_code" = "$expected_status" ]; then
    if [ -n "$check_field" ] && ! echo "$response_body" | grep -q "$check_field"; then
      FAIL=$((FAIL + 1))
      echo "  FAIL [$TOTAL] $description (status=$status_code, missing: $check_field)"
      return
    fi
    PASS=$((PASS + 1))
    echo "  PASS [$TOTAL] $description (status=$status_code)"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL [$TOTAL] $description (expected=$expected_status, got=$status_code)"
  fi
}

echo "================================================"
echo " fSnippet REST API Test"
echo " Server: $BASE_URL"
echo "================================================"
echo ""

# 1. Health Check
test_endpoint "Health Check (GET /)" \
  "GET" "$BASE_URL/" "200" "" '"status"'

# 2. Snippet Search
test_endpoint "Snippet Search (GET /api/snippets/search?q=test)" \
  "GET" "$BASE_URL/api/snippets/search?q=test" "200" "" '"success"'

# 3. Snippet Search - missing query
test_endpoint "Snippet Search - missing query (400)" \
  "GET" "$BASE_URL/api/snippets/search" "400"

# 4. Snippet Expand
test_endpoint "Snippet Expand (POST /api/snippets/expand)" \
  "POST" "$BASE_URL/api/snippets/expand" "200" \
  '{"abbreviation":"bb◊"}' '"expanded_text"'

# 5. Snippet Expand - invalid JSON
test_endpoint "Snippet Expand - invalid JSON (400)" \
  "POST" "$BASE_URL/api/snippets/expand" "400" \
  'not-json'

# 6. Snippet Expand - not found abbreviation
test_endpoint "Snippet Expand - not found (404)" \
  "POST" "$BASE_URL/api/snippets/expand" "404" \
  '{"abbreviation":"__nonexistent__"}' '"error"'

# 7. Snippet by Abbreviation - not found
test_endpoint "Snippet by Abbreviation - not found (404)" \
  "GET" "$BASE_URL/api/snippets/by-abbreviation/NONEXISTENT_ABBREV_12345" "404"

# 8. Snippet by ID - not found
test_endpoint "Snippet by ID - not found (404)" \
  "GET" "$BASE_URL/api/snippets/NONEXISTENT_ID_12345" "404"

# 9. Clipboard History
test_endpoint "Clipboard History (GET /api/clipboard/history)" \
  "GET" "$BASE_URL/api/clipboard/history?limit=5" "200" "" '"success"'

# 10. Clipboard Search
test_endpoint "Clipboard Search (GET /api/clipboard/search?q=test)" \
  "GET" "$BASE_URL/api/clipboard/search?q=test" "200" "" '"success"'

# 11. Clipboard Search - missing query
test_endpoint "Clipboard Search - missing query (400)" \
  "GET" "$BASE_URL/api/clipboard/search" "400"

# 12. Clipboard Detail - not found
test_endpoint "Clipboard Detail - not found (404)" \
  "GET" "$BASE_URL/api/clipboard/history/999999999" "404"

# 13. Folder List
test_endpoint "Folder List (GET /api/folders)" \
  "GET" "$BASE_URL/api/folders" "200" "" '"success"'

# 14. Folder Detail - not found
test_endpoint "Folder Detail - not found (404)" \
  "GET" "$BASE_URL/api/folders/NONEXISTENT_FOLDER_12345" "404"

# 15. Stats Top
test_endpoint "Stats Top (GET /api/stats/top)" \
  "GET" "$BASE_URL/api/stats/top?limit=5" "200" "" '"success"'

# 16. Stats History
test_endpoint "Stats History (GET /api/stats/history)" \
  "GET" "$BASE_URL/api/stats/history?limit=5" "200" "" '"success"'

# 17. Trigger Keys
test_endpoint "Trigger Keys (GET /api/triggers)" \
  "GET" "$BASE_URL/api/triggers" "200" "" '"success"'

# 18. 404 - Unknown path
test_endpoint "Unknown Path (404)" \
  "GET" "$BASE_URL/api/nonexistent" "404"

echo ""
echo "================================================"
echo " Results: $PASS passed, $FAIL failed (total: $TOTAL)"
echo "================================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
