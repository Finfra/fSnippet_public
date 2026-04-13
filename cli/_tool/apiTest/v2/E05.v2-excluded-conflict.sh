#!/bin/bash
# 409 duplicate + 404 not-found 복합 검증 (global)
BASE="http://localhost:3015/api/v2"
TEMP="apitest-err-$$.md"
curl -s -o /dev/null -X POST -H "Content-Type: application/json" \
  -d "{\"filename\":\"$TEMP\"}" \
  "$BASE/settings/advanced/excluded-files/global/entries"
echo "== POST duplicate → 409 =="
curl -s -w "\nHTTP=%{http_code}\n" -X POST -H "Content-Type: application/json" \
  -d "{\"filename\":\"$TEMP\"}" \
  "$BASE/settings/advanced/excluded-files/global/entries"
echo "== DELETE non-existent → 404 =="
curl -s -w "\nHTTP=%{http_code}\n" -X DELETE \
  "$BASE/settings/advanced/excluded-files/global/entries/nothing-$$.txt"
# 정리
curl -s -o /dev/null -X DELETE \
  "$BASE/settings/advanced/excluded-files/global/entries/$TEMP"
