#!/bin/bash
# ERROR CASE: 존재하지 않는 스니펫 ID (expect 404)
BASE="http://localhost:3015/api/v1"
curl -s --connect-timeout 3 "$BASE/snippets/NONEXISTENT_ID_12345" | jq .
