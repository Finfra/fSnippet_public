#!/bin/bash
# lib.sh - assertion helpers for apiTest/v2/*.sh (Issue258).
# A case script sources this, calls expect_* for each check, and ends with api_finish.
# api_finish prints one verdict line that apiTestDo.sh parses; a script that never prints it
# (or exits early) is counted as a failure, so a case can no longer pass by merely running.
#
# Contract is covered by tdd #10 (api/test-api.sh); these helpers only assert per-case
# HTTP status and key fields of the response.

API_BASE="http://localhost:${FSC_API_PORT:-3015}/api/v2"
API_PASS=0
API_FAIL=0
API_SKIP=0
API_STATUS=""
API_BODY=""

_api_ok()   { API_PASS=$((API_PASS + 1)); echo "  ✔ $1"; }
_api_fail() { API_FAIL=$((API_FAIL + 1)); echo "  ❌ FAIL: $1"; }

# api_skip <reason> - the precondition is absent (e.g. no _emoji folder); reported, never silent
api_skip() { API_SKIP=$((API_SKIP + 1)); echo "  ⚠ SKIP: $1"; }

# api_call <METHOD> <path> [json-body] - sets API_STATUS / API_BODY (status 000 = no response)
api_call() {
    local method="$1" path="$2" body="${3:-}" out
    local args=(-s --connect-timeout 3 -m 15 -X "$method" -w $'\n%{http_code}')
    [ -n "$body" ] && args+=(-H "Content-Type: application/json" -d "$body")
    out=$(curl "${args[@]}" "$API_BASE$path" 2>/dev/null)
    API_STATUS="${out##*$'\n'}"
    API_BODY="${out%$'\n'*}"
}

# expect_status <label> <expected-code> <METHOD> <path> [json-body]
expect_status() {
    local label="$1" want="$2"
    api_call "$3" "$4" "${5:-}"
    if [ "$API_STATUS" = "$want" ]; then
        _api_ok "$label (HTTP $API_STATUS)"
    else
        _api_fail "$label: HTTP $API_STATUS (want $want) body=$(echo "$API_BODY" | head -c 200)"
    fi
}

# expect_jq <label> <jq-filter> - the filter must evaluate true against the last response body
expect_jq() {
    if echo "$API_BODY" | jq -e "$2" >/dev/null 2>&1; then
        _api_ok "$1"
    else
        _api_fail "$1: jq '$2' false on body=$(echo "$API_BODY" | head -c 200)"
    fi
}

# api_finish - print the verdict line and exit non-zero on any failure
api_finish() {
    echo "APITEST_RESULT pass=$API_PASS fail=$API_FAIL skip=$API_SKIP"
    [ "$API_FAIL" -eq 0 ] && [ $((API_PASS + API_SKIP)) -gt 0 ]
    exit $?
}
