#!/bin/bash
# 정상: clipboard search 검색
$CLI clipboard search test
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
