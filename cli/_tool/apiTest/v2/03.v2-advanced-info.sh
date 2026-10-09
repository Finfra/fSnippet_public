#!/bin/bash
# GET /settings/advanced/info
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET /settings/advanced/info" 200 GET /settings/advanced/info
expect_jq "appVersion is a non-empty string" '(.appVersion|type)=="string" and (.appVersion|length)>0'
api_finish
