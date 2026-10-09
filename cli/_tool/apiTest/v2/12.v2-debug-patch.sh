#!/bin/bash
# PATCH /settings/advanced/debug logLevel round trip
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET /settings/advanced/debug (original)" 200 GET /settings/advanced/debug
ORIG=$(echo "$API_BODY" | jq -c '.logLevel')
expect_status "PATCH logLevel" 200 PATCH /settings/advanced/debug '{"logLevel": "warning"}'
expect_status "GET /settings/advanced/debug (after)" 200 GET /settings/advanced/debug
expect_jq "logLevel updated" '.logLevel == "warning"'
# restore the original value so later cases see the state they started with
if [ "$ORIG" != "null" ]; then
    expect_status "PATCH logLevel (restore)" 200 PATCH /settings/advanced/debug "{\"logLevel\": $ORIG}"
fi
api_finish
