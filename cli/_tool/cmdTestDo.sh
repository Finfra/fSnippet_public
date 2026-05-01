#!/bin/bash
# cli/_tool/cmdTestDo.sh - cmdTest/cmdTestDo.sh wrapper (v2 전용, v1 deprecated)
# Usage:
#   source cli/_tool/cmdTestDo.sh              # v2 전체 (기본)
#   source cli/_tool/cmdTestDo.sh v2           # v2만
#   source cli/_tool/cmdTestDo.sh 5            # v2/05.*.sh 실행
#   source cli/_tool/cmdTestDo.sh v2 3         # v2/03.*.sh 실행
#   source cli/_tool/cmdTestDo.sh v2 E         # v2 에러 전체
#   source cli/_tool/cmdTestDo.sh v2 E01       # v2/E01.*.sh 실행

REAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/cmdTest" && pwd)"
source "$REAL_DIR/cmdTestDo.sh" "$@"
