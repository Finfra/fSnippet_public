#!/bin/bash
# Usage: run.sh [run-only]
#   인자 없음: 빌드 후 배포 및 실행
#   run-only: 빌드 없이 실행만

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DEST="/Applications/_nowage_app"
APP_NAME="fSnippetCli"

# Step 1: 기존 프로세스 종료
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

# Step 2: 빌드 (run-only가 아닌 경우)
if [ "$1" != "run-only" ]; then
    echo "🔨 Release 빌드..."
    cd "$CLI_DIR"
    xcodebuild -scheme "$APP_NAME" -configuration Release build -quiet
    echo "✅ 빌드 완료"
fi

# Step 3: 배포 및 실행
echo "📦 배포..."
BUILD_DIR=$(cd "$CLI_DIR" && xcodebuild -scheme "$APP_NAME" -configuration Release -showBuildSettings 2>/dev/null \
    | grep " TARGET_BUILD_DIR =" | awk -F " = " '{print $2}' | xargs)

if [ ! -d "$BUILD_DIR/$APP_NAME.app" ]; then
    echo "❌ 빌드 결과물 없음: $BUILD_DIR/$APP_NAME.app"
    exit 1
fi

mkdir -p "$APP_DEST"
rm -rf "$APP_DEST/$APP_NAME.app"
cp -R "$BUILD_DIR/$APP_NAME.app" "$APP_DEST/"
xattr -cr "$APP_DEST/$APP_NAME.app"
echo "🚀 실행..."
open "$APP_DEST/$APP_NAME.app"

# Step 4: 동작 확인
sleep 3
echo "📡 상태 확인..."
curl -s http://localhost:3015/ | python3 -m json.tool 2>/dev/null || echo "⚠️ API 응답 없음"
echo ""
echo "✅ 완료"
