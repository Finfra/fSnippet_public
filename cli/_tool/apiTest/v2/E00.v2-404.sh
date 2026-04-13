#!/bin/bash
# v2 미구현 엔드포인트는 404 (Phase 1 read-only 외 범위)
BASE="http://localhost:3015/api/v2"
curl -s -o /dev/null -w "status=%{http_code}\n" --connect-timeout 3 "$BASE/settings/advanced/debug"
