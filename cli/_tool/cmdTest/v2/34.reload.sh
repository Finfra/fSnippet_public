#!/bin/bash
# 정상: reload 스니펫/규칙/설정 리로드
curl -s -X POST http://localhost:3015/api/v2/reload | python3 -m json.tool
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
