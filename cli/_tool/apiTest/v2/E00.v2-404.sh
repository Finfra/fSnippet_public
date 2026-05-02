#!/bin/bash
# v2 undefined endpoint → must return 404 (default route fallback)
# Issue91: /settings/advanced/debug was implemented (Phase 4) → switched to a genuinely undefined path
BASE="http://localhost:3015/api/v2"
curl -s -o /dev/null -w "status=%{http_code}\n" --connect-timeout 3 "$BASE/nonexistent-endpoint"
