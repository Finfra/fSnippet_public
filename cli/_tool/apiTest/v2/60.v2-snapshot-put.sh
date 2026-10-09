#!/bin/bash
# PUT /settings/snapshot
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET snapshot" 200 GET /settings/snapshot
expect_jq "snapshot has version" 'has("version")'
SNAP="$API_BODY"
expect_status "PUT empty snapshot (nothing restored)" 200 PUT /settings/snapshot '{}'
expect_status "PUT exported snapshot back" 200 PUT /settings/snapshot "$SNAP"
api_finish
