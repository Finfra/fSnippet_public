#!/bin/bash
# GET /settings/snippet-folders/{folder} (_emoji, else the first listed folder)
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
api_call GET /settings/snippet-folders
F=$(echo "$API_BODY" | jq -r 'if any(.[]?; .folder=="_emoji") then "_emoji" else (.[0].folder // empty) end')
if [ -z "$F" ]; then
    api_skip "no snippet folder on this data root"
else
    expect_status "GET /settings/snippet-folders/$F" 200 GET "/settings/snippet-folders/$F"
    expect_jq "folder == $F" ".folder == \"$F\""
fi
api_finish
