#!/bin/bash
# GET /status (Issue92 v2 health check)
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET /status" 200 GET /status
expect_jq "ok and status=ok" '.ok==true and .data.status=="ok"'
api_finish
