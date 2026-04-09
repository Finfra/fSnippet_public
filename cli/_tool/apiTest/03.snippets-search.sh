#!/bin/bash
# 동적: 첫 번째 스니펫의 keyword로 검색
BASE="http://localhost:3015/api/v1"
KEYWORD=$(curl -s --connect-timeout 3 "$BASE/snippets?limit=1" | jq -r '.data[0].keyword // empty')
if [ -z "$KEYWORD" ]; then
  echo '{"error":"스니펫 없음 — 테스트 불가"}'; exit 1
fi
curl -s --connect-timeout 3 "$BASE/snippets/search?q=$KEYWORD&limit=5" | jq .
