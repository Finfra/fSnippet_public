#!/bin/bash
# unknown snippet folder -> 404
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET unknown folder" 404 GET /settings/snippet-folders/NoSuchFolder
api_finish
