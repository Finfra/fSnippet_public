#!/bin/bash
# destructive actions reject a missing/wrong confirm token
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "reset-settings wrong confirm" 403 POST /settings/actions/reset-settings '{"confirm":"no"}'
expect_jq "error.code == forbidden" '.error.code == "forbidden"'
expect_status "reset-snippets no body" 400 POST /settings/actions/reset-snippets
expect_status "factory-reset empty object" 400 POST /settings/actions/factory-reset '{}'
api_finish
