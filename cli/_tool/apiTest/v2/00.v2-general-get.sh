#!/bin/bash
# GET /settings/general
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET /settings/general" 200 GET /settings/general
expect_jq "has language and permissions" 'has("language") and has("permissions")'
api_finish
