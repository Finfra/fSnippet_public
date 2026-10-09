#!/bin/bash
# PATCH /settings/snippet-folders/_emoji suffix round trip
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
api_call GET /settings/snippet-folders/_emoji
if [ "$API_STATUS" = "404" ]; then
    api_skip "_emoji folder absent on this data root"
elif [ "$API_STATUS" != "200" ]; then
    _api_fail "GET _emoji: HTTP $API_STATUS (want 200 or 404)"
else
    ORIG=$(echo "$API_BODY" | jq -r '.suffix // empty')
    expect_status "PATCH suffix" 200 PATCH /settings/snippet-folders/_emoji '{"suffix":",{right_command}"}'
    expect_status "GET _emoji (after)" 200 GET /settings/snippet-folders/_emoji
    expect_jq "suffix == ,{right_command}" '.suffix == ",{right_command}"'
    if [ -n "$ORIG" ]; then
        expect_status "PATCH suffix (restore)" 200 PATCH /settings/snippet-folders/_emoji "{\"suffix\":\"$ORIG\"}"
    fi
fi
api_finish
