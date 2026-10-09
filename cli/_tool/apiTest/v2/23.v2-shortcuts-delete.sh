#!/bin/bash
# DELETE /settings/shortcuts/togglePreviewHotkey (204)
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
expect_status "DELETE togglePreviewHotkey" 204 DELETE /settings/shortcuts/togglePreviewHotkey
api_finish
