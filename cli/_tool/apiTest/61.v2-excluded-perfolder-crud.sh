#!/bin/bash
# Per-folder excluded files — PUT / GET / POST entry / DELETE entry / DELETE folder
BASE="http://localhost:3015/api/v2"
F="_apitest_folder_$$"
echo "== PUT list --"
curl -s -X PUT -H "Content-Type: application/json" -d '["a.md","b.md"]' \
  "$BASE/settings/excluded-files/per-folder/$F" | jq .
echo "== GET one =="; curl -s "$BASE/settings/excluded-files/per-folder/$F" | jq .
echo "== POST entry c.md =="
curl -s -w "\nHTTP=%{http_code}\n" -X POST -H "Content-Type: application/json" \
  -d '{"filename":"c.md"}' \
  "$BASE/settings/excluded-files/per-folder/$F/entries"
echo "== DELETE entry a.md =="
curl -s -o /dev/null -w "HTTP=%{http_code}\n" -X DELETE \
  "$BASE/settings/excluded-files/per-folder/$F/entries/a.md"
echo "== DELETE folder =="
curl -s -o /dev/null -w "HTTP=%{http_code}\n" -X DELETE \
  "$BASE/settings/excluded-files/per-folder/$F"
