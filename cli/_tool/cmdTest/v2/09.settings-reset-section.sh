#!/bin/bash
# 정상: settings reset popup (섹션 전체 리셋)
# 주의: 이 테스트는 popup 설정 전체를 기본값으로 초기화함
# 사전 백업
BACKUP=$($CLI settings get popup --json 2>/dev/null)
$CLI settings reset popup
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
echo "⚠️  popup 설정이 기본값으로 초기화됨"
exit $RC
