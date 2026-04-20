#!/bin/bash
# Issue40: Xcode GUI 기반 빌드·실행 스크립트 (TCC 회피 목적, fSnippetCli)
# Issue41 Phase2: build-deploy 흐름에 xcode_run_stop 삽입 — Xcode에서 run→stop으로
#                 TCC 권한을 앱에 귀속시킨 뒤 /deploy debug(= fsc-deploy-debug.sh)로 독립 기동
#
# Usage: ./fsc-run-xcode.sh [open|stop|build|build-deploy|deploy-run|run-only|kill|tcc]
#
#   open         : .xcodeproj 사전 오픈 + 로드 대기 (idempotent)
#   build        : Xcode GUI 빌드만 (배포 없음)
#   build-deploy : build + xcode_run_stop(TCC 획득) + fsc-deploy-debug.sh (기본값)
#   deploy-run   : 배포만 + 실행 (이미 빌드된 결과물 사용, fsc-deploy-debug.sh 호출)
#   run-only     : 빌드·배포 없이 기존 배포 앱 실행
#   stop         : Xcode의 현재 scheme action 중단
#   kill         : 배포 앱 프로세스 종료
#   tcc          : kill + tccutil reset Accessibility + build-deploy
#                  (외부 빌드/brew 재설치로 꼬인 TCC 권한 재설정 목적)
#
# 설계 근거: Issue.md Issue40 + Issue41 Phase2

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_DIR="$(dirname "$SCRIPT_DIR")"

# shellcheck source=fsc-config.sh
source "$SCRIPT_DIR/fsc-config.sh"

