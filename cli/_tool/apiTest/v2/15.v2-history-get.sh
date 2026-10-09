#!/bin/bash
# GET /settings/history
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET /settings/history" 200 GET /settings/history
expect_jq "historyEnabledPlainText is a boolean" '(.historyEnabledPlainText|type)=="boolean"'
api_finish
