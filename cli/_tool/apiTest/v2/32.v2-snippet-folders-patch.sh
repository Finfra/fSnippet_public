#!/bin/bash
# PATCH suffix — _rule.yml 반영 후 자동 복구
BASE="http://localhost:3015/api/v2"
ORIG=$(curl -s "$BASE/settings/snippet-folders/_emoji" | jq -r .suffix)
echo "== 원본 suffix: $ORIG =="
echo "== PATCH suffix=',{right_command}' =="
curl -s -X PATCH -H "Content-Type: application/json" \
  -d '{"suffix":",{right_command}"}' \
  "$BASE/settings/snippet-folders/_emoji" | jq .
echo "== 복구 =="
curl -s -X PATCH -H "Content-Type: application/json" \
  -d "{\"suffix\":\"$ORIG\"}" \
  "$BASE/settings/snippet-folders/_emoji" | jq .
