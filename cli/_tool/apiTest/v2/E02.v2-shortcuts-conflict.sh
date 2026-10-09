#!/bin/bash
# assigning an already-used token -> 409
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
SC='{"keyCode":null,"modifiers":[],"display":"⌃⇧⌘0","token":"⌃⇧⌘0"}'
expect_status "PUT settingsHotkey (setup)" 200 PUT /settings/shortcuts/settingsHotkey "$SC"
expect_status "PUT viewerHotkey same token" 409 PUT /settings/shortcuts/viewerHotkey "$SC"
expect_jq "error.code == conflict" '.error.code == "conflict"'
expect_status "PUT settingsHotkey (restore)" 200 PUT /settings/shortcuts/settingsHotkey '{"keyCode":null,"modifiers":[],"display":"^⇧⌘;","token":"^⇧⌘;"}'
api_finish
