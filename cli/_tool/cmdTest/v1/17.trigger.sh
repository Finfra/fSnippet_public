#!/bin/bash
# 정상: trigger 트리거 키 정보
$CLI trigger
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
