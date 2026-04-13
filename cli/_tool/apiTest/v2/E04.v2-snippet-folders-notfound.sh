#!/bin/bash
# GET 404 — 존재하지 않는 폴더
BASE="http://localhost:3015/api/v2"
curl -s --connect-timeout 3 -w "\nHTTP=%{http_code}\n" \
  "$BASE/settings/snippet-folders/NoSuchFolder"
