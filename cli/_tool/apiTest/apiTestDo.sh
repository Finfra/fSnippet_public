#!/bin/bash
# apiTestDo.sh - API 테스트 실행기 (v1/v2 분리 지원)
# Usage:
#   bash apiTestDo.sh         # v1 전체 (기본)
#   bash apiTestDo.sh v1      # v1만
#   bash apiTestDo.sh v2      # v2만
#   bash apiTestDo.sh all     # v1 + v2 전체
#   bash apiTestDo.sh 5       # v1/05.*.sh 실행
#   bash apiTestDo.sh v2 5    # v2/05.*.sh 실행

# source 호환
if [ -n "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# 인자 파싱
VERSION="${1:-v1}"
TEST_NUM="${2:---all}"

# v1, v2, all 외의 값이 버전으로 넘어온 경우 처리
if [[ ! "$VERSION" =~ ^(v1|v2|all)$ ]]; then
  TEST_NUM="$VERSION"
  VERSION="v1"
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
    done

    # 17.cli-quit은 마지막에 (v1만)
    if [ "$ver" = "v1" ]; then
      QUIT_SCRIPT="$base_dir/17.cli-quit.sh"
      if [ -f "$QUIT_SCRIPT" ]; then
        echo "=== [$ver] $(basename "$QUIT_SCRIPT") [LAST - 앱 종료됨] ==="
        printf "cli-quit 실행? (y/N): "; read yn
        if [ "$yn" = "y" ] || [ "$yn" = "Y" ]; then
          bash "$QUIT_SCRIPT"
        else
          echo "⏭️ 건너뜀"
        fi
      fi
    fi
  fi
}

# 메인 로직
if [ "$VERSION" = "all" ]; then
  echo "📋 v1 테스트 실행..."
  run_version "v1" "--all"
  echo ""
  echo "📋 v2 테스트 실행..."
  run_version "v2" "--all"
else
  run_version "$VERSION" "$TEST_NUM"
fi
