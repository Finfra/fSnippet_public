#!/bin/bash
# 정상: --help 글로벌 도움말 출력
$CLI --help
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
