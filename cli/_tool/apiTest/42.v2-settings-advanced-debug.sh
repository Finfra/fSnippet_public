#!/bin/bash
# GET + PATCH /api/v2/settings/advanced/debug
BASE="http://localhost:3015/api/v2"
echo "== GET =="
curl -s --connect-timeout 3 "$BASE/settings/advanced/debug" | jq .
echo "== PATCH (logLevel=debug) =="
curl -s --connect-timeout 3 -X PATCH \
  -H "Content-Type: application/json" \
  -d '{"logLevel": "debug"}' \
  "$BASE/settings/advanced/debug" | jq .
