#!/bin/bash
# Issue41 Phase2: Debug 빌드 결과물을 Applications로 배포하고 독립 실행
# Usage: bash cli/_tool/fsc-deploy-debug.sh
#
# 호출 시점:
#   - /deploy debug 커맨드
#   - fsc-run-xcode.sh build-deploy 흐름 (xcode_run_stop 이후)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_DIR="$(dirname "$SCRIPT_DIR")"

# shellcheck source=fsc-config.sh
source "$SCRIPT_DIR/fsc-config.sh"

CACHE_FILE="$SCRIPT_DIR/$CACHE_FILE_NAME"

# ---------- 빌드 경로 동적 계산 ----------
get_build_dir() {
    if [ -f "$CACHE_FILE" ]; then
        local cached
        cached=$(cat "$CACHE_FILE")
        if [ -n "$cached" ] && [ -d "$cached" ]; then
            echo "$cached"
            return 0
        fi
    fi
    local dir
    dir=$(cd "$CLI_DIR" && xcodebuild -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings 2>/dev/null | grep " TARGET_BUILD_DIR =" | awk -F " = " '{print $2}' | xargs)
    if [ -z "$dir" ]; then
        echo "[build-dir] ❌ BUILD_DIR 조회 실패" >&2
        return 1
    fi
    echo "$dir" > "$CACHE_FILE"
    echo "$dir"
}

# ---------- 배포 (Applications 복사) ----------
deploy() {
    local build_dir src
    build_dir=$(get_build_dir) || return 1
    src="$build_dir/$APP_NAME"
    if [ ! -d "$src" ]; then
        echo "[deploy] ❌ 빌드 결과물 없음: $src"
        return 1
    fi

    # 바이너리 타임스탬프 비교 (GNU stat 간섭 회피: date -r 사용)
    local src_mtime dst_mtime
    src_mtime=$(date -r "$src/Contents/MacOS/$PROJECT_NAME" +%s 2>/dev/null || echo 0)
    dst_mtime=$(date -r "$APP_PATH/Contents/MacOS/$PROJECT_NAME" +%s 2>/dev/null || echo 0)
    if [ "$src_mtime" -le "$dst_mtime" ] && [ -d "$APP_PATH" ]; then
        echo "[deploy] 변경 없음 (skip)"
        return 0
    fi

    echo "[deploy] $APP_NAME 복사 중..."
    pkill -f "MacOS/$PROJECT_NAME" 2>/dev/null || true
    sleep 0.3
    mkdir -p "$DEPLOY_DIR"
    rm -rf "$APP_PATH"
    cp -R "$src" "$APP_PATH"
    xattr -cr "$APP_PATH"
    echo "[deploy] ✅ $APP_PATH"
}

# ---------- 실행 ----------
run_app() {
    echo "[run] $APP_PATH 실행"
    open "$APP_PATH"
}

# ---------- 실행 ----------
deploy
run_app
