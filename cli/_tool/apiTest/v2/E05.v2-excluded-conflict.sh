#!/bin/bash
# global excluded: duplicate -> 409, missing -> 404
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
TEMP="apitest-err-$$.md"
expect_status "POST $TEMP (setup)" 201 POST /settings/advanced/excluded-files/global/entries "{\"filename\":\"$TEMP\"}"
expect_status "POST duplicate" 409 POST /settings/advanced/excluded-files/global/entries "{\"filename\":\"$TEMP\"}"
expect_status "DELETE non-existent" 404 DELETE "/settings/advanced/excluded-files/global/entries/nothing-$$.txt"
expect_status "DELETE $TEMP (cleanup)" 204 DELETE "/settings/advanced/excluded-files/global/entries/$TEMP"
api_finish
