#!/bin/bash
# 동적: 첫 번째 폴더명으로 상세 조회
BASE="http://localhost:3015/api/v1"
FOLDER=$(curl -s --connect-timeout 3 "$BASE/folders" | jq -r '.data[0].name // empty')
if [ -z "$FOLDER" ]; then
  echo '{"error":"폴더 없음 — 테스트 불가"}'; exit 1
fi
ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$FOLDER', safe=''))")
curl -s --connect-timeout 3 "$BASE/folders/$ENCODED" | jq .
