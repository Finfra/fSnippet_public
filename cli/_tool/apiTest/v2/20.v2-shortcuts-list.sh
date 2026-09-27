#!/bin/bash
# GET /api/v2/settings/shortcuts — 전 단축키 조회
BASE="http://localhost:${FSC_API_PORT:-3015}/api/v2"
curl -s --connect-timeout 3 "$BASE/settings/shortcuts" | jq .
