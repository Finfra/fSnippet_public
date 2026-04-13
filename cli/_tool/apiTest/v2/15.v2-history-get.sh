#!/bin/bash
set -e
BASE="http://localhost:3015/api/v2"

echo "📖 히스토리 설정 조회..."
curl -s --connect-timeout 3 "$BASE/settings/history" | jq '.'

echo ""
echo "✅ GET /settings/history 테스트 완료"
