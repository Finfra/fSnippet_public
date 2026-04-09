#!/bin/bash
# 스니펫 생성 테스트 (POST /api/v1/snippets)
# 먼저 임시 폴더를 생성하고 그 안에 스니펫 생성
BASE="http://localhost:3015/api/v1"
FOLDER_NAME="_ApiTestSnip_$(date +%s)"
echo "--- 테스트 폴더 생성: $FOLDER_NAME ---"
curl -s --connect-timeout 3 -X POST "$BASE/folders" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$FOLDER_NAME\"}" | jq .
echo ""
echo "--- 스니펫 생성 ---"
curl -s --connect-timeout 3 -X POST "$BASE/snippets" \
  -H "Content-Type: application/json" \
  -d "{\"folder\":\"$FOLDER_NAME\",\"keyword\":\"tst\",\"name\":\"api test snippet\",\"content\":\"Hello from API test\"}" | jq .
