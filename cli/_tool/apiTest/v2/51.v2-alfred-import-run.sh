#!/bin/bash
# POST /api/v2/settings/advanced/alfred-import/run — 비동기 잡 시작 (202 + jobId)
# 실제 임포트는 백그라운드. 여기서는 HTTP 코드만 검증.
#
# prj5#Issue99: self-contained. The job reads the configured Alfred DB; on a machine without
# Alfred snippets (jma, a fresh jm4 test root) it failed with db_not_found and left an ERROR in
# flog_cliApp.log, which fsc-test.sh Step 11 then reported. Point the source at an empty
# fixture DB with the importer's schema for the duration of the run, then restore it.
BASE="http://localhost:${FSC_API_PORT:-3015}/api/v2"
FIXTURE="/tmp/_apitest_snippets_$$.alfdb"
rm -f "$FIXTURE"
sqlite3 "$FIXTURE" "CREATE TABLE snippets (uid TEXT, name TEXT, keyword TEXT, snippet TEXT, collection TEXT, autoexpand INTEGER);"

ORIG=$(curl -s "$BASE/settings/advanced/alfred-import" | jq -r .sourcePath)
curl -s -o /dev/null -X PUT -H "Content-Type: application/json" \
  -d "{\"sourcePath\":\"$FIXTURE\"}" \
  "$BASE/settings/advanced/alfred-import"

curl -s -w "\nHTTP=%{http_code}\n" -X POST \
  "$BASE/settings/advanced/alfred-import/run"

# Let the background job open the fixture before the source is restored.
sleep 1
curl -s -o /dev/null -X PUT -H "Content-Type: application/json" \
  -d "{\"sourcePath\":\"$ORIG\"}" \
  "$BASE/settings/advanced/alfred-import"
rm -f "$FIXTURE"
