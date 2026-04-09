#!/bin/bash
# ERROR CASE: X-Confirm 헤더 누락 (expect 400)
BASE="http://localhost:3015/api/v1"
curl -s --connect-timeout 3 -X POST "$BASE/cli/quit" | jq .
