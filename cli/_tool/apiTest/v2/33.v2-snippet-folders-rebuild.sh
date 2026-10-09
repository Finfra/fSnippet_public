#!/bin/bash
# POST /settings/snippet-folders/_emoji/rebuild (202 accepted)
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
api_call GET /settings/snippet-folders/_emoji
if [ "$API_STATUS" = "404" ]; then
    api_skip "_emoji folder absent on this data root"
elif [ "$API_STATUS" != "200" ]; then
    _api_fail "GET _emoji: HTTP $API_STATUS (want 200 or 404)"
else
    expect_status "POST rebuild" 202 POST /settings/snippet-folders/_emoji/rebuild
    expect_jq "status == accepted" '.data.status == "accepted"'
fi
api_finish
