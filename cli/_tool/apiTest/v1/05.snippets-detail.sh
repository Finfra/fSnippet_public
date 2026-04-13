#!/bin/bash
# 동적: 첫 번째 스니펫의 id로 상세 조회
BASE="http://localhost:3015/api/v1"
ID=$(curl -s --connect-timeout 3 "$BASE/snippets?limit=1" | jq -r '.data[0].id // empty')
if [ -z "$ID" ]; then
  echo '{"error":"스니펫 없음 — 테스트 불가"}'; exit 1
fi
ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$ID', safe=''))")
curl -s --connect-timeout 3 "$BASE/snippets/$ENCODED" | jq .
