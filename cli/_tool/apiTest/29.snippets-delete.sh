#!/bin/bash
# 스니펫 삭제 테스트 (DELETE /api/v1/snippets/{id})
# 먼저 임시 폴더+스니펫을 생성하고 스니펫 삭제 후 폴더도 정리
BASE="http://localhost:3015/api/v1"
FOLDER_NAME="_ApiTestDel2_$(date +%s)"
SNIPPET_FILE="tst===api test delete.txt"
SNIPPET_ID="$FOLDER_NAME/$SNIPPET_FILE"

echo "--- 테스트 폴더 생성: $FOLDER_NAME ---"
curl -s --connect-timeout 3 -X POST "$BASE/folders" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$FOLDER_NAME\"}" | jq .
echo ""

echo "--- 테스트 스니펫 생성 ---"
curl -s --connect-timeout 3 -X POST "$BASE/snippets" \
  -H "Content-Type: application/json" \
  -d "{\"folder\":\"$FOLDER_NAME\",\"keyword\":\"tst\",\"name\":\"api test delete\",\"content\":\"Delete me\"}" | jq .
echo ""

echo "--- 스니펫 삭제: $SNIPPET_ID ---"
ENCODED_ID=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$SNIPPET_ID', safe=''))")
curl -s --connect-timeout 3 -X DELETE "$BASE/snippets/$ENCODED_ID" | jq .
echo ""

echo "--- 테스트 폴더 정리 ---"
curl -s --connect-timeout 3 -X DELETE "$BASE/folders/$FOLDER_NAME" | jq .
