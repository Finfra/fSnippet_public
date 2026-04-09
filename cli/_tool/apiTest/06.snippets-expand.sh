#!/bin/bash
# 동적: 첫 번째 스니펫의 abbreviation으로 expand
BASE="http://localhost:3015/api/v1"
ABBREV=$(curl -s --connect-timeout 3 "$BASE/snippets?limit=1" | jq -r '.data[0].abbreviation // empty')
if [ -z "$ABBREV" ]; then
  echo '{"error":"스니펫 없음 — 테스트 불가"}'; exit 1
fi
curl -s --connect-timeout 3 -X POST "$BASE/snippets/expand" \
  -H "Content-Type: application/json" \
  -d "{\"abbreviation\":\"$ABBREV\"}" | jq .
