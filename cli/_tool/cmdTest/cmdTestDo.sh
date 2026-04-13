#!/bin/bash
# cmdTestDo.sh - CLI 커맨드 테스트 실행기 (v1/v2 분리 지원)
# Usage:
#   bash cli/_tool/cmdTest/cmdTestDo.sh              # v1 전체 (기본)
#   bash cli/_tool/cmdTest/cmdTestDo.sh v1           # v1만
#   bash cli/_tool/cmdTest/cmdTestDo.sh v2           # v2만
#   bash cli/_tool/cmdTest/cmdTestDo.sh all          # v1 + v2 전체
#   bash cli/_tool/cmdTest/cmdTestDo.sh 5            # v1/05.*.sh 실행
#   bash cli/_tool/cmdTest/cmdTestDo.sh v2 3         # v2/03.*.sh 실행
#   bash cli/_tool/cmdTest/cmdTestDo.sh v1 E         # v1 에러 전체
#   bash cli/_tool/cmdTest/cmdTestDo.sh v2 E01       # v2/E01.*.sh 실행

# source 호환: BASH_SOURCE 우선, fallback으로 $0
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# CLI 바이너리 경로 (환경변수 또는 자동 탐지)
if [ -z "$CLI" ]; then
  # 1) Homebrew 경로
  if [ -x "/opt/homebrew/opt/fsnippetcli/fSnippetCli.app/Contents/MacOS/fSnippetCli" ]; then
    export CLI="/opt/homebrew/opt/fsnippetcli/fSnippetCli.app/Contents/MacOS/fSnippetCli"
  # 2) DerivedData Release 빌드
  elif DERIVED=$(find ~/Library/Developer/Xcode/DerivedData -name "fSnippetCli" -path "*/Release/*.app/Contents/MacOS/*" -type f 2>/dev/null | head -1) && [ -n "$DERIVED" ]; then
    export CLI="$DERIVED"
  # 3) DerivedData Debug 빌드
  elif DERIVED=$(find ~/Library/Developer/Xcode/DerivedData -name "fSnippetCli" -path "*/Debug/*.app/Contents/MacOS/*" -type f 2>/dev/null | head -1) && [ -n "$DERIVED" ]; then
    export CLI="$DERIVED"
  else
    echo "❌ fSnippetCli 바이너리를 찾을 수 없음. CLI 환경변수를 설정하세요."
    echo "   export CLI=/path/to/fSnippetCli.app/Contents/MacOS/fSnippetCli"
    return 1 2>/dev/null || exit 1
  fi
fi

echo "📍 CLI: $CLI"
echo

run_normal() {
  local dir="$1"
  local pass=0 fail=0 total=0
  for f in $(ls "$dir"/[0-9]*.sh 2>/dev/null \
    | awk -F'/' '{print $NF" "$0}' | sort -V | awk '{print $2}'); do
    total=$((total + 1))
    echo "=== $(basename "$f") ==="
    bash "$f"
    if [ $? -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
    echo
  done
  echo "==============================="
  echo "결과: 전체=$total  성공=$pass  실패=$fail"
  echo "==============================="
}

run_error() {
  local dir="$1"
  local pass=0 fail=0 total=0
  for f in $(ls "$dir"/E*.sh 2>/dev/null | sort); do
    total=$((total + 1))
    echo "=== $(basename "$f") ==="
    bash "$f"
    if [ $? -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
    echo
  done
  echo "==============================="
  echo "결과: 전체=$total  성공=$pass  실패=$fail"
  echo "==============================="
}

run_single() {
  local dir="$1"
  local arg="$2"
  local ver="$3"
  # E 에러 케이스 전체
  if [ "$arg" = "E" ] || [ "$arg" = "e" ]; then
    run_error "$dir"
    return
  fi
  # E01 등 특정 에러
  if [[ "$arg" =~ ^E[0-9] ]]; then
    MATCHED=$(ls "$dir"/"$arg".*.sh 2>/dev/null)
    if [ -z "$MATCHED" ]; then
      echo "❌ [$ver] $arg.*.sh 를 찾을 수 없음"
      return 1
    fi
    echo "=== [$ver] $(basename "$MATCHED") ==="
    bash "$MATCHED"
    return
  fi
  # 숫자 → 00 패딩
  NUM=$(printf '%02d' "$arg" 2>/dev/null)
  MATCHED=$(ls "$dir"/"$NUM".*.sh 2>/dev/null)
  if [ -z "$MATCHED" ]; then
    echo "❌ [$ver] $NUM.*.sh 를 찾을 수 없음"
    return 1
  fi
  echo "=== [$ver] $(basename "$MATCHED") ==="
  bash "$MATCHED"
}

# 인자 파싱
VERSION="${1:-v1}"
TEST_ARG="${2:---all}"

# v1/v2/all 이외 값이 버전으로 넘어온 경우 처리
if [[ ! "$VERSION" =~ ^(v1|v2|all)$ ]]; then
  TEST_ARG="$VERSION"
  VERSION="v1"
fi

if [ "$VERSION" = "all" ]; then
  echo "📋 v1 정상 테스트..."
  run_normal "$SCRIPT_DIR/v1"
  echo ""
  echo "📋 v1 에러 테스트..."
  run_error "$SCRIPT_DIR/v1"
  echo ""
  echo "📋 v2 정상 테스트..."
  run_normal "$SCRIPT_DIR/v2"
  echo ""
  echo "📋 v2 에러 테스트..."
  run_error "$SCRIPT_DIR/v2"
else
  BASE="$SCRIPT_DIR/$VERSION"
  if [ ! -d "$BASE" ]; then
    echo "❌ $BASE 디렉터리 없음"
    return 1 2>/dev/null || exit 1
  fi
  if [ "$TEST_ARG" = "--all" ]; then
    run_normal "$BASE"
    echo ""
    echo "📋 에러 케이스..."
    run_error "$BASE"
  else
    run_single "$BASE" "$TEST_ARG" "$VERSION"
  fi
fi
