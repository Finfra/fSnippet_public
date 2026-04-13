#!/bin/bash
# 파라미터 검증: /snippets/search?q=...&folder=Aa (폴더 필터 + 검색)
BASE="http://localhost:3015/api/v1"
FOLDER=$(curl -s --connect-timeout 3 "$BASE/folders" | jq -r '.data[0].name // empty')
KEYWORD=$(curl -s --connect-timeout 3 "$BASE/snippets?limit=10" | jq -r '[.data[] | select(.keyword != "")] | .[0].keyword // empty')
if [ -z "$FOLDER" ]; then
  echo '{"error":"폴더 없음 — 테스트 불가"}'; exit 1
fi
if [ -z "$KEYWORD" ]; then
  # keyword가 모두 빈 경우 description으로 대체
  KEYWORD=$(curl -s --connect-timeout 3 "$BASE/snippets?limit=1" | jq -r '.data[0].description // empty')
fi
if [ -z "$KEYWORD" ]; then
  echo '{"error":"검색어 추출 불가 — 테스트 불가"}'; exit 1
fi
RESULT=$(curl -s --connect-timeout 3 "$BASE/snippets/search?q=$KEYWORD&folder=$FOLDER&limit=5")
echo "$RESULT" | jq .
MISMATCH=$(echo "$RESULT" | jq -r ".data[] | select(.folder != \"$FOLDER\") | .folder" 2>/dev/null)
if [ -z "$MISMATCH" ]; then
  echo "✅ search + folder 필터 정상"
else
  echo "❌ folder 필터 불일치: $MISMATCH"
fi
