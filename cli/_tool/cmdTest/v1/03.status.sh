#!/bin/bash
# 정상: status 서비스 상태 확인
$CLI status
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
