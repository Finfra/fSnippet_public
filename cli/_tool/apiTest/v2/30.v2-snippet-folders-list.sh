#!/bin/bash
# GET /settings/snippet-folders
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET /settings/snippet-folders" 200 GET /settings/snippet-folders
expect_jq "response is an array" 'type=="array"'
if [ "$(echo "$API_BODY" | jq 'length')" -gt 0 ]; then
    expect_jq "first entry has folder name" '(.[0].folder|type)=="string"'
else
    api_skip "snippet-folders list is empty on this data root"
fi
api_finish
