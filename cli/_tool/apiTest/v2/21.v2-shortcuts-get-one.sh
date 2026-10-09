#!/bin/bash
# GET /settings/shortcuts/settingsHotkey
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET /settings/shortcuts/settingsHotkey" 200 GET /settings/shortcuts/settingsHotkey
expect_jq "token is a non-empty string" '(.token|type)=="string" and (.token|length)>0'
api_finish
