#!/bin/bash
# GET /settings/shortcuts
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET /settings/shortcuts" 200 GET /settings/shortcuts
expect_jq "settingsHotkey entry has a token" '(.settingsHotkey.token|type)=="string"'
api_finish
