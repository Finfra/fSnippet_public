#!/bin/bash
# Normal: clipboard get detail — look up an id that actually exists via `clipboard list` (Issue244 ③).
# A clean history (0 entries) has nothing to get → SKIP (77) instead of getting a non-existent id 1.
# A failing `clipboard list` is a FAIL, never a SKIP.
LIST=$($CLI clipboard list --limit 1 --json)
LRC=$?
if [ $LRC -ne 0 ]; then echo "❌ FAIL (clipboard list exit=$LRC)"; exit $LRC; fi
ID=$(printf '%s' "$LIST" | python3 -c 'import json,sys
d=json.load(sys.stdin).get("data") or []
print(d[0]["id"] if d else "")') || { echo "❌ FAIL (clipboard list: unparsable JSON)"; exit 1; }
if [ -z "$ID" ]; then echo "⏭️  SKIP (clipboard history empty)"; exit 77; fi
$CLI clipboard get "$ID"
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (id=$ID exit=$RC)"; else echo "❌ FAIL (id=$ID exit=$RC)"; fi
exit $RC
