#!/bin/bash
# Danger Zone — confirm guard (positive path 실행 금지)
# 잘못된 confirm / 빈 body / 누락 필드 에 대한 가드 동작만 검증.
BASE="http://localhost:3015/api/v2"
echo "== reset-settings wrong confirm (403) =="
curl -s -w "\nHTTP=%{http_code}\n" -X POST -H "Content-Type: application/json" \
  -d '{"confirm":"no"}' "$BASE/settings/actions/reset-settings"
echo "== reset-snippets no body (400) =="
curl -s -w "\nHTTP=%{http_code}\n" -X POST "$BASE/settings/actions/reset-snippets"
echo "== factory-reset empty body (400) =="
curl -s -w "\nHTTP=%{http_code}\n" -X POST -H "Content-Type: application/json" \
  -d '{}' "$BASE/settings/actions/factory-reset"
