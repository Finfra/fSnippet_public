#!/bin/bash
# 정상: config --json JSON 형식 출력
OUTPUT=$($CLI config --json 2>&1)
RC=$?
echo "$OUTPUT"
echo "$OUTPUT" | jq . > /dev/null 2>&1
JQ_RC=$?
if [ $RC -eq 0 ] && [ $JQ_RC -eq 0 ]; then echo "✅ PASS (exit=$RC, json=valid)"; else echo "❌ FAIL (exit=$RC, json=$JQ_RC)"; fi
exit $RC
