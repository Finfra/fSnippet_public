#!/bin/bash
# PATCH /settings/behavior showNotifications round trip
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET /settings/behavior (original)" 200 GET /settings/behavior
ORIG=$(echo "$API_BODY" | jq -c '.showNotifications')
expect_status "PATCH showNotifications" 200 PATCH /settings/behavior '{"showNotifications": false}'
expect_status "GET /settings/behavior (after)" 200 GET /settings/behavior
expect_jq "showNotifications updated" '.showNotifications == false'
# restore the original value so later cases see the state they started with
if [ "$ORIG" != "null" ]; then
    expect_status "PATCH showNotifications (restore)" 200 PATCH /settings/behavior "{\"showNotifications\": $ORIG}"
fi
api_finish
