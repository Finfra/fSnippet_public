#!/bin/bash
# apiTestDo.sh - API 테스트 실행기
# Usage:
#   bash cli/_tool/apiTest/apiTestDo.sh        # 전체 순서대로 실행
#   bash cli/_tool/apiTest/apiTestDo.sh 0      # 00.hello.sh 만 실행
#   source cli/_tool/apiTestDo.sh 0            # wrapper 경유 실행
# Note: 17.cli-quit은 앱 종료시키므로 전체 실행 시 마지막에 배치
# 파일명: 00~99 두 자리, E01~E99 에러 케이스

# source 호환: BASH_SOURCE 우선, fallback으로 $0
if [ -n "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

if [ -n "$1" ]; then
  NUM=$(printf '%02d' "$1" 2>/dev/null)
  MATCHED=$(ls "$SCRIPT_DIR"/"$NUM".*.sh 2>/dev/null)
  if [ -z "$MATCHED" ]; then
    echo "❌ $NUM.*.sh 를 찾을 수 없음"
    return 1 2>/dev/null || exit 1
  fi
  echo "=== $(basename "$MATCHED") ==="
  bash "$MATCHED"
else
  # 숫자 추출 후 정렬, quit(17)은 제외하고 마지막에 실행
  for f in $(ls "$SCRIPT_DIR"/[0-9]*.sh "$SCRIPT_DIR"/E*.sh 2>/dev/null \
    | grep -v '/17\.\|apiTestDo' \
    | awk -F'/' '{print $NF" "$0}' | sort -n | awk '{print $2}'); do
    echo "=== $(basename "$f") ==="
    bash "$f"
    echo
  done
  # quit은 마지막 (확인 후 실행)
  QUIT_SCRIPT="$SCRIPT_DIR/17.cli-quit.sh"

  if [ -f "$QUIT_SCRIPT" ]; then
    echo "=== $(basename "$QUIT_SCRIPT") [LAST - 앱 종료됨] ==="
    printf "cli-quit 실행? (y/N): "; read yn
    if [ "$yn" = "y" ] || [ "$yn" = "Y" ]; then
      bash "$QUIT_SCRIPT"
    else
      echo "⏭️ 건너뜀"
    fi
  fi
fi
