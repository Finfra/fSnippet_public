#!/bin/bash
# PUT /settings/shortcuts/togglePreviewHotkey
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "PUT togglePreviewHotkey" 200 PUT /settings/shortcuts/togglePreviewHotkey '{"keyCode":null,"modifiers":["control","option"],"display":"⌃⌥T","token":"⌃⌥T"}'
expect_status "GET togglePreviewHotkey (after)" 200 GET /settings/shortcuts/togglePreviewHotkey
expect_jq "token == ⌃⌥T" '.token == "⌃⌥T"'
api_finish
