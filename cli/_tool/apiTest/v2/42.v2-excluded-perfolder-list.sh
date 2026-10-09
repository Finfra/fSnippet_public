#!/bin/bash
# GET /settings/excluded-files/per-folder
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET /settings/excluded-files/per-folder" 200 GET /settings/excluded-files/per-folder
expect_jq "response is an object" 'type=="object"'
api_finish
