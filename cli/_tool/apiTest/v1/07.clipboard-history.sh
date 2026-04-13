#!/bin/bash
BASE="http://localhost:3015/api/v1"
curl -s --connect-timeout 3 "$BASE/clipboard/history?limit=5" | jq .
