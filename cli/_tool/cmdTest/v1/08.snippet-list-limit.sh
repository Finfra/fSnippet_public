#!/bin/bash
# 정상: snippet list --limit 결과 수 제한
$CLI snippet list --limit 3
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
