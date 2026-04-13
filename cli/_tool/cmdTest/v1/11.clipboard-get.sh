#!/bin/bash
# 정상: clipboard get 상세 조회
$CLI clipboard get 1
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
