#!/bin/bash
# 정상: folder list 폴더 목록
$CLI folder list
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
