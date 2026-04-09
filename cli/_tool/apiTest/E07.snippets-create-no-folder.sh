#!/bin/bash
# 에러: 존재하지 않는 폴더에 스니펫 생성 시도 (404 기대)
BASE="http://localhost:3015/api/v1"
echo "--- 존재하지 않는 폴더에 스니펫 생성 (404 기대) ---"
curl -s --connect-timeout 3 -X POST "$BASE/snippets" \
  -H "Content-Type: application/json" \
  -d '{"folder":"_NonExistentFolder_99999","keyword":"x","name":"test","content":"fail"}' | jq .
