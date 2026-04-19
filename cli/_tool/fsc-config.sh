#!/bin/bash
# Issue40: Xcode 기반 빌드·배포 공용 설정 (fSnippetCli)
# - fsc-run-xcode.sh 에서 source로 로드
# - fWarrangeCli `config.sh`와 동일 구조. 파일명 충돌 방지를 위해 `fsc-` 접두어 사용

PROJECT_NAME="fSnippetCli"
SCHEME="fSnippetCli"
XCODEPROJ_NAME="fSnippetCli.xcodeproj"
APP_NAME="fSnippetCli.app"
BUNDLE_ID="kr.finfra.${PROJECT_NAME}"   # PROJECT_NAME 재사용 (하드코딩 회피)
# Option 2 경로 정책:
#   - 실물 경로(brew 표준 var 영역): /opt/homebrew/var/fSnippetCli/fSnippetCli.app
#   - 편의 심링크(Spotlight/Finder):  /Applications/_nowage_app/fSnippetCli.app → 실물
#   - brew local 배포는 별도(Cellar/opt) 관리, _nowage_app 심링크가 최근 배포를 가리킴
HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"
DEPLOY_DIR="${HOMEBREW_PREFIX}/var/fSnippetCli"
APP_PATH="${DEPLOY_DIR}/${APP_NAME}"
STABLE_LINK_DIR="/Applications/_nowage_app"
STABLE_LINK="${STABLE_LINK_DIR}/${APP_NAME}"
CACHE_FILE_NAME=".last_build_path"
CONFIGURATION="${CONFIGURATION:-Debug}"   # /run 경로 기본 Debug (TCC 회피)
BREW_FORMULA="fsnippet-cli"   # Homebrew Formula 이름 (kebab-case)
BREW_SERVICE_LABEL="homebrew.mxcl.${BREW_FORMULA}"
BREW_SERVICE_PLIST="${HOME}/Library/LaunchAgents/${BREW_SERVICE_LABEL}.plist"

# brew service가 현재 launchd에 로드되어 있는지 확인
# (plist 존재만으로는 부족 — brew services stop 후에도 plist는 남음)
brew_service_running() {
    launchctl list 2>/dev/null | awk '{print $3}' | grep -q "^${BREW_SERVICE_LABEL}$"
}
