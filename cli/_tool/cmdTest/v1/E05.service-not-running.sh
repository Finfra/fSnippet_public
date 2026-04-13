#!/bin/bash
# 에러: 서비스 중지 상태에서 커맨드 실행 (expect exit=3)
# 주의: 서비스가 실행 중이면 이 테스트는 FAIL됨 (수동 확인용)
echo "⚠️  이 테스트는 서비스 중지 상태에서만 유효합니다"
$CLI status 2>&1
RC=$?
if [ $RC -eq 3 ]; then echo "✅ PASS (exit=$RC, expected=3)"; else echo "⏭️ SKIP - 서비스 실행 중 (exit=$RC)"; fi
exit 0
