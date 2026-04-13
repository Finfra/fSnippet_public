#!/bin/bash
# PUT /api/v2/settings/shortcuts/togglePreviewHotkey — 토큰 설정
BASE="http://localhost:3015/api/v2"
curl -s --connect-timeout 3 -X PUT \
  -H "Content-Type: application/json" \
  -d '{"keyCode":null,"modifiers":["control","option"],"display":"⌃⌥T","token":"⌃⌥T"}' \
  "$BASE/settings/shortcuts/togglePreviewHotkey" | jq .
