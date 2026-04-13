#!/bin/bash
# 에러: 존재하지 않는 스니펫 ID (expect exit=1)
$CLI snippet get 999999 2>&1
RC=$?
if [ $RC -eq 1 ]; then echo "✅ PASS (exit=$RC, expected=1)"; else echo "❌ FAIL (exit=$RC, expected=1)"; fi
exit 0
