#!/bin/bash
# 에러: 잘못된 옵션 (expect exit=2)
$CLI --unknown 2>&1
RC=$?
if [ $RC -eq 2 ]; then echo "✅ PASS (exit=$RC, expected=2)"; else echo "❌ FAIL (exit=$RC, expected=2)"; fi
exit 0
