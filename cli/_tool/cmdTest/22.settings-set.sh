#!/bin/bash
# 정상: settings set popup.popupRows 변경 → 원복
ORIGINAL=$($CLI settings get popup --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('popupRows','8'))" 2>/dev/null || echo "8")
$CLI settings set popup.popupRows 9
RC=$?
# 원복
$CLI settings set popup.popupRows "$ORIGINAL" > /dev/null 2>&1
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
