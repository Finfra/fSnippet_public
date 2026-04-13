#!/bin/bash
# 정상: folder get 폴더 상세 (첫 번째 폴더명 동적 조회)
FIRST_FOLDER=$($CLI folder list --json 2>/dev/null | jq -r '.data[0].name // empty')
if [ -z "$FIRST_FOLDER" ]; then
  echo "⏭️ SKIP - 폴더 없음"
  exit 0
fi
$CLI folder get "$FIRST_FOLDER"
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
