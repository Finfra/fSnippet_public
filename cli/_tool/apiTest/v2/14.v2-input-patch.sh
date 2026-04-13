#!/bin/bash
# GET + PATCH /api/v2/settings/advanced/input
BASE="http://localhost:3015/api/v2"
echo "== GET =="
curl -s --connect-timeout 3 "$BASE/settings/advanced/input" | jq .
echo "== PATCH (forceSearchInputLanguage=U.S.) =="
curl -s --connect-timeout 3 -X PATCH \
  -H "Content-Type: application/json" \
  -d '{"forceSearchInputLanguage": "U.S."}' \
  "$BASE/settings/advanced/input" | jq .
