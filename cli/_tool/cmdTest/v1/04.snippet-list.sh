#!/bin/bash
# 정상: snippet list 스니펫 목록 조회
$CLI snippet list
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
