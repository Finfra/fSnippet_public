#!/bin/bash
# 파라미터 검증: /clipboard/history?kind=plain_text (kind 필터)
BASE="http://localhost:3015/api/v1"
RESULT=$(curl -s --connect-timeout 3 "$BASE/clipboard/history?kind=plain_text&limit=5")
echo "$RESULT" | jq .
MISMATCH=$(echo "$RESULT" | jq -r '.data[] | select(.kind != "plain_text") | .kind' 2>/dev/null)
if [ -z "$MISMATCH" ]; then
  echo "✅ kind=plain_text 필터 정상"
else
  echo "❌ kind 필터 불일치: $MISMATCH"
fi
