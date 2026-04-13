#!/bin/bash
# 에러: 비어있지 않은 폴더 삭제 시도 (409 기대)
# 동적: 첫 번째 폴더를 시도
BASE="http://localhost:3015/api/v1"
FOLDER=$(curl -s --connect-timeout 3 "$BASE/folders" | jq -r '.data[0].name // empty')
if [ -z "$FOLDER" ]; then
  echo '{"error":"폴더 없음 — 테스트 불가"}'; exit 1
fi
echo "--- 비어있지 않은 폴더 삭제 시도: $FOLDER (409 기대) ---"
curl -s --connect-timeout 3 -X DELETE "$BASE/folders/$FOLDER" | jq .
