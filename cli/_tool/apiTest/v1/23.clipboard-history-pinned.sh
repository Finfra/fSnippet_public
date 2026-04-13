#!/bin/bash
# 파라미터 검증: /clipboard/history?pinned=true (핀 필터)
BASE="http://localhost:3015/api/v1"
RESULT=$(curl -s --connect-timeout 3 "$BASE/clipboard/history?pinned=true&limit=5")
echo "$RESULT" | jq .
COUNT=$(echo "$RESULT" | jq '.meta.count // 0')
MISMATCH=$(echo "$RESULT" | jq -r '.data[] | select(.pinned != true) | .id' 2>/dev/null)
if [ -z "$MISMATCH" ]; then
  echo "✅ pinned=true 필터 정상 (${COUNT}건)"
else
  echo "❌ pinned 필터 불일치"
fi
