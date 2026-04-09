#!/bin/bash
# cli/_tool/cmdTestDo.sh - cmdTest/cmdTestDo.sh wrapper
# Usage:
#   source cli/_tool/cmdTestDo.sh        # 전체 실행
#   source cli/_tool/cmdTestDo.sh 0      # 단건 실행

REAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/cmdTest" && pwd)"
source "$REAL_DIR/cmdTestDo.sh" "$@"
