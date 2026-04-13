#!/bin/bash
# GET /api/v2/settings/snippet-folders — 폴더+규칙 전체 목록
BASE="http://localhost:3015/api/v2"
curl -s --connect-timeout 3 "$BASE/settings/snippet-folders" | jq 'length, .[0]'
