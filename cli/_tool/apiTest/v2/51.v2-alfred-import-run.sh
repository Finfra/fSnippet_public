#!/bin/bash
# POST /settings/advanced/alfred-import/run (202 + jobId)
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
# prj5#Issue99: self-contained. The job reads the configured Alfred DB; on a machine without
# Alfred snippets (jma, a fresh jm4 test root) it failed with db_not_found and left an ERROR in
# flog_cliApp.log, which fsc-test.sh Step 11 then reported. Point the source at an empty
# fixture DB with the importer's schema for the duration of the run, then restore it.
FIXTURE="/tmp/_apitest_snippets_$$.alfdb"
rm -f "$FIXTURE"
sqlite3 "$FIXTURE" "CREATE TABLE snippets (uid TEXT, name TEXT, keyword TEXT, snippet TEXT, collection TEXT, autoexpand INTEGER);"

api_call GET /settings/advanced/alfred-import
ORIG=$(echo "$API_BODY" | jq -r '.sourcePath // empty')
expect_status "PUT fixture source" 200 PUT /settings/advanced/alfred-import "{\"sourcePath\":\"$FIXTURE\"}"
expect_status "POST run" 202 POST /settings/advanced/alfred-import/run
expect_jq "jobId is a non-empty string" '(.jobId|type)=="string" and (.jobId|length)>0'

# Let the background job open the fixture before the source is restored.
sleep 1
if [ -n "$ORIG" ]; then
    expect_status "PUT source (restore)" 200 PUT /settings/advanced/alfred-import "{\"sourcePath\":\"$ORIG\"}"
fi
rm -f "$FIXTURE"
api_finish
