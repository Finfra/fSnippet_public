#!/bin/bash
# PATCH /api/v2/settings/popup — popupRows 변경
BASE="http://localhost:3015/api/v2"
curl -s --connect-timeout 3 -X PATCH \
  -H "Content-Type: application/json" \
  -d '{"popupRows": 12}' \
  "$BASE/settings/popup" | jq .
