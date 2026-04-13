#!/bin/bash
# 정상: -v 단축 버전 출력
$CLI -v
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
