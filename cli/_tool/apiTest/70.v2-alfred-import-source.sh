#!/bin/bash
# GET/PUT /api/v2/settings/advanced/alfred-import — sourcePath 조회/변경
BASE="http://localhost:3015/api/v2"
ORIG=$(curl -s "$BASE/settings/advanced/alfred-import" | jq -r .sourcePath)
echo "== GET (원본) =="; echo "$ORIG"
echo "== PUT tmp =="
curl -s -X PUT -H "Content-Type: application/json" \
  -d '{"sourcePath":"/tmp/_apitest.alfdb"}' \
  "$BASE/settings/advanced/alfred-import" | jq .
echo "== GET (확인) =="; curl -s "$BASE/settings/advanced/alfred-import" | jq .
# 원복
curl -s -o /dev/null -X PUT -H "Content-Type: application/json" \
  -d "{\"sourcePath\":\"$ORIG\"}" \
  "$BASE/settings/advanced/alfred-import"
