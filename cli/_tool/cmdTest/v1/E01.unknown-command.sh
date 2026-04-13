#!/bin/bash
# 에러: 존재하지 않는 커맨드 (expect exit=2)
$CLI nosuchcommand 2>&1
RC=$?
if [ $RC -eq 2 ]; then echo "✅ PASS (exit=$RC, expected=2)"; else echo "❌ FAIL (exit=$RC, expected=2)"; fi
exit 0
