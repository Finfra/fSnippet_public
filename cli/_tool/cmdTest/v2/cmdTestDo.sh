#!/bin/bash
# cmdTestDo.sh - CLI v2 커맨드 테스트 실행기 (settings)
# Usage:
#   bash cli/_tool/cmdTest/v2/cmdTestDo.sh        # 전체 순서대로 실행
#   bash cli/_tool/cmdTest/v2/cmdTestDo.sh 0      # 00.settings-general-get.sh 만 실행
# 파일명: 00~99 두 자리, E01~E99 에러 케이스

# source 호환: BASH_SOURCE 우선, fallback으로 $0
if [ -n "${BASH_SOURCE[0]}" ]; then
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

if [ -n "$1" ]; then
  # 단건 실행: 숫자 → 00 패딩
  NUM=$(printf '%02d' "$1" 2>/dev/null)
  MATCHED=$(ls "$SCRIPT_DIR"/"$NUM".*.sh 2>/dev/null)
  if [ -z "$MATCHED" ]; then
    # E 에러 케이스 매칭 시도
    MATCHED=$(ls "$SCRIPT_DIR"/E"$NUM".*.sh 2>/dev/null)
  fi
  if [ -z "$MATCHED" ]; then
    echo "❌ $NUM.*.sh 또는 E$NUM.*.sh 를 찾을 수 없음"
    return 1 2>/dev/null || exit 1
  fi
  echo "=== [v2] $(basename "$MATCHED") ==="
  bash "$MATCHED"
else
  # 전체 실행: 정상 + 에러 케이스 순서대로
  PASS=0
  FAIL=0
  TOTAL=0
  for f in $(ls "$SCRIPT_DIR"/[0-9]*.sh "$SCRIPT_DIR"/E*.sh 2>/dev/null \
    | grep -v 'cmdTestDo' \
    | awk -F'/' '{print $NF" "$0}' | sort | awk '{print $2}'); do
    TOTAL=$((TOTAL + 1))
    echo "=== [v2] $(basename "$f") ==="
    bash "$f"
    RC=$?
    if [ $RC -eq 0 ]; then
      PASS=$((PASS + 1))
    else
      FAIL=$((FAIL + 1))
    fi
    echo
  done
  echo "==============================="
  echo "결과: 전체=$TOTAL  성공=$PASS  실패=$FAIL"
  echo "==============================="
fi
