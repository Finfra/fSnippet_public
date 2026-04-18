#!/bin/bash
# 정상: settings set general.triggerKey 변경 → 원복
# triggerKey 현재 값 저장
ORIGINAL=$($CLI settings get --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('triggerKey','{right_command}'))" 2>/dev/null || echo "{right_command}")
$CLI settings set general.triggerKey "{right_command}"
RC=$?
# 원복
$CLI settings set general.triggerKey "$ORIGINAL" > /dev/null 2>&1
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
