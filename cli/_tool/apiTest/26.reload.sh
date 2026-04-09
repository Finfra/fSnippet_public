#!/bin/bash
# 스니펫, 규칙, 설정 등을 런타임에 재로딩
BASE="http://localhost:3015/api/v1"
curl -s --connect-timeout 3 -X POST "$BASE/reload" | jq .
