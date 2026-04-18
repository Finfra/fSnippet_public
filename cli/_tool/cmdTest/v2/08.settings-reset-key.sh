#!/bin/bash
# 정상: settings reset popup.popupRows (단일 키 리셋)
# 현재 값 저장
ORIGINAL=$($CLI settings get popup --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('popupRows','8'))" 2>/dev/null || echo "8")
# 값 변경 후 리셋
$CLI settings set popup.popupRows 5 > /dev/null 2>&1
$CLI settings reset popup.popupRows
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
# 원래 값이 달랐다면 복원
if [ "$ORIGINAL" != "$(defaults read kr.finfra.fSnippetCli popupRows 2>/dev/null)" ]; then
  $CLI settings set popup.popupRows "$ORIGINAL" > /dev/null 2>&1
fi
exit $RC
