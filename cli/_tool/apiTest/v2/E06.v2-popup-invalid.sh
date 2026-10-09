#!/bin/bash
# PATCH /settings/popup popupRows out of range -> 400 invalid_argument
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "PATCH popupRows=9999" 400 PATCH /settings/popup '{"popupRows": 9999}'
expect_jq "error.code == invalid_argument" '.error.code == "invalid_argument"'
api_finish
