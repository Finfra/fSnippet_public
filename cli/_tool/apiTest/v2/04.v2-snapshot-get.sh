#!/bin/bash
# GET /settings/snapshot
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET /settings/snapshot" 200 GET /settings/snapshot
expect_jq "snapshot has advanced section" 'has("advanced")'
api_finish
