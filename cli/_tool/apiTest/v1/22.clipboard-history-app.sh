#!/bin/bash
# 파라미터 검증: /clipboard/history?app=... (앱 필터)
BASE="http://localhost:3015/api/v1"
APP=$(curl -s --connect-timeout 3 "$BASE/clipboard/history?limit=1" | jq -r '.data[0].app_bundle // empty')
if [ -z "$APP" ]; then
  echo '{"error":"클립보드 없음 — 테스트 불가"}'; exit 1
fi
ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$APP', safe=''))")
RESULT=$(curl -s --connect-timeout 3 "$BASE/clipboard/history?app=$ENCODED&limit=5")
echo "$RESULT" | jq .
MISMATCH=$(echo "$RESULT" | jq -r ".data[] | select(.app_bundle != \"$APP\") | .app_bundle" 2>/dev/null)
if [ -z "$MISMATCH" ]; then
  echo "✅ app=$APP 필터 정상"
else
  echo "❌ app 필터 불일치: $MISMATCH"
fi
