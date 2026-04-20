#!/bin/bash
# Issue40 + Issue51 Phase1 (pairApp Issue39 Full Mirror): Xcode 기반 빌드·배포 공용 설정 (fSnippetCli)
# - fsc-run-xcode.sh / fsc-deploy-debug.sh 에서 source 로 로드
# - pairApp `fwc-config.sh` Full Mirror 구조. 파일명 충돌 방지를 위해 `fsc-` 접두어 사용

PROJECT_NAME="fSnippetCli"
SCHEME="fSnippetCli"
XCODEPROJ_NAME="fSnippetCli.xcodeproj"
APP_NAME="fSnippetCli.app"
BUNDLE_ID="kr.finfra.${PROJECT_NAME}"   # PROJECT_NAME 재사용 (하드코딩 회피)

# Issue51 Phase1: 경로 정책 개편 — DerivedData 직접 실행 (var 경로 생성 금지)
#   - Debug 실행 대상: DerivedData 의 .app 을 직접 open (copy 없음)
#   - 편의 심링크(Spotlight/Finder·cmdTest): /Applications/_nowage_app/fSnippetCli.app → DerivedData 실물
#   - Release(brew) 경로는 별도(Cellar/opt) 관리 — 본 설정과 무관
#   - LEGACY_VAR_DIR 은 Phase1 이전 배포 흔적 감지/정리용 — fsc-deploy-debug.sh 에서 경고 출력
HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"
LEGACY_VAR_DIR="${HOMEBREW_PREFIX}/var/fSnippetCli"
STABLE_LINK_DIR="/Applications/_nowage_app"
STABLE_LINK="${STABLE_LINK_DIR}/${APP_NAME}"
CACHE_FILE_NAME=".last_build_path"
CONFIGURATION="${CONFIGURATION:-Debug}"   # /run 경로 기본 Debug (TCC 회피)
BREW_FORMULA="fsnippet-cli"               # Homebrew Formula 이름 (kebab-case)
BREW_SERVICE_LABEL="homebrew.mxcl.${BREW_FORMULA}"
BREW_SERVICE_PLIST="${HOME}/Library/LaunchAgents/${BREW_SERVICE_LABEL}.plist"

# ---------- 공용 헬퍼 ----------

# config.sh 자신의 위치 기준 script 디렉토리 (source 환경에서 안전)
_fsc_script_dir() {
    cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

# DerivedData (TARGET_BUILD_DIR) 경로 resolve
# 1) $CACHE_FILE 에 저장된 값이 유효하면 재사용
# 2) 아니면 xcodebuild -showBuildSettings 로 조회 후 캐시 기록
get_build_dir() {
    local script_dir cache_file cached cli_dir dir
    script_dir=$(_fsc_script_dir)
    cache_file="$script_dir/$CACHE_FILE_NAME"
    if [ -f "$cache_file" ]; then
        cached=$(cat "$cache_file" 2>/dev/null || true)
        if [ -n "$cached" ] && [ -d "$cached" ]; then
            echo "$cached"
            return 0
        fi
    fi
    cli_dir="$(cd "$script_dir/.." && pwd)"
    dir=$(cd "$cli_dir" && xcodebuild -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings 2>/dev/null \
        | grep " TARGET_BUILD_DIR =" | awk -F " = " '{print $2}' | xargs)
    if [ -z "$dir" ]; then
        return 1
    fi
    echo "$dir" > "$cache_file"
    echo "$dir"
}

# Debug .app 실물 경로 resolve — DerivedData 의 .app 을 직접 가리킴
# 빌드 결과가 없으면 비어있는 문자열 반환 (호출부에서 판단)
resolve_app_path() {
    local dir
    dir=$(get_build_dir 2>/dev/null) || return 1
    if [ -d "$dir/$APP_NAME" ]; then
        echo "$dir/$APP_NAME"
        return 0
    fi
    return 1
}

# brew service 가 현재 launchd 에 로드되어 있는지 확인
# (plist 존재만으로는 부족 — brew services stop 후에도 plist 는 남음)
brew_service_running() {
    launchctl list 2>/dev/null | awk '{print $3}' | grep -q "^${BREW_SERVICE_LABEL}$"
}

# Issue51 Phase1: 레거시 var 경로 감지 — 발견 시 경고 출력 (자동 삭제 없음)
#   - 과거 Phase1 이전에 fsc-deploy-debug.sh 가 copy 하던 대상
#   - 현재는 생성 주체 없음. 잔존 시 case 4(이중 인스턴스) 재현 여지
#   - 자동 삭제는 사용자 권한/TCC 재부여 이슈로 수동 가이드
warn_legacy_var_dir() {
    if [ -d "$LEGACY_VAR_DIR" ]; then
        echo "[legacy] ⚠️ 구 배포 경로 감지: $LEGACY_VAR_DIR"
        echo "         이 경로는 Issue51 Phase1 이후 사용되지 않음."
        echo "         이중 인스턴스 방지를 위해 수동 삭제 권장:"
        echo "           rm -rf '$LEGACY_VAR_DIR'"
    fi
}
