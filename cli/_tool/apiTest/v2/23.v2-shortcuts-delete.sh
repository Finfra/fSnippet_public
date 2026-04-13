#!/bin/bash
# DELETE /api/v2/settings/shortcuts/togglePreviewHotkey — 단축키 해제 (204)
BASE="http://localhost:3015/api/v2"
curl -s --connect-timeout 3 -o /dev/null -w "HTTP=%{http_code}\n" -X DELETE \
  "$BASE/settings/shortcuts/togglePreviewHotkey"
