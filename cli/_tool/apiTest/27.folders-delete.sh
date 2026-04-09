#!/bin/bash
# 폴더 삭제 테스트 (DELETE /api/v1/folders/{name})
# 먼저 임시 폴더를 생성하고 삭제
BASE="http://localhost:3015/api/v1"
FOLDER_NAME="_ApiTestDel_$(date +%s)"
echo "--- 폴더 생성 (삭제 테스트용) ---"
curl -s --connect-timeout 3 -X POST "$BASE/folders" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$FOLDER_NAME\"}" | jq .
echo ""
echo "--- 폴더 삭제: $FOLDER_NAME ---"
curl -s --connect-timeout 3 -X DELETE "$BASE/folders/$FOLDER_NAME" | jq .
