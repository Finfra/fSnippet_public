#!/bin/bash
# undefined v2 endpoint -> 404 (Issue91: /settings/advanced/debug is implemented, so use a truly undefined path)
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET undefined endpoint" 404 GET /nonexistent-endpoint
expect_jq "error.code == NOT_FOUND" '.ok == false and .error.code == "NOT_FOUND"'
api_finish
