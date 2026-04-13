#!/bin/bash
# Global excluded files — GET / POST entry / DELETE entry (auto cleanup)
BASE="http://localhost:3015/api/v2"
TEMP="apitest-$$.md"
echo "== GET =="; curl -s "$BASE/settings/advanced/excluded-files/global" | jq .
echo "== POST $TEMP =="
curl -s -w "\nHTTP=%{http_code}\n" -X POST -H "Content-Type: application/json" \
  -d "{\"filename\":\"$TEMP\"}" \
  "$BASE/settings/advanced/excluded-files/global/entries"
echo "== DELETE $TEMP =="
curl -s -o /dev/null -w "HTTP=%{http_code}\n" -X DELETE \
  "$BASE/settings/advanced/excluded-files/global/entries/$TEMP"
