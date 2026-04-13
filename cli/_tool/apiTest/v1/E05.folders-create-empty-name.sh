#!/bin/bash
# 에러: 빈 이름으로 폴더 생성 시도 (400 기대)
BASE="http://localhost:3015/api/v1"
echo "--- 빈 이름 폴더 생성 (400 기대) ---"
curl -s --connect-timeout 3 -X POST "$BASE/folders" \
  -H "Content-Type: application/json" \
  -d '{"name":""}' | jq .
