#!/bin/bash
# PATCH /settings/advanced/performance keyBufferSize round trip
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET /settings/advanced/performance (original)" 200 GET /settings/advanced/performance
ORIG=$(echo "$API_BODY" | jq -c '.keyBufferSize')
expect_status "PATCH keyBufferSize" 200 PATCH /settings/advanced/performance '{"keyBufferSize": 200}'
expect_status "GET /settings/advanced/performance (after)" 200 GET /settings/advanced/performance
expect_jq "keyBufferSize updated" '.keyBufferSize == 200'
# restore the original value so later cases see the state they started with
if [ "$ORIG" != "null" ]; then
    expect_status "PATCH keyBufferSize (restore)" 200 PATCH /settings/advanced/performance "{\"keyBufferSize\": $ORIG}"
fi
api_finish
