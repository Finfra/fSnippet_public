#!/bin/bash
# GET /settings/behavior
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET /settings/behavior" 200 GET /settings/behavior
expect_jq "launchAtLogin is a boolean" '(.launchAtLogin|type)=="boolean"'
api_finish
