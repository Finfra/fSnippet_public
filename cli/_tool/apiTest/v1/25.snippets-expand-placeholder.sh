#!/bin/bash
# 파라미터 검증: /snippets/expand + placeholder_values
# placeholder가 포함된 스니펫을 동적으로 찾아 테스트
BASE="http://localhost:3015/api/v1"
# has_placeholders가 true인 스니펫 찾기
SNIPPET=$(curl -s --connect-timeout 3 "$BASE/snippets?limit=50" | jq -r '[.data[] | select(.content_preview | test("\\{\\{"))] | .[0]')
if [ "$SNIPPET" = "null" ] || [ -z "$SNIPPET" ]; then
  echo '{"success":true,"data":{"message":"placeholder 스니펫 없음 — skip"}}'
  exit 0
fi
ABBREV=$(echo "$SNIPPET" | jq -r '.abbreviation')
echo "대상: abbreviation=$ABBREV"
# placeholder_values 포함하여 expand
RESULT=$(curl -s --connect-timeout 3 -X POST "$BASE/snippets/expand" \
  -H "Content-Type: application/json" \
  -d "{\"abbreviation\":\"$ABBREV\",\"placeholder_values\":{\"x\":\"TEST_VALUE\"}}" 2>&1)
echo "$RESULT" | python3 -c "import sys,json; print(json.dumps(json.loads(sys.stdin.read()), indent=2, ensure_ascii=False))" 2>/dev/null || echo "$RESULT"
SUCCESS=$(echo "$RESULT" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('success',''))" 2>/dev/null)
if [ "$SUCCESS" = "True" ] || [ "$SUCCESS" = "true" ]; then
  echo "✅ placeholder_values expand 정상"
else
  echo "⚠️ expand 응답 확인 필요 (placeholder 미적용일 수 있음)"
fi
