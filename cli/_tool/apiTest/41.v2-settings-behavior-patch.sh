#!/bin/bash
# PATCH /api/v2/settings/behavior — showNotifications 토글
BASE="http://localhost:3015/api/v2"
curl -s --connect-timeout 3 -X PATCH \
  -H "Content-Type: application/json" \
  -d '{"showNotifications": true}' \
  "$BASE/settings/behavior" | jq .
