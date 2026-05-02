#!/bin/bash
# apiTestDo.sh - API 테스트 실행기 (v2 전용, v1은 deprecated)
# Usage:
#   bash apiTestDo.sh         # v2 전체 (기본)
#   bash apiTestDo.sh v2      # v2만
#   bash apiTestDo.sh 5       # v2/05.*.sh 실행
#   bash apiTestDo.sh v2 5    # v2/05.*.sh 실행
#
# Issue93 — burst stability:
#   * Each test in --all mode is followed by APITEST_BURST_DELAY (default 0.05s)
#     to avoid HTTP=000 spikes seen on rapid consecutive requests.
#   * Override via env: APITEST_BURST_DELAY=0.1 bash apiTestDo.sh
#   * Set 0 to disable: APITEST_BURST_DELAY=0 bash apiTestDo.sh

# Burst delay between tests in --all mode (seconds). Default: 0.05
APITEST_BURST_DELAY="${APITEST_BURST_DELAY:-0.05}"

# source 호환
if [ -n "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# 인자 파싱
VERSION="${1:-v2}"
TEST_NUM="${2:---all}"

# v2 외의 값이 버전으로 넘어온 경우 처리
if [[ "$VERSION" = "v1" ]]; then
  echo "⚠️  v1은 deprecated (410 Gone). v2로 전환됨."
  VERSION="v2"
elif [[ "$VERSION" = "all" ]]; then
  echo "⚠️  all 옵션은 v1 deprecated로 v2만 실행됨."
  VERSION="v2"
elif [[ ! "$VERSION" =~ ^(v2)$ ]]; then
  TEST_NUM="$VERSION"
  VERSION="v2"
fi

run_version() {
  local ver="$1"
  local num="$2"

  local base_dir="$SCRIPT_DIR/$ver"

  if [ ! -d "$base_dir" ]; then
    echo "❌ $base_dir 디렉터리 없음"
    return 1
  fi

  if [ "$num" != "--all" ]; then
    # 특정 번호 실행
    NUM=$(printf '%02d' "$num" 2>/dev/null)
    MATCHED=$(ls "$base_dir"/"$NUM".*.sh 2>/dev/null)
    if [ -z "$MATCHED" ]; then
      echo "❌ $ver/$NUM.*.sh 를 찾을 수 없음"
      return 1
    fi
    echo "=== [$ver] $(basename "$MATCHED") ==="
    bash "$MATCHED"
  else
    # 전체 실행
    for f in $(ls "$base_dir"/[0-9]*.sh "$base_dir"/E*.sh 2>/dev/null \
      | grep -v '/17\.' \
      | awk -F'/' '{print $NF" "$0}' | sort -V | awk '{print $2}'); do
      echo "=== [$ver] $(basename "$f") ==="
      bash "$f"
      echo
      # Issue93: burst sleep — avoid HTTP=000 from rapid consecutive APIServer hits
      if [ "$APITEST_BURST_DELAY" != "0" ]; then
        sleep "$APITEST_BURST_DELAY"
      fi
    done

    # 17.cli-quit은 v1 전용이므로 v2에서는 생략
    :
  fi
}

# 메인 로직
run_version "$VERSION" "$TEST_NUM"
