#!/bin/bash
# GET 404 — 정의되지 않은 shortcut 이름
BASE="http://localhost:3015/api/v2"
curl -s -w "\nHTTP=%{http_code}\n" "$BASE/settings/shortcuts/nonexistent"
