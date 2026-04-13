#!/bin/bash
# PATCH /api/v2/settings/popup — popupRows 범위 초과 (400 invalid_argument 기대)
BASE="http://localhost:3015/api/v2"
curl -s --connect-timeout 3 -X PATCH \
  -H "Content-Type: application/json" \
  -d '{"popupRows": 9999}' \
  "$BASE/settings/popup" | jq .
