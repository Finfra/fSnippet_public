#!/bin/bash
# GET /api/v2/settings/snippet-folders/_emoji
BASE="http://localhost:3015/api/v2"
curl -s --connect-timeout 3 "$BASE/settings/snippet-folders/_emoji" | jq .
