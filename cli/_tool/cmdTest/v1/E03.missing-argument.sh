#!/bin/bash
# 에러: 인자 누락 - snippet search에 쿼리 없음 (expect exit=2)
$CLI snippet search 2>&1
RC=$?
if [ $RC -eq 2 ]; then echo "✅ PASS (exit=$RC, expected=2)"; else echo "❌ FAIL (exit=$RC, expected=2)"; fi
exit 0
