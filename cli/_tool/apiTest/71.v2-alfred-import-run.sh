#!/bin/bash
# POST /api/v2/settings/advanced/alfred-import/run — 비동기 잡 시작 (202 + jobId)
# 실제 임포트는 백그라운드. 여기서는 HTTP 코드만 검증.
BASE="http://localhost:3015/api/v2"
curl -s -w "\nHTTP=%{http_code}\n" -X POST \
  "$BASE/settings/advanced/alfred-import/run"
