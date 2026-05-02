#!/bin/bash
# Issue92: v2 health check (/api/v2/status)
BASE="http://localhost:3015/api/v2"
curl -s --connect-timeout 3 "$BASE/status" | jq .
