#!/bin/bash
# 폴더 생성 테스트 (POST /api/v1/folders)
BASE="http://localhost:3015/api/v1"
FOLDER_NAME="_ApiTest_$(date +%s)"
echo "--- 폴더 생성: $FOLDER_NAME ---"
curl -s --connect-timeout 3 -X POST "$BASE/folders" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$FOLDER_NAME\"}" | jq .
