#!/bin/bash
# 에러: 존재하지 않는 스니펫 삭제 시도 (404 기대)
BASE="http://localhost:3015/api/v1"
FAKE_ID="NonExistent%2Ffake%3D%3D%3Dnothing.txt"
echo "--- 존재하지 않는 스니펫 삭제 (404 기대) ---"
curl -s --connect-timeout 3 -X DELETE "$BASE/snippets/$FAKE_ID" | jq .
