#!/bin/bash
# PATCH /settings/advanced/input forceSearchInputLanguage
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET /settings/advanced/input" 200 GET /settings/advanced/input
expect_jq "response is an object" 'type=="object"'
expect_status "PATCH forceSearchInputLanguage" 200 PATCH /settings/advanced/input '{"forceSearchInputLanguage": "U.S."}'
expect_status "GET /settings/advanced/input (after)" 200 GET /settings/advanced/input
expect_jq "forceSearchInputLanguage == U.S." '.forceSearchInputLanguage == "U.S."'
api_finish
