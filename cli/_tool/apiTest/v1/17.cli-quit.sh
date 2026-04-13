#!/bin/bash
# WARNING: 이 스크립트는 fSnippetCli 앱을 종료시킵니다.
BASE="http://localhost:3015/api/v1"
curl -s --connect-timeout 3 -X POST "$BASE/cli/quit" \
  -H "X-Confirm: true" | jq .
