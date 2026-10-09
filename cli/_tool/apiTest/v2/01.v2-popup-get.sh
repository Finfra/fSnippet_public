#!/bin/bash
# GET /settings/popup
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET /settings/popup" 200 GET /settings/popup
expect_jq "popupRows is a number" '(.popupRows|type)=="number"'
api_finish
