#!/bin/bash
# PATCH /settings/popup popupRows round trip
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET /settings/popup (original)" 200 GET /settings/popup
ORIG=$(echo "$API_BODY" | jq -c '.popupRows')
expect_status "PATCH popupRows" 200 PATCH /settings/popup '{"popupRows": 12}'
expect_status "GET /settings/popup (after)" 200 GET /settings/popup
expect_jq "popupRows updated" '.popupRows == 12'
# restore the original value so later cases see the state they started with
if [ "$ORIG" != "null" ]; then
    expect_status "PATCH popupRows (restore)" 200 PATCH /settings/popup "{\"popupRows\": $ORIG}"
fi
api_finish
