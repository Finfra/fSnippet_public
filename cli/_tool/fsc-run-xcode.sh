#!/bin/bash
# Issue40: Xcode GUI 기반 빌드·배포 스크립트 (TCC 회피 목적, fSnippetCli)
# Usage: ./fsc-run-xcode.sh [build|build-deploy|run-only|deploy-run|stop|kill|open]
#
#   open         : .xcodeproj 사전 오픈 + 로드 대기 (idempotent)
#   build        : Xcode GUI 빌드만 (배포 없음)
#   build-deploy : build + Applications 복사 + 실행 (기본값)
#   run-only     : 빌드 없이 기존 배포 앱 실행
#   deploy-run   : 배포만 + 실행 (이미 빌드된 결과물 사용)
#   stop         : Xcode의 현재 scheme action 중단
#   kill         : 배포 앱 프로세스 종료
#
# 설계 근거: Issue.md Issue40 (fWarrangeCli Issue31 POC 결과 이식)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_DIR="$(dirname "$SCRIPT_DIR")"

# shellcheck source=fsc-config.sh
source "$SCRIPT_DIR/fsc-config.sh"

XCODEPROJ="$CLI_DIR/$XCODEPROJ_NAME"
CACHE_FILE="$SCRIPT_DIR/$CACHE_FILE_NAME"

CMD="${1:-build-deploy}"

# ---------- Step 0: 프로젝트 사전 오픈 (AppleScript 오류 예방) ----------
open_project() {
    local already_loaded
    already_loaded=$(osascript 2>/dev/null <<APPLESCRIPT || echo "false"
tell application "Xcode"
    try
        set ws to workspace document "$XCODEPROJ_NAME"
        return (loaded of ws) as text
    on error
        return "false"
    end try
end tell
APPLESCRIPT
)
    if [[ "$already_loaded" == "true" ]]; then
        echo "[open] $XCODEPROJ_NAME 이미 로드됨"
        return 0
    fi

    echo "[open] $XCODEPROJ_NAME 오픈 중..."
    open -a Xcode "$XCODEPROJ"

    # loaded 폴링 — 최대 60초 (120회 × 0.5초)
    osascript <<APPLESCRIPT
tell application "Xcode"
    repeat 120 times
        try
            set ws to workspace document "$XCODEPROJ_NAME"
            if loaded of ws is true then return "OK"
        end try
        delay 0.5
    end repeat
    error "Xcode workspace did not finish loading within 60s"
end tell
APPLESCRIPT
    echo "[open] 로드 완료"
}

# ---------- Step 1: Xcode 빌드 제어 ----------
# 다른 Xcode 프로젝트의 빌드에 영향을 주지 않도록 해당 workspace document만 stop.
# pkill -f xcodebuild 같은 전역 종료 사용 금지 — 다른 프로젝트 CLI 빌드까지 죽임.
xcode_stop() {
    echo "[stop] $XCODEPROJ_NAME scheme action 중단 (해당 workspace 한정)"
    open_project
    osascript 2>/dev/null <<APPLESCRIPT || true
tell application "Xcode"
    try
        stop (workspace document "$XCODEPROJ_NAME")
    end try
end tell
APPLESCRIPT
}

xcode_build() {
    # 기존 scheme action이 있으면 해당 workspace만 중단 후 새 빌드 시작
    # (open_project는 xcode_stop 내부에서 수행)
    xcode_stop
    # Xcode에 포커스 — 외부 파일 변경 감지 시 Revert 다이얼로그가 보이도록
    osascript -e 'tell application "Xcode" to activate' 2>/dev/null || true
    echo "[build] Xcode 빌드 시작 ($SCHEME)"
    local result exit_code
    result=$(osascript 2>&1 <<APPLESCRIPT
tell application "Xcode"
    set ws to workspace document "$XCODEPROJ_NAME"
    set buildRes to build ws
    repeat while completed of buildRes is false
        delay 0.5
    end repeat
    set s to (status of buildRes as text)
    if s is "succeeded" then
        return "OK"
    else
        set emsg to ""
        try
            set emsg to (error message of buildRes)
        end try
        return "FAIL|" & s & "|" & emsg
    end if
end tell
APPLESCRIPT
)
    exit_code=$?
    if [[ "$result" == "OK" ]]; then
        echo "[build] ✅ 빌드 성공"
        return 0
    fi
    echo "[build] ❌ $result"
    if [ $exit_code -ne 0 ] || [[ "$result" == *"Can’t get scheme action result"* ]] || [[ "$result" == *"-1728"* ]]; then
        echo ""
        echo "📌 안내: Xcode에 파일 변경 확인 다이얼로그가 떠 있을 수 있습니다."
        echo "         Xcode 창을 확인하고 'Revert' 버튼을 클릭한 뒤 재실행하세요."
    fi
    return 1
}

# ---------- Step 2: 빌드 경로 동적 계산 (TCC 무관 메타 조회) ----------
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

# ---------- Step 3: 배포 (Applications 복사) ----------
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

# ---------- Step 4: 실행·종료 ----------
run_app() {
    echo "[run] $APP_PATH 실행"
    open "$APP_PATH"
}

kill_app() {
    echo "[kill] $PROJECT_NAME 프로세스 종료"
    pkill -f "MacOS/$PROJECT_NAME" 2>/dev/null || true
}

# ---------- 명령 디스패치 ----------
case "$CMD" in
    open)
        open_project
        ;;
    stop)
        xcode_stop
        ;;
    build)
        xcode_build
        ;;
    build-deploy)
        xcode_build
        deploy
        run_app
        ;;
    deploy-run)
        deploy
        run_app
        ;;
    run-only)
        kill_app
        run_app
        ;;
    kill)
        kill_app
        ;;
    *)
        echo "Usage: $0 [open|stop|build|build-deploy|deploy-run|run-only|kill]"
        exit 1
        ;;
esac
