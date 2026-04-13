#!/bin/bash
# GET /api/v2/settings/excluded-files/per-folder — 전체 맵 조회
BASE="http://localhost:3015/api/v2"
curl -s --connect-timeout 3 "$BASE/settings/excluded-files/per-folder" | jq .
