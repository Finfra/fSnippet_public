#!/bin/bash
# 정상: settings set behavior.pasteMode 변경 → 원복
ORIGINAL=$($CLI settings get behavior --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('pasteMode','direct'))" 2>/dev/null || echo "direct")
$CLI settings set behavior.pasteMode direct
RC=$?
# 원복
$CLI settings set behavior.pasteMode "$ORIGINAL" > /dev/null 2>&1
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
