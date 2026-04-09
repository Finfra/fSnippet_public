#!/bin/bash
# 파라미터 검증: /snippets?folder=Aa (폴더 필터)
BASE="http://localhost:3015/api/v1"
FOLDER=$(curl -s --connect-timeout 3 "$BASE/folders" | jq -r '.data[0].name // empty')
if [ -z "$FOLDER" ]; then
  echo '{"error":"폴더 없음 — 테스트 불가"}'; exit 1
fi
RESULT=$(curl -s --connect-timeout 3 "$BASE/snippets?folder=$FOLDER&limit=5")
echo "$RESULT" | jq .
# 모든 결과의 folder가 지정한 값인지 검증
MISMATCH=$(echo "$RESULT" | jq -r ".data[] | select(.folder != \"$FOLDER\") | .folder" 2>/dev/null)
if [ -z "$MISMATCH" ]; then
  echo "✅ folder 필터 정상"
else
  echo "❌ folder 필터 불일치: $MISMATCH"
fi
