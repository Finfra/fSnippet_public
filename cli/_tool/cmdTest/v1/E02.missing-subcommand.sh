#!/bin/bash
# 에러: 서브커맨드 누락 (expect exit=2)
$CLI snippet 2>&1
RC=$?
if [ $RC -eq 2 ]; then echo "✅ PASS (exit=$RC, expected=2)"; else echo "❌ FAIL (exit=$RC, expected=2)"; fi
exit 0
