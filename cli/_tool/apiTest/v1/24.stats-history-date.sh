#!/bin/bash
# 파라미터 검증: /stats/history?from=...&to=... (날짜 범위)
BASE="http://localhost:3015/api/v1"
FROM="2026-01-01T00:00:00Z"
TO="2026-12-31T23:59:59Z"
RESULT=$(curl -s --connect-timeout 3 "$BASE/stats/history?from=$FROM&to=$TO&limit=5")
echo "$RESULT" | jq .
SUCCESS=$(echo "$RESULT" | jq -r '.success // false')
if [ "$SUCCESS" = "true" ]; then
  echo "✅ from/to 날짜 범위 필터 정상"
else
  echo "❌ from/to 필터 실패"
fi
