#!/bin/bash
# PATCH /settings/history viewer.showStatusBar
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "PATCH viewer.showStatusBar=false" 200 PATCH /settings/history '{"viewer": {"showStatusBar": false}}'
api_finish
