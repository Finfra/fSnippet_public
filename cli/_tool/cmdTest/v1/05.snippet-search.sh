#!/bin/bash
# 정상: snippet search 검색
$CLI snippet search docker
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
