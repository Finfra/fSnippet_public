#!/bin/bash
set -e
BASE="http://localhost:3015/api/v2"

# Get current value
echo "📖 현재 일반 설정 조회..."
CURRENT=$(curl -s --connect-timeout 3 "$BASE/settings/general" | jq '.triggerBias // 0')
echo "현재 triggerBias: $CURRENT"

# Update
echo "📝 triggerBias 변경 (5로) ..."
curl -s --connect-timeout 3 -X PATCH "$BASE/settings/general" \
  -H "Content-Type: application/json" \
  -d '{"triggerBias": 5}' | jq '.'

# Restore
echo "📝 원본값으로 복원 ($CURRENT) ..."
curl -s --connect-timeout 3 -X PATCH "$BASE/settings/general" \
  -H "Content-Type: application/json" \
  -d "{\"triggerBias\": $CURRENT}" | jq '.'

echo "✅ PATCH /settings/general 테스트 완료"
