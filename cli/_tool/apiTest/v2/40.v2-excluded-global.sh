#!/bin/bash
# global excluded files: list / add / remove
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
TEMP="apitest-$$.md"
expect_status "GET global list" 200 GET /settings/advanced/excluded-files/global
expect_jq "list is an array" 'type=="array"'
expect_status "POST $TEMP" 201 POST /settings/advanced/excluded-files/global/entries "{\"filename\":\"$TEMP\"}"
expect_status "GET global list (after add)" 200 GET /settings/advanced/excluded-files/global
expect_jq "list contains $TEMP" "any(.[]; . == \"$TEMP\")"
expect_status "DELETE $TEMP" 204 DELETE "/settings/advanced/excluded-files/global/entries/$TEMP"
api_finish
