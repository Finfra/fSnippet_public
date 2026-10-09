#!/bin/bash
# unknown shortcut name -> 404
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET unknown shortcut" 404 GET /settings/shortcuts/nonexistent
api_finish
