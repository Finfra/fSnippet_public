#!/bin/bash
# 에러: 존재하지 않는 settings section → exit 2 기대
$CLI settings get xyz_nonexistent 2>&1
RC=$?
if [ $RC -ne 0 ]; then echo "✅ PASS: 예상된 에러 (exit=$RC)"; else echo "❌ FAIL: 에러 없이 성공 (exit=$RC)"; fi
exit $([ $RC -ne 0 ] && echo 0 || echo 1)
