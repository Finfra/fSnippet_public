#!/bin/bash
# 정상: snippet expand abbreviation 확장 (첫 번째 스니펫의 abbreviation 동적 조회)
FIRST_ABBR=$($CLI snippet list --json 2>/dev/null | jq -r '.data[0].abbreviation // empty')
if [ -z "$FIRST_ABBR" ]; then
  echo "⏭️ SKIP - 스니펫 없음"
  exit 0
fi
$CLI snippet expand "$FIRST_ABBR"
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
