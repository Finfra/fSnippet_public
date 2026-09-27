#!/bin/bash
BASE="http://localhost:${FSC_API_PORT:-3015}/api/v2"
curl -s --connect-timeout 3 "$BASE/settings/general" | jq .
