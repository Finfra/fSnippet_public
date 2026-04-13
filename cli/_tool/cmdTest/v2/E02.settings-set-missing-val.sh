#!/bin/bash
# 에러: settings set 에 값 누락 → exit 2 기대
$CLI settings set popup.popupRows 2>&1
RC=$?
if [ $RC -ne 0 ]; then echo "✅ PASS: 예상된 에러 (exit=$RC)"; else echo "❌ FAIL: 에러 없이 성공 (exit=$RC)"; fi
exit $([ $RC -ne 0 ] && echo 0 || echo 1)
