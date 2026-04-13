#!/bin/bash
# GET + PATCH /api/v2/settings/advanced/performance
BASE="http://localhost:3015/api/v2"
echo "== GET =="
curl -s --connect-timeout 3 "$BASE/settings/advanced/performance" | jq .
echo "== PATCH (keyBufferSize=200) =="
curl -s --connect-timeout 3 -X PATCH \
  -H "Content-Type: application/json" \
  -d '{"keyBufferSize": 200}' \
  "$BASE/settings/advanced/performance" | jq .
