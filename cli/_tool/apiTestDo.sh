#!/bin/bash
# cli/_tool/apiTestDo.sh - apiTest/apiTestDo.sh wrapper
# Usage:
#   source cli/_tool/apiTestDo.sh        # 전체 실행
#   source cli/_tool/apiTestDo.sh 0      # 단건 실행

REAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/apiTest" && pwd)"
source "$REAL_DIR/apiTestDo.sh" "$@"
