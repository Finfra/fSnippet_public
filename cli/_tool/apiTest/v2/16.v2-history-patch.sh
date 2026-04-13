#!/bin/bash
set -e
BASE="http://localhost:3015/api/v2"

echo "📝 히스토리 설정 수정 시도..."
curl -s --connect-timeout 3 -X PATCH "$BASE/settings/history" \
  -H "Content-Type: application/json" \
  -d '{"viewer": {"showStatusBar": false}}' | jq '.'

echo ""
echo "✅ PATCH /settings/history 테스트 완료"