XCODEPROJ="$CLI_DIR/$XCODEPROJ_NAME"

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
#
# AppleScript stop이 성공해도 앱 프로세스가 잔존하는 경우가 있어,
# 이후 build → xcode_run_stop 단계에서 TCC가 새 바이너리에 적용되지 않는 문제가 발생함.
# 따라서 stop 성공 시에는 `pkill -f "MacOS/$PROJECT_NAME"`으로 해당 앱 프로세스만 정리.
xcode_stop() {
    echo "[stop] $XCODEPROJ_NAME scheme action 중단 (해당 workspace 한정)"
    open_project
    local stop_result
    stop_result=$(osascript 2>&1 <<APPLESCRIPT || true
tell application "Xcode"
    try
        stop (workspace document "$XCODEPROJ_NAME")
        return "OK"
    on error emsg
        return "FAIL|" & emsg
    end try
end tell
APPLESCRIPT
)
    if [[ "$stop_result" == "OK" ]]; then
        # Xcode stop 성공 — TCC 재적용 방해 방지용 잔존 프로세스 정리
        if pgrep -f "MacOS/$PROJECT_NAME" > /dev/null 2>&1; then
            echo "[stop] 잔존 프로세스 감지 — pkill -f MacOS/$PROJECT_NAME"
            pkill -f "MacOS/$PROJECT_NAME" 2>/dev/null || true
            sleep 0.3
        fi
    else
        echo "[stop] ⚠️ $stop_result"
    fi
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

# ---------- Step 2: Xcode run → stop (TCC 권한 획득용) ----------
# Issue41 Phase2: Xcode 세션에서 앱을 1회 실행해 TCC 다이얼로그가 뜨게 한 뒤 즉시 stop.
# 최초 1회는 사용자가 TCC 프롬프트(접근성/Automation)를 승인해야 함.
# 이후 /deploy debug(= fsc-deploy-debug.sh)로 Applications 경로에서 독립 기동 시
# TCC 권한은 앱 번들에 귀속된 상태로 승계됨.
xcode_run_stop() {
    echo "[run-stop] Xcode에서 run→stop 순서로 TCC 권한 획득 ($SCHEME)"
    local result
    result=$(osascript 2>&1 <<APPLESCRIPT
tell application "Xcode"
    set ws to workspace document "$XCODEPROJ_NAME"
    try
        set runRes to run ws
        -- run 시작까지 짧게 대기 (TCC 프롬프트 표시 트리거)
        delay 1.0
    end try
    try
        stop ws
    end try
    return "OK"
end tell
APPLESCRIPT
)
    if [[ "$result" == *"OK"* ]]; then
        echo "[run-stop] ✅ TCC 권한 획득 완료"
        return 0
    fi
    echo "[run-stop] ⚠️ $result"
    echo "             (최초 실행 시 TCC 프롬프트를 승인해야 합니다)"
    return 0
}

# ---------- Step 3: 프로세스 종료 ----------
# Issue52 Phase0: applicationWillTerminate 가 정상 경로에서 brew stop 을 수행하지만,
# SIGKILL/pkill 경로는 delegate 건너뜀 → launchctl 잔존 시 fallback brew stop.
kill_app() {
    echo "[kill] $PROJECT_NAME 프로세스 종료"
    pkill -f "MacOS/$PROJECT_NAME" 2>/dev/null || true
    sleep 1
    if brew_service_running; then
        echo "[kill] ⚠️ brew service 잔존 — fallback: brew services stop $BREW_FORMULA"
        brew services stop "$BREW_FORMULA" 2>&1 | tail -1 || true
    fi
}

# ---------- Step 3.5: TCC Accessibility 권한 초기화 ----------
# 외부 빌드(스크립트/brew 재설치 등)로 번들 서명-권한 연결이 꼬였을 때,
# TCC DB에서 해당 BundleID 엔트리를 제거하여 다음 실행 시 사용자가
# 시스템 설정에서 접근성 권한을 재추가하게 강제함.
reset_tcc_accessibility() {
    echo "[tcc-reset] Accessibility 권한 초기화: $BUNDLE_ID"
    if tccutil reset Accessibility "$BUNDLE_ID" 2>&1; then
        echo "[tcc-reset] ✅ 초기화 완료 — Xcode run 시 사용자가 권한을 다시 승인해야 합니다"
    else
        echo "[tcc-reset] ⚠️ tccutil 실패 (이미 제거된 상태일 수 있음)"
    fi
}

# ---------- Step 3.6: brew service 선행 정지 (Debug 배포 경합 방지) ----------
# Debug 바이너리를 덮어쓰기/실행하기 전에 brew service가 launchd에 로드되어 있으면
# 정지시킴. 이유:
#   - `pkill` 은 launchd가 crash로 오인 → keep_alive 트리거 → Cellar/Release 재기동
#   - 포트 3015 단일 인스턴스 가드가 Release를 먼저 잡아 Debug 거부 가능
# Debug 세션 종료 후 복원은 `/deploy brew local` 또는 `brew services start`.
brew_service_stop_for_debug() {
    if brew_service_running; then
        echo "[brew] service 실행 감지 — Debug 덮어쓰기 전 stop (launchd respawn 차단)"
        brew services stop "$BREW_FORMULA" 2>&1 | tail -1 || true
        echo "[brew] ℹ️ Release 복원: brew services start $BREW_FORMULA 또는 /deploy brew local"
    fi
}

# ---------- Step 4: 기존 배포 앱 실행 (빌드·배포 없음) ----------
# brew service 실행 여부에 따라 실행 경로 분기:
#   - 실행 중: brew services restart (단일 경로, launchd 경합 회피)
#   - 정지/미등록: 기존 kill + open (Debug 오버라이드 존중)
# plist 존재 여부가 아닌 launchctl 로드 상태로 판정하여, /run build-deploy로
# 중지된 Debug 세션 중 run-only 호출 시 의도치 않은 Release 복원을 방지.
run_app_only() {
    if brew_service_running; then
        echo "[run-only] brew service 실행 감지 — $BREW_FORMULA 재시작 (launchd 단일 경로)"
        if brew services restart "$BREW_FORMULA"; then
            echo "[run-only] ✅ brew services restart 완료"
            return 0
        fi
        echo "[run-only] ⚠️ brew services restart 실패 — fallback: 직접 실행"
    fi

    # Issue51 Phase1: DerivedData 의 .app 을 직접 open
    local app_path
    app_path=$(resolve_app_path) || {
        echo "[run-only] ❌ 배포된 앱 없음 (DerivedData resolve 실패)"
        echo "            먼저 /run build-deploy 또는 /deploy debug 실행 필요"
        return 1
    }
    kill_app
    # pkill 직후 macOS Launch Services 내부 정리 대기 (-600 회피)
    sleep 0.5
    echo "[run-only] $app_path 실행"
    for attempt in 1 2 3; do
        if open "$app_path" 2>&1; then
            return 0
        fi
        echo "[run-only] ⚠️ open 실패 (attempt $attempt/3) — retry"
        sleep 0.5
    done
    echo "[run-only] ❌ open 최종 실패"
    return 1
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
        # Issue41 Phase2: build → Xcode run/stop (TCC 획득) → /deploy debug (독립 기동)
        # brew service 실행 중이면 선행 정지 (pkill → launchd respawn 경합 차단)
        brew_service_stop_for_debug
        xcode_build
        xcode_run_stop
        bash "$SCRIPT_DIR/fsc-deploy-debug.sh"
        ;;
    deploy-run)
        # 이미 빌드된 결과물을 배포+실행 (TCC 획득 단계 생략)
        brew_service_stop_for_debug
        bash "$SCRIPT_DIR/fsc-deploy-debug.sh"
        ;;
    run-only)
        # brew service 등록 시 brew services restart (launchd 단일 경로),
        # 미등록 시 kill + open. kill 은 run_app_only 내부에서 분기 처리.
        run_app_only
        ;;
    kill)
        kill_app
        ;;
    tcc)
        # kill → TCC Accessibility reset → build-deploy
        # 외부 빌드/brew 재설치로 꼬인 권한을 재설정하고, Xcode run 시점에
        # 사용자가 접근성 권한을 다시 부여하도록 유도.
        brew_service_stop_for_debug
        kill_app
        reset_tcc_accessibility
        xcode_build
        xcode_run_stop
        bash "$SCRIPT_DIR/fsc-deploy-debug.sh"
        ;;
    *)
        echo "Usage: $0 [open|stop|build|build-deploy|deploy-run|run-only|kill|tcc]"
        exit 1
        ;;
esac
