#!/bin/bash
# ERROR CASE: 잘못된 ID 형식 (expect 400)
BASE="http://localhost:3015/api/v1"
curl -s --connect-timeout 3 "$BASE/clipboard/history/not_a_number" | jq .
