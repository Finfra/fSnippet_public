#!/bin/bash
# POST /api/v2/settings/snippet-folders/_emoji/rebuild — 202 Accepted
BASE="http://localhost:3015/api/v2"
curl -s --connect-timeout 3 -w "\nHTTP=%{http_code}\n" \
  -X POST "$BASE/settings/snippet-folders/_emoji/rebuild"
