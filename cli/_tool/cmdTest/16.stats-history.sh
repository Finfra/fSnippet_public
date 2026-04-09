#!/bin/bash
# 정상: stats history 사용 이력
$CLI stats history
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
