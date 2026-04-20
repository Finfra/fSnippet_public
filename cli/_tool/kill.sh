#!/bin/bash
# Usage: kill.sh
#   fSnippetCli 프로세스 종료
#
# Issue40: 다른 Xcode 프로젝트에 영향 없도록 해당 workspace document만 stop.
# `every workspace document` 전역 stop 사용 금지.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=fsc-config.sh
source "$SCRIPT_DIR/fsc-config.sh"

echo "🔄 기존 프로세스 종료..."
pkill -9 -f "MacOS/$PROJECT_NAME" 2>/dev/null || true
sleep 1

# 잔존 프로세스 확인 — Xcode Run scheme으로 실행 중인 경우 해당 workspace만 stop
REMAIN=$(pgrep -f "MacOS/$PROJECT_NAME" | wc -l | tr -d ' ')
if [ "$REMAIN" -gt 0 ]; then
    echo "⚠️ 잔존 프로세스 감지 — $XCODEPROJ_NAME workspace만 stop"
    osascript 2>/dev/null <<APPLESCRIPT || true
tell application "Xcode"
    try
        stop (workspace document "$XCODEPROJ_NAME")
    end try
end tell
APPLESCRIPT
    sleep 2
fi

# Issue52 Phase0: delegate(applicationWillTerminate)가 정상 수행되면 brew=stopped 가 되지만,
# SIGKILL(-9) / crash 경로는 delegate 를 건너뜀 → launchctl 잔존 시 명시적 fallback.
if launchctl list 2>/dev/null | grep -q "homebrew.mxcl.fsnippet-cli"; then
    echo "⚠️ brew service 잔존 — fallback: brew services stop fsnippet-cli"
    brew services stop fsnippet-cli 2>&1 | tail -1 || true
else
    echo "✅ brew service 정상 정지 (delegate 경유)"
fi

echo "✅ 프로세스 종료 완료"
