#!/bin/bash
# PATCH /settings/general triggerBias round trip
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET /settings/general (original)" 200 GET /settings/general
ORIG=$(echo "$API_BODY" | jq -c '.triggerBias // 0')
expect_status "PATCH triggerBias=5" 200 PATCH /settings/general '{"triggerBias": 5}'
expect_status "GET /settings/general (after)" 200 GET /settings/general
expect_jq "triggerBias == 5" '.triggerBias == 5'
expect_status "PATCH triggerBias (restore)" 200 PATCH /settings/general "{\"triggerBias\": $ORIG}"
api_finish
