#!/bin/bash
BASE="http://localhost:3015/api/v2"
curl -s --connect-timeout 3 "$BASE/settings/popup" | jq .
