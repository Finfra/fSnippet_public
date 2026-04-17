#!/bin/bash
# Usage: kill.sh
#   fSnippetCli 프로세스 종료

APP_NAME="fSnippetCli"

echo "🔄 기존 프로세스 종료..."
pkill -9 -f "MacOS/$APP_NAME" 2>/dev/null || true
sleep 1

# 잔존 프로세스 확인
REMAIN=$(ps aux | grep -c "[f]SnippetCli" || true)
if [ "$REMAIN" -gt 0 ]; then
    echo "⚠️ 잔존 프로세스 감지 — Xcode stop 시도"
    osascript -e 'tell application "Xcode" to stop (every workspace document)' 2>/dev/null || true
    sleep 2
fi

echo "✅ 프로세스 종료 완료"
