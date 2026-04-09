#!/bin/bash
# 정상: clipboard list 히스토리 목록
$CLI clipboard list
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
