#!/bin/bash
# ERROR CASE: q 파라미터 누락 (expect 400)
BASE="http://localhost:3015/api/v1"
curl -s --connect-timeout 3 "$BASE/snippets/search" | jq .
