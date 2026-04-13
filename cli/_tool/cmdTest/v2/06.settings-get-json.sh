#!/bin/bash
# 정상: settings get --json 출력 (jq 파싱 가능 확인)
OUTPUT=$($CLI settings get --json 2>/dev/null)
RC=$?
if [ $RC -ne 0 ]; then echo "❌ FAIL (exit=$RC)"; exit $RC; fi
# JSON 파싱 검증
echo "$OUTPUT" | python3 -c "import sys,json; json.load(sys.stdin); print('JSON 파싱 OK')" 2>/dev/null
PARSE_RC=$?
if [ $PARSE_RC -eq 0 ]; then echo "✅ PASS (exit=$RC, JSON valid)"; else echo "❌ FAIL (JSON parse error)"; exit 1; fi
exit 0
