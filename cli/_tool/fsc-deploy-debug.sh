#!/bin/bash
# Issue41 Phase2 + Issue51 Phase1: Debug 빌드 결과물을 DerivedData 그대로 실행
# Usage: bash cli/_tool/fsc-deploy-debug.sh
#
# 호출 시점:
#   - /deploy debug 커맨드
#   - fsc-run-xcode.sh build-deploy 흐름 (xcode_run_stop 이후)
#
# Issue51 Phase1 변경 (pairApp Issue39 Full Mirror):
#   - 과거: DerivedData → /opt/homebrew/var/fSnippetCli/fSnippetCli.app 로 cp -R
#   - 현재: DerivedData 의 .app 을 직접 open (copy 없음, var 경로 생성 금지)
#   - /Applications/_nowage_app/fSnippetCli.app 심링크만 DerivedData 실물로 갱신
#     (cmdTest 스크립트가 이 경로를 CLI 진입점으로 사용 → 심링크 유지 필수)
#   - get_build_dir / resolve_app_path 는 fsc-config.sh 로 이전 (재사용)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=fsc-config.sh
source "$SCRIPT_DIR/fsc-config.sh"

# ---------- 심링크 갱신 ----------
update_stable_link() {
    local app_path="$1"
    mkdir -p "$STABLE_LINK_DIR"
    if [ -L "$STABLE_LINK" ] || [ -e "$STABLE_LINK" ]; then
        rm -f "$STABLE_LINK"
    fi
    ln -sfn "$app_path" "$STABLE_LINK"
    echo "[deploy] ✅ 심링크: $STABLE_LINK → $app_path"
}

# ---------- 배포 (copy 없음 — DerivedData 직접 사용) ----------
deploy() {
    local app_path
    app_path=$(resolve_app_path) || {
        echo "[deploy] ❌ 빌드 결과물 없음 — xcodebuild build 선행 필요"
        return 1
    }

    # Phase1: copy 제거. pkill 만 선행 (심링크 재생성 직전 실행 중 프로세스 정리)
    if pgrep -f "MacOS/$PROJECT_NAME" > /dev/null 2>&1; then
        echo "[deploy] 실행 중인 $PROJECT_NAME 프로세스 정리"
        pkill -f "MacOS/$PROJECT_NAME" 2>/dev/null || true
        sleep 0.3
    fi

    echo "[deploy] ✅ Debug 앱 경로 확정 (DerivedData 직접 실행): $app_path"
    update_stable_link "$app_path"

    # 레거시 var 경로 잔존 경고 (Phase1 이전 배포 흔적)
    warn_legacy_var_dir
}

# ---------- 실행 (DerivedData 실물 경로로 직접 open) ----------
run_app() {
    local app_path
    app_path=$(resolve_app_path) || {
        echo "[run] ❌ 빌드 결과물 없음"
        return 1
    }
    echo "[run] $app_path 실행"
    open "$app_path"
}

# ---------- 실행 ----------
deploy
run_app
