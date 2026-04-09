#!/bin/bash
# 정상: snippet get 상세 조회 (첫 번째 스니펫 ID를 동적 조회)
FIRST_ID=$($CLI snippet list --json 2>/dev/null | jq -r '.data[0].id // empty')
if [ -z "$FIRST_ID" ]; then
  echo "⏭️ SKIP - 스니펫 없음"
  exit 0
fi
$CLI snippet get "$FIRST_ID"
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
