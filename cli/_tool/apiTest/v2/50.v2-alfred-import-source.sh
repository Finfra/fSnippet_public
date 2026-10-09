#!/bin/bash
# alfred-import source path GET / PUT
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "GET source (original)" 200 GET /settings/advanced/alfred-import
expect_jq "has sourcePath" 'has("sourcePath")'
ORIG=$(echo "$API_BODY" | jq -r '.sourcePath // empty')
expect_status "PUT tmp source" 200 PUT /settings/advanced/alfred-import '{"sourcePath":"/tmp/_apitest.alfdb"}'
expect_status "GET source (after)" 200 GET /settings/advanced/alfred-import
expect_jq "sourcePath == tmp" '.sourcePath == "/tmp/_apitest.alfdb"'
# the API rejects an empty sourcePath, so an originally-empty value cannot be restored
if [ -n "$ORIG" ]; then
    expect_status "PUT source (restore)" 200 PUT /settings/advanced/alfred-import "{\"sourcePath\":\"$ORIG\"}"
fi
api_finish
