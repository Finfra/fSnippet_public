#!/bin/bash
# GET /api/v2/settings/snapshot + PUT snapshot cycle
BASE="http://localhost:3015/api/v2"
echo "== GET =="; curl -s "$BASE/settings/snapshot" | jq '.version, .exportedAt' | head -1
echo "== PUT (echo) =="; curl -s -w "HTTP=%{http_code}\n" -X PUT -H "Content-Type: application/json" \
  -d '{}' "$BASE/settings/snapshot" | head -1
echo "== PUT (valid) =="; \
  curl -s "$BASE/settings/snapshot" | \
  curl -s -w "HTTP=%{http_code}\n" -X PUT -H "Content-Type: application/json" -d @- \
  "$BASE/settings/snapshot"
