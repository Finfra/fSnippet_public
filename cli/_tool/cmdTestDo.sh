#!/bin/bash
# cli/_tool/cmdTestDo.sh - cmdTest/cmdTestDo.sh wrapper
# Usage:
#   source cli/_tool/cmdTestDo.sh              # v1 전체 (기본)
#   source cli/_tool/cmdTestDo.sh v1           # v1만
#   source cli/_tool/cmdTestDo.sh v2           # v2만
#   source cli/_tool/cmdTestDo.sh all          # v1 + v2 전체
#   source cli/_tool/cmdTestDo.sh 5            # v1/05.*.sh 실행
#   source cli/_tool/cmdTestDo.sh v2 3         # v2/03.*.sh 실행
#   source cli/_tool/cmdTestDo.sh v1 E         # v1 에러 전체
#   source cli/_tool/cmdTestDo.sh v2 E01       # v2/E01.*.sh 실행

REAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/cmdTest" && pwd)"
source "$REAL_DIR/cmdTestDo.sh" "$@"
