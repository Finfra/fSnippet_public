#!/bin/bash
# PUT 충돌 (409): 두 이름에 동일 토큰을 연속 할당
BASE="http://localhost:3015/api/v2"
# 1단계: settingsHotkey 에 임시 토큰 설정
curl -s -o /dev/null -X PUT -H "Content-Type: application/json" \
  -d '{"keyCode":null,"modifiers":[],"display":"⌃⇧⌘0","token":"⌃⇧⌘0"}' \
  "$BASE/settings/shortcuts/settingsHotkey"
# 2단계: viewerHotkey 에 같은 토큰 → 409 기대
curl -s -w "\nHTTP=%{http_code}\n" -X PUT -H "Content-Type: application/json" \
  -d '{"keyCode":null,"modifiers":[],"display":"⌃⇧⌘0","token":"⌃⇧⌘0"}' \
  "$BASE/settings/shortcuts/viewerHotkey"
# 정리: settingsHotkey 복구
curl -s -o /dev/null -X PUT -H "Content-Type: application/json" \
  -d '{"keyCode":null,"modifiers":[],"display":"^⇧⌘;","token":"^⇧⌘;"}' \
  "$BASE/settings/shortcuts/settingsHotkey"
