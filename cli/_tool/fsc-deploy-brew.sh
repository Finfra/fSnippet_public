#!/bin/bash
# Issue43: /deploy brew 서브커맨드 라우터
# Usage: ./fsc-deploy-brew.sh [local|publish|status|uninstall]
#
# 목적:
#   - 단독 호출 금지 — 반드시 서브커맨드 동반
#   - local: 로컬 Homebrew tap 재설치 (원격 tap 생성 전 테스트 경로)
#   - publish: 원격 finfra/homebrew-tap 저장소에 Formula 반영 (🚧 TODO)
#   - status: 설치/tap/프로세스/REST 상태 조회
#   - uninstall: brew 제거 + 로컬 tap Formula 파일 정리
#
# 설계 근거: ~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md
# 설계 메모:
#   - Formula version이 URL로부터 추출되지 않으므로 version "0.0.0-local" 명시 필수
#   - PIPESTATUS로 xcodebuild/brew 실제 exit code 포착 (tail 파이프에 가려지지 않도록)
#   - 메뉴바 GUI 앱(LSUIElement)은 brew services 대신 open으로 직접 실행
#   - brew 재설치 후 새 서명 바이너리로 TCC 권한 꼬임 가능 → /run tcc 안내

set +e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_DIR="$(dirname "$SCRIPT_DIR")"
TAP_DIR="/opt/homebrew/Library/Taps/finfra/homebrew-tap"
TAP_FORMULA="$TAP_DIR/Formula/fsnippet-cli.rb"
TARBALL="/tmp/fSnippetCli-local.tar.gz"
# VERSION 파일에서 읽기 (없으면 0.0.0-local 폴백)
_VERSION_FILE="$(git -C "$CLI_DIR" rev-parse --show-toplevel 2>/dev/null)/VERSION"
LOCAL_VERSION="$(cat "$_VERSION_FILE" 2>/dev/null | tr -d '[:space:]')"
[ -z "$LOCAL_VERSION" ] && LOCAL_VERSION="0.0.0-local"

# shellcheck source=fsc-config.sh
source "$SCRIPT_DIR/fsc-config.sh"

usage() {
  cat <<'USAGE'
Usage: /deploy brew <sub>       ⚠️ 서브커맨드 필수 — 단독 호출 엄격 금지

🚫 `/deploy brew` (서브커맨드 없음)는 사용자 실수를 유발하므로 차단됩니다.
   암시적 기본값(local) 적용하지 않습니다. 반드시 아래 4개 중 하나 명시.

  sub         설명                                                         상태
  ---------   -----------------------------------------------------------  -----
  local       Release 빌드 → 로컬 tap 재설치 + 심링크 + (옵트인 brew services) + 앱 실행 (9단계)  ✅
  publish     Release 빌드 → gh release(cli-v{ver}) + asset → Formula 갱신 + 원격 tap push  ✅
  status      brew 설치·tap·프로세스·REST API 상태 조회                    ✅
  uninstall   brew uninstall + 로컬 tap Formula 파일 정리                  ✅

예시:
  /deploy brew local       # 로컬 재설치 (개발 반복)
  /deploy brew status      # 현재 상태 한눈에 조회
  /deploy brew uninstall   # 깨끗하게 정리

⚠️ TCC 안내: brew 재설치로 접근성 권한이 꼬이면 `/run tcc` 로 재설정.
USAGE
}

# ---------- 공용 유틸: TCC 안내 ----------
tcc_notice() {
    echo ""
    echo "⚠️ TCC 안내"
    echo "   brew 재설치로 새 서명 바이너리가 생기면 접근성 권한이 분리되어"
    echo "   키 이벤트 감지가 동작하지 않을 수 있습니다."
    echo ""
    echo "   해결책 중 하나:"
    echo "     1) 시스템 설정 > 개인정보 보호 및 보안 > 접근성 > fSnippetCli 체크"
    echo "     2) Xcode Debug 경로로 재설정: /run tcc"
    echo "        (fsc-run-xcode.sh tcc = kill + tccutil reset + build-deploy)"
}

# ==========================================
# 서브커맨드: local (기존 8단계)
# ==========================================
cmd_local() {
    local TOTAL_PASS=0
    local TOTAL_FAIL=0
    local STEP_RESULTS=()

    record_result() {
        local step="$1" result="$2" detail="$3"
        if [ "$result" = "PASS" ]; then
            TOTAL_PASS=$((TOTAL_PASS + 1))
            STEP_RESULTS+=("✅ $step: $detail")
        else
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            STEP_RESULTS+=("❌ $step: $detail")
        fi
    }

    echo "╔══════════════════════════════════════════╗"
    echo "║  fSnippetCli Brew Deploy (local)         ║"
    echo "╚══════════════════════════════════════════╝"

    # Step 1: Release 빌드
    echo ""
    echo "=== Step 1: Release 빌드 ==="
    pushd "$CLI_DIR" > /dev/null || { record_result "Release 빌드" "FAIL" "cd $CLI_DIR 실패"; return 1; }
    xcodebuild -scheme fSnippetCli -configuration Release build 2>&1 | tail -8
    local BUILD_STATUS=${PIPESTATUS[0]}
    popd > /dev/null || true
    if [ "$BUILD_STATUS" -eq 0 ]; then
        record_result "Release 빌드" "PASS" "xcodebuild 성공"
    else
        record_result "Release 빌드" "FAIL" "xcodebuild 실패 (exit=$BUILD_STATUS)"
        print_report "$TOTAL_PASS" "$TOTAL_FAIL" "${STEP_RESULTS[@]}"
        return 1
    fi

    # Step 2: 기존 설치 완전 정리 (launchd bootout + pkill + brew uninstall)
    # 목적: stale launchd 등록으로 인한 bootstrap EIO(5) 예방 및 새 서명 바이너리 clean install
    echo ""
    echo "=== Step 2: 기존 설치 완전 정리 ==="
    # 2-1: brew services stop (launchd 정상 경로)
    brew services stop fsnippet-cli 2>/dev/null || true
    # 2-2: stale LaunchAgent 잔존 시 강제 bootout (idempotent — 미등록 상태여도 무해)
    launchctl bootout "gui/$(id -u)/homebrew.mxcl.fsnippet-cli" 2>/dev/null || true
    sleep 0.3
    # 2-3: 잔여 프로세스 강제 종료
    if pgrep -f "MacOS/fSnippetCli" > /dev/null 2>&1; then
        echo "fSnippetCli 프로세스 감지 — pkill"
        pkill -f "MacOS/fSnippetCli" 2>/dev/null || true
        sleep 0.5
    fi
    # 2-4: brew uninstall (재설치 전 완전 제거 — 새 서명 바이너리 clean swap 보장)
    if brew list fsnippet-cli &>/dev/null; then
        echo "── brew uninstall fsnippet-cli (선행)"
        brew uninstall fsnippet-cli 2>&1 | tail -3
    fi
    record_result "기존 설치 완전 정리" "PASS" "services stop + bootout + pkill + uninstall"

    # Step 3: 로컬 tap 확인·생성
    echo ""
    echo "=== Step 3: 로컬 tap 확인·생성 (finfra/tap) ==="
    if [ ! -d "$TAP_DIR" ]; then
        echo "tap 미존재 — 생성 시도"
        if brew tap-new finfra/tap 2>/dev/null; then
            record_result "로컬 tap" "PASS" "brew tap-new finfra/tap"
        else
            echo "brew tap-new 실패 — 수동 mkdir fallback"
            mkdir -p "$TAP_DIR/Formula"
            pushd "$TAP_DIR" > /dev/null || true
            git init -q 2>/dev/null || true
            popd > /dev/null || true
            record_result "로컬 tap" "PASS" "수동 mkdir fallback"
        fi
    else
        record_result "로컬 tap" "PASS" "이미 존재: $TAP_DIR"
    fi

    # Step 4: 로컬 tarball 생성 (서명된 .app 포함 — A-2 방식)
    echo ""
    echo "=== Step 4: 로컬 tarball 생성 (서명된 .app 포함) ==="
    # Step 1에서 빌드된 .app 경로 조회
    local BUILT_APP
    BUILT_APP=$(cd "$CLI_DIR" && xcodebuild -scheme fSnippetCli -configuration Release -showBuildSettings 2>/dev/null | awk -F ' = ' '/ TARGET_BUILD_DIR =/ {print $2}' | xargs)
    if [ -z "$BUILT_APP" ] || [ ! -d "$BUILT_APP/fSnippetCli.app" ]; then
        record_result "tarball 생성" "FAIL" "빌드된 .app 미존재: $BUILT_APP/fSnippetCli.app"
        print_report "$TOTAL_PASS" "$TOTAL_FAIL" "${STEP_RESULTS[@]}"
        return 1
    fi
    # 서명 유지를 위해 -p (permissions) 옵션 사용
    # Homebrew가 단일 루트 디렉토리를 buildpath로 인식하므로
    # .app를 감싸는 디렉토리(fsnippet-cli-pkg)를 추가하여 정상 unpack 유도
    local TAR_STAGE
    TAR_STAGE=$(mktemp -d)
    mkdir -p "$TAR_STAGE/fsnippet-cli-pkg"
    cp -R "$BUILT_APP/fSnippetCli.app" "$TAR_STAGE/fsnippet-cli-pkg/"
    tar -C "$TAR_STAGE" -czpf "$TARBALL" fsnippet-cli-pkg
    local TAR_STATUS=$?
    rm -rf "$TAR_STAGE"
    if [ "$TAR_STATUS" -eq 0 ]; then
        local SHA
        SHA=$(shasum -a 256 "$TARBALL" | awk '{print $1}')
        echo "tarball: $TARBALL (from $BUILT_APP)"
        echo "sha256 : $SHA"
        record_result "tarball 생성" "PASS" "$(du -h "$TARBALL" | awk '{print $1}') (서명된 .app)"
    else
        record_result "tarball 생성" "FAIL" "tar czpf 실패 (exit=$TAR_STATUS)"
        print_report "$TOTAL_PASS" "$TOTAL_FAIL" "${STEP_RESULTS[@]}"
        return 1
    fi

    # Step 5: 로컬 tap Formula 작성
    echo ""
    echo "=== Step 5: 로컬 tap Formula 갱신 ==="
    mkdir -p "$(dirname "$TAP_FORMULA")"
    cat > "$TAP_FORMULA" <<FORMULA
class FsnippetCli < Formula
  desc "Text snippet expansion engine daemon for fSnippet (local build)"
  homepage "https://github.com/Finfra/fSnippet_public"
  url "file://$TARBALL"
  version "$LOCAL_VERSION"
  sha256 "$SHA"
  license "MIT"

  depends_on :macos

  def install
    # tarball에 사전 빌드된 fSnippetCli.app 포함됨 (Apple Development 서명 유지).
    # brew sandbox에서는 키체인 접근이 제한되므로 재빌드하지 않고 그대로 복사.
    prefix.install "fSnippetCli.app"
  end

  service do
    run [opt_prefix/"fSnippetCli.app/Contents/MacOS/fSnippetCli"]
    keep_alive successful_exit: false
    run_at_load true
    log_path var/"log/fsnippet-cli.log"
    error_log_path var/"log/fsnippet-cli.err.log"
    process_type :interactive
  end

  def caveats
    <<~EOS
      fSnippetCli requires Accessibility permissions.

      To enable auto-start after installation:
        brew services start finfra/tap/fsnippet-cli

      To grant Accessibility permissions:
        System Settings > Privacy & Security > Accessibility > fSnippetCli

      If TCC permissions are corrupted, reset via Xcode Debug path: /run tcc
    EOS
  end

  test do
    assert_predicate prefix/"fSnippetCli.app/Contents/MacOS/fSnippetCli", :exist?
  end
end
FORMULA
    echo "$TAP_FORMULA"
    record_result "Formula 갱신" "PASS" "file:// URL + SHA256 + version=$LOCAL_VERSION"

    # Step 6: brew install (uninstall은 Step 2에서 선행 완료)
    echo ""
    echo "=== Step 6: brew install ==="
    brew install --build-from-source finfra/tap/fsnippet-cli 2>&1 | tail -20
    local INSTALL_STATUS=${PIPESTATUS[0]}
    if [ "$INSTALL_STATUS" -eq 0 ]; then
        record_result "brew install" "PASS" "finfra/tap/fsnippet-cli"
    else
        record_result "brew install" "FAIL" "exit=$INSTALL_STATUS"
    fi

    # Step 7: /Applications/_nowage_app 심링크 생성 (Spotlight·Finder 편의용)
    # Issue46: TCC 3회 요청 회피를 위해 직접 open 실행은 제거. 실제 기동은 Step 8 LaunchAgent 단일 경로로 위임
    echo ""
    echo "=== Step 7: 심링크 생성 (Finder·Spotlight 편의용) ==="
    local STABLE_APP="$STABLE_LINK"
    if [ "$INSTALL_STATUS" -ne 0 ]; then
        record_result "심링크" "FAIL" "brew install 실패로 skip"
    else
        local INSTALLED_APP
        INSTALLED_APP="$(brew --prefix fsnippet-cli 2>/dev/null)/fSnippetCli.app"
        if [ -d "$INSTALLED_APP" ]; then
            mkdir -p /Applications/_nowage_app
            ln -sfn "$INSTALLED_APP" "$STABLE_APP"
            echo "[symlink] $STABLE_APP → $INSTALLED_APP"
            record_result "심링크" "PASS" "$STABLE_APP"
        else
            record_result "심링크" "FAIL" "설치 경로 미존재: $INSTALLED_APP"
        fi
    fi

    # Step 8: brew services 자동 등록 + Issue61 launchAtLogin 동기화
    # Formula의 service do 블록을 LaunchAgent plist로 변환 + load
    # Step 2에서 bootout + uninstall 완료 상태이므로 stale 잔존 우려 없음
    # Issue61 Phase3: _config.yml의 launchAtLogin 설정과 brew services 상태 동기화
    echo ""
    echo "=== Step 8: brew services 자동 시작 등록 + launchAtLogin 동기화 ==="

    # Issue61: _config.yml에서 launchAtLogin 설정값 읽기
    local CONFIG_FILE="$HOME/Documents/finfra/fSnippetData/_config.yml"
    local LAUNCH_AT_LOGIN="false"
    if [ -f "$CONFIG_FILE" ]; then
        # YAML 형식: launchAtLogin: true/false
        # grep -A1 로 다음 줄도 함께 추출 (멀티라인 YAML 대비), sed로 불린 값 추출
        # _config.yml uses snake_case `launch_at_login`; accept camelCase too for safety.
        LAUNCH_AT_LOGIN=$(grep -E "launch_at_login:|launchAtLogin:" "$CONFIG_FILE" | head -1 | awk '{print $2}' | tr -d '\r')
        [ -z "$LAUNCH_AT_LOGIN" ] && LAUNCH_AT_LOGIN="false"
        echo "[config] launchAtLogin: $LAUNCH_AT_LOGIN (from $CONFIG_FILE)"
    else
        echo "[config] $CONFIG_FILE 미존재 — launchAtLogin 기본값: false"
    fi

    # Issue61: launchAtLogin 값에 따라 brew services 상태 분기
    if [ "$LAUNCH_AT_LOGIN" = "true" ]; then
        echo "[sync] launchAtLogin=true → brew services start fsnippet-cli"
        brew services start finfra/tap/fsnippet-cli 2>&1 | tail -3
        local SVC_STATUS=${PIPESTATUS[0]}
        if [ "$SVC_STATUS" -eq 0 ]; then
            record_result "brew services start" "PASS" "finfra/tap/fsnippet-cli (launchAtLogin=true)"
        else
            record_result "brew services start" "FAIL" "exit=$SVC_STATUS"
        fi
    else
        # Issue67: launchAtLogin=false → brew services run (fWarrangeCli 패턴)
        # - brew services stop: LaunchAgents plist 제거 + launchd 해제
        # - brew services run: keg plist(/opt/homebrew/opt/...) 직접 사용, 재부팅 미지속
        echo "[sync] launchAtLogin=false → brew services run (keg plist, no LaunchAgents)"
        local PLIST_PATH="$HOME/Library/LaunchAgents/homebrew.mxcl.fsnippet-cli.plist"
        local PLIST_PATH_ALT="$HOME/Library/LaunchAgents/kr.finfra.fSnippetCli.plist"
        if [ -f "$PLIST_PATH" ]; then
            brew services stop fsnippet-cli 2>/dev/null || true
            launchctl bootout "gui/$(id -u)/homebrew.mxcl.fsnippet-cli" 2>/dev/null || true
            rm -f "$PLIST_PATH"
            echo "  ✅ LaunchAgents plist 제거: $PLIST_PATH"
        fi
        [ -f "$PLIST_PATH_ALT" ] && rm -f "$PLIST_PATH_ALT"
        sleep 0.3
        brew services run finfra/tap/fsnippet-cli 2>&1 | tail -3
        local RUN_STATUS=${PIPESTATUS[0]}
        if [ "$RUN_STATUS" -eq 0 ]; then
            record_result "brew services run" "PASS" "keg plist 직접 실행 (launchAtLogin=false)"
        else
            record_result "brew services run" "FAIL" "exit=$RUN_STATUS"
        fi
    fi

    # Step 9: REST API 헬스 체크 (자동 기동된 경우에만 실측)
    echo ""
    echo "=== Step 9: REST API 헬스 체크 ==="
    if [ "${FSC_AUTOSTART:-1}" != "1" ]; then
        echo "ℹ️  FSC_AUTOSTART=0 — 앱 미기동 상태. 검증을 원하면:"
        echo "    brew services start fsnippet-cli  (LaunchAgent 경유 기동)"
        echo "  또는 Finder·Spotlight 로 /Applications/_nowage_app/fSnippetCli.app 실행"
        record_result "REST API" "PASS" "skip (앱 미기동 상태)"
    else
        local HEALTH=""
        for _i in $(seq 1 10); do
            HEALTH=$(curl -s --connect-timeout 2 http://localhost:3015/ 2>/dev/null)
            [ -n "$HEALTH" ] && break
            sleep 1
        done
        if [ -n "$HEALTH" ]; then
            echo "$HEALTH" | python3 -m json.tool 2>/dev/null || echo "$HEALTH"
            record_result "REST API" "PASS" "포트 3015 응답 정상"
        else
            record_result "REST API" "FAIL" "10초 내 응답 없음 (접근성 미승인 가능성)"
        fi
    fi

    print_report "$TOTAL_PASS" "$TOTAL_FAIL" "${STEP_RESULTS[@]}"
    tcc_notice
    return "$TOTAL_FAIL"
}

# ==========================================
# 서브커맨드: publish (Issue167 — fWarrange 패턴 미러)
# ==========================================
# 동작:
#   1. Release 빌드 → 서명된 fSnippetCli.app
#   2. 릴리스 tarball 생성 (fsnippet-cli-pkg/fSnippetCli.app wrapper)
#   3. git tag cli-v{ver} + gh release create (Finfra/fSnippet_public) + asset 업로드
#   4. asset sha256 산출 → cli/Formula/fsnippet-cli.rb (repo SSOT) url/version/sha 갱신
#   5. 원격 Finfra/homebrew-tap 클론 → Formula 복사 → commit → push
# 사전 조건: gh CLI 인증, Finfra/fSnippet_public·Finfra/homebrew-tap repo 존재
cmd_publish() {
    local PUB_OWNER="Finfra"
    local SRC_REPO="$PUB_OWNER/fSnippet_public"
    local TAP_REPO="$PUB_OWNER/homebrew-tap"
    local VER="$LOCAL_VERSION"
    local TAG="cli-v$VER"
    local ASSET="fSnippetCli-$VER.tar.gz"
    local REPO_FORMULA="$CLI_DIR/Formula/fsnippet-cli.rb"
    local REL_TARBALL="/tmp/$ASSET"

    echo "╔══════════════════════════════════════════╗"
    echo "║  fSnippetCli Brew Deploy (publish)       ║"
    echo "╚══════════════════════════════════════════╝"
    echo "  version : $VER"
    echo "  tag     : $TAG"
    echo "  src     : $SRC_REPO"
    echo "  tap     : $TAP_REPO"
    echo ""

    # ── 사전 조건 검증 ──
    if ! command -v gh >/dev/null 2>&1; then
        echo "❌ gh CLI 미설치 — brew install gh"
        return 1
    fi
    if ! gh auth status >/dev/null 2>&1; then
        echo "❌ gh 미인증 — gh auth login"
        return 1
    fi
    if [ "$VER" = "0.0.0-local" ] || [ -z "$VER" ]; then
        echo "❌ VERSION 미확인 ($_VERSION_FILE). publish 중단."
        return 1
    fi

    # ── Step 0: VERSION → MARKETING_VERSION 동기화 (드리프트 방지·층1, Issue170) ──
    # VERSION(SSOT)을 xcodeproj MARKETING_VERSION 으로 강제 주입 → Info.plist
    # CFBundleShortVersionString($(MARKETING_VERSION))·API /status version 자동 일치.
    echo "=== Step 0: VERSION → MARKETING_VERSION 동기화 ($VER) ==="
    /usr/bin/sed -i '' "s/MARKETING_VERSION: \"[^\"]*\"/MARKETING_VERSION: \"$VER\"/" "$CLI_DIR/project.yml"
    /usr/bin/sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $VER;/g" \
        "$CLI_DIR/fSnippetCli.xcodeproj/project.pbxproj"
    echo "  MARKETING_VERSION → $VER (project.yml + pbxproj Debug/Release)"
    echo ""

    # ── Step 1: Release 빌드 ──
    echo "=== Step 1: Release 빌드 ==="
    pushd "$CLI_DIR" > /dev/null || { echo "❌ cd $CLI_DIR 실패"; return 1; }
    xcodebuild -scheme fSnippetCli -configuration Release build 2>&1 | tail -6
    local BUILD_STATUS=${PIPESTATUS[0]}
    popd > /dev/null || true
    if [ "$BUILD_STATUS" -ne 0 ]; then
        echo "❌ 빌드 실패 (exit=$BUILD_STATUS)"
        return 1
    fi

    # ── Step 2: 릴리스 tarball 생성 ──
    echo ""
    echo "=== Step 2: 릴리스 tarball 생성 ==="
    local BUILT_APP
    BUILT_APP=$(cd "$CLI_DIR" && xcodebuild -scheme fSnippetCli -configuration Release -showBuildSettings 2>/dev/null | awk -F ' = ' '/ TARGET_BUILD_DIR =/ {print $2}' | xargs)
    if [ -z "$BUILT_APP" ] || [ ! -d "$BUILT_APP/fSnippetCli.app" ]; then
        echo "❌ 빌드된 .app 미존재: $BUILT_APP/fSnippetCli.app"
        return 1
    fi
    local TAR_STAGE
    TAR_STAGE=$(mktemp -d)
    mkdir -p "$TAR_STAGE/fsnippet-cli-pkg"
    cp -R "$BUILT_APP/fSnippetCli.app" "$TAR_STAGE/fsnippet-cli-pkg/"
    tar -C "$TAR_STAGE" -czpf "$REL_TARBALL" fsnippet-cli-pkg
    local TAR_STATUS=$?
    rm -rf "$TAR_STAGE"
    if [ "$TAR_STATUS" -ne 0 ]; then
        echo "❌ tar 실패 (exit=$TAR_STATUS)"
        return 1
    fi
    local SHA
    SHA=$(shasum -a 256 "$REL_TARBALL" | awk '{print $1}')
    echo "  tarball: $REL_TARBALL ($(du -h "$REL_TARBALL" | awk '{print $1}'))"
    echo "  sha256 : $SHA"

    # ── Step 2.5: 버전 검증 게이트 (드리프트 방지·층2, Issue170) ──
    # 빌드된 .app Info.plist 실제 버전 ≠ VERSION 이면 release 발행·tap push 전 중단.
    # Step 0 동기화가 어떤 이유로 실패해도 엉뚱한 버전의 공개 release 발행을 차단.
    local BUILT_VER
    BUILT_VER=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" \
        "$BUILT_APP/fSnippetCli.app/Contents/Info.plist" 2>/dev/null)
    if [ "$BUILT_VER" != "$VER" ]; then
        echo "❌ 버전 불일치 — Info.plist=$BUILT_VER, VERSION=$VER. publish 중단."
        echo "   (Step 0 MARKETING_VERSION 동기화 또는 빌드 캐시 확인)"
        return 1
    fi
    echo "  ✅ Info.plist 버전 검증: $BUILT_VER == $VER"

    # ── Step 2.9: git tag + push (F5-4 / prj1#Issue346) ──
    # 왜: 지금까지 태그는 `gh release create` 가 **원격 기본 브랜치 HEAD 에** 대신
    #   만들어 줬다. 그래서 태그가 붙는 커밋이 지금 빌드한 커밋이라는 보장이 없다.
    #   prj26(fwc-deploy-brew.sh Step 3) 처럼 로컬에서 명시적으로 붙이고 push 한 뒤
    #   gh release 가 그 태그를 재사용하게 한다.
    # ⚠️ fail-soft — 이미 존재하는 태그로 재배포하는 경우가 정상 경로에 있다.
    echo ""
    echo "=== Step 2.9: git tag $TAG + push ==="
    if git -C "$CLI_DIR" rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
        echo "  태그 이미 존재: $TAG (건너뜀)"
    elif git -C "$CLI_DIR" tag -a "$TAG" -m "fSnippetCli v$VER"; then
        git -C "$CLI_DIR" push origin "$TAG" 2>&1 | tail -2 \
            || echo "  ⚠️ 태그 push 실패: $TAG (로컬에는 생성됨)"
        echo "  🏷 $TAG → $(git -C "$CLI_DIR" rev-parse --short "$TAG^{commit}")"
    else
        echo "  ⚠️ 태그 생성 실패: $TAG"
    fi

    # ── Step 3: GitHub release + asset ──
    echo ""
    echo "=== Step 3: GitHub release ($TAG) + asset 업로드 ==="
    local ASSET_URL="https://github.com/$SRC_REPO/releases/download/$TAG/$ASSET"
    if gh release view "$TAG" -R "$SRC_REPO" >/dev/null 2>&1; then
        echo "  릴리스 $TAG 이미 존재 — asset 갱신(--clobber)"
        gh release upload "$TAG" "$REL_TARBALL" -R "$SRC_REPO" --clobber 2>&1 | tail -3
    else
        echo "  릴리스 $TAG 생성 + asset 업로드"
        gh release create "$TAG" "$REL_TARBALL" \
            -R "$SRC_REPO" \
            --title "fSnippetCli v$VER" \
            --notes "fSnippetCli v$VER — Homebrew tap release (brew install $PUB_OWNER/tap/fsnippet-cli)" \
            2>&1 | tail -3
    fi
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        echo "❌ gh release 실패"
        return 1
    fi

    # ── Step 4: repo Formula 갱신 ──
    echo ""
    echo "=== Step 4: repo Formula 갱신 ($REPO_FORMULA) ==="
    if [ ! -f "$REPO_FORMULA" ]; then
        echo "❌ Formula 미존재: $REPO_FORMULA"
        return 1
    fi
    # url/version/sha256 3줄만 치환 (나머지 install/service 블록 보존)
    /usr/bin/sed -i '' \
        -e "s|^  url .*|  url \"$ASSET_URL\"|" \
        -e "s|^  version .*|  version \"$VER\"|" \
        -e "s|^  sha256 .*|  sha256 \"$SHA\"|" \
        "$REPO_FORMULA"
    echo "  갱신됨:"
    grep -E '^\s*(url|version|sha256)' "$REPO_FORMULA" | sed 's/^/    /'

    # ── Step 5: 원격 tap push ──
    echo ""
    echo "=== Step 5: 원격 tap push ($TAP_REPO) ==="
    local TAP_CLONE
    TAP_CLONE=$(mktemp -d)
    if ! gh repo clone "$TAP_REPO" "$TAP_CLONE/tap" -- -q 2>&1 | tail -2; then
        echo "❌ tap 클론 실패"
        rm -rf "$TAP_CLONE"
        return 1
    fi
    mkdir -p "$TAP_CLONE/tap/Formula"
    cp "$REPO_FORMULA" "$TAP_CLONE/tap/Formula/fsnippet-cli.rb"
    pushd "$TAP_CLONE/tap" > /dev/null || { rm -rf "$TAP_CLONE"; return 1; }
    git add Formula/fsnippet-cli.rb
    if git diff --cached --quiet; then
        echo "  변경 없음 — push 생략 (Formula 동일)"
    else
        git commit -q -m "fsnippet-cli $VER ($TAG)"
        if git push -q origin HEAD 2>&1 | tail -3; then
            echo "  ✅ push 완료: $TAP_REPO"
        else
            echo "❌ tap push 실패"
            popd > /dev/null || true
            rm -rf "$TAP_CLONE"
            return 1
        fi
    fi
    popd > /dev/null || true
    rm -rf "$TAP_CLONE"

    # ── 배포 인벤토리 기록 (F5-5 / prj1#Issue346) ──
    local _DEPLOY_RECORD="$HOME/_git/___pm/scripts/fpm-deploy-record.sh"
    if [ -f "$_DEPLOY_RECORD" ]; then
        bash "$_DEPLOY_RECORD" --prj 25 --name fSnippetCli --version "$VER" \
            --channel homebrew --tag "$TAG" \
            --commit "$(git -C "$CLI_DIR" rev-parse --short HEAD)" \
            || echo "⚠️ 배포 기록 실패 (배포 자체는 완료됨)"
    fi

    # ── 완료 ──
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║  🎉 publish 완료                          ║"
    echo "╚══════════════════════════════════════════╝"
    echo "  검증: brew update && brew install $PUB_OWNER/tap/fsnippet-cli"
    echo "  asset: $ASSET_URL"
    return 0
}

# ==========================================
# 서브커맨드: status
# ==========================================
cmd_status() {
    echo "╔══════════════════════════════════════════╗"
    echo "║  fSnippetCli Brew Status                 ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    echo "── brew 설치 ──"
    if brew list fsnippet-cli &>/dev/null; then
        local VERSION
        VERSION=$(brew list --versions fsnippet-cli | awk '{print $2}')
        local PREFIX
        PREFIX=$(brew --prefix fsnippet-cli 2>/dev/null)
        echo "✅ 설치됨: fsnippet-cli $VERSION"
        echo "   prefix : $PREFIX"
        [ -d "$PREFIX/fSnippetCli.app" ] && echo "   .app   : $PREFIX/fSnippetCli.app"
    else
        echo "❌ 미설치"
    fi
    echo ""

    echo "── 로컬 tap ──"
    if [ -d "$TAP_DIR" ]; then
        echo "✅ 존재: $TAP_DIR"
        if [ -f "$TAP_FORMULA" ]; then
            echo "   Formula: $TAP_FORMULA"
            grep -E '^\s*(url|version|sha256)' "$TAP_FORMULA" | sed 's/^/     /'
        else
            echo "   Formula 파일 없음"
        fi
    else
        echo "❌ tap 미설치 ($TAP_DIR)"
    fi
    echo ""

    # Issue44: /Applications/_nowage_app 심링크 상태
    echo "── 심링크 (/Applications/_nowage_app) ──"
    local STABLE_APP="$STABLE_LINK"
    if [ -L "$STABLE_APP" ]; then
        local target
        target="$(readlink "$STABLE_APP")"
        echo "✅ 심링크 존재: $STABLE_APP"
        echo "   → $target"
        [ -d "$target" ] || echo "   ⚠️  타겟 미존재 (stale 심링크)"
    elif [ -e "$STABLE_APP" ]; then
        echo "⚠️  실제 파일/디렉토리 존재 (심링크 아님): $STABLE_APP"
    else
        echo "❌ 미생성 — /deploy brew local 실행 시 Step 7에서 자동 생성됨"
    fi
    echo ""

    # Issue45: brew services 상태
    echo "── brew services ──"
    local svc_info
    svc_info=$(brew services info fsnippet-cli 2>&1)
    if echo "$svc_info" | grep -q "Loaded: true"; then
        echo "✅ LaunchAgent 등록됨"
        echo "$svc_info" | grep -E "^(fsnippet-cli|Running|Loaded|Schedulable|File|User):" | sed 's/^/  /'
    elif brew list fsnippet-cli &>/dev/null; then
        echo "ℹ️  설치됐으나 brew services 미등록"
        echo "   등록: brew services start finfra/tap/fsnippet-cli"
    else
        echo "❌ 미설치"
    fi
    echo ""

    echo "── 프로세스 ──"
    if pgrep -fl "MacOS/fSnippetCli" 2>/dev/null; then
        :
    else
        echo "(실행 중 아님)"
    fi
    echo ""

    echo "── REST API (port 3015) ──"
    local HEALTH
    HEALTH=$(curl -s --connect-timeout 2 http://localhost:3015/ 2>/dev/null)
    if [ -n "$HEALTH" ]; then
        echo "✅ 응답 정상"
        echo "$HEALTH" | python3 -m json.tool 2>/dev/null | sed 's/^/  /'
    else
        echo "❌ 응답 없음"
    fi
}

# ==========================================
# 서브커맨드: uninstall
# ==========================================
cmd_uninstall() {
    echo "╔══════════════════════════════════════════╗"
    echo "║  fSnippetCli Brew Uninstall              ║"
    echo "╚══════════════════════════════════════════╝"

    # Issue45: brew services 선행 중지 (launchd 경로)
    echo "── brew services stop (선행)"
    brew services stop fsnippet-cli 2>/dev/null || true
    sleep 0.3

    # 프로세스 종료 (services stop 실패 대비)
    if pgrep -f "MacOS/fSnippetCli" > /dev/null 2>&1; then
        echo "── 프로세스 종료"
        pkill -f "MacOS/fSnippetCli" 2>/dev/null || true
        sleep 0.3
    fi

    # Issue44 (obsolete): /Applications/_nowage_app 심링크 제거 (§7-4 심링크 전략은 유지, 파일만 정리)
    local STABLE_APP="$STABLE_LINK"
    if [ -L "$STABLE_APP" ] || [ -e "$STABLE_APP" ]; then
        echo "── 심링크 제거"
        rm -f "$STABLE_APP"
        echo "✅ 제거: $STABLE_APP"
    fi

    echo "── brew uninstall fsnippet-cli"
    brew uninstall fsnippet-cli 2>&1 | tail -5

    echo "── 로컬 tap Formula 제거"
    if [ -f "$TAP_FORMULA" ]; then
        rm -f "$TAP_FORMULA"
        echo "✅ 제거: $TAP_FORMULA"
    else
        echo "(없음: $TAP_FORMULA)"
    fi

    echo "── tarball 제거"
    if [ -f "$TARBALL" ]; then
        rm -f "$TARBALL"
        echo "✅ 제거: $TARBALL"
    else
        echo "(없음: $TARBALL)"
    fi

    echo ""
    echo "ℹ️  finfra/tap 디렉토리($TAP_DIR)는 유지함 — 완전 제거하려면:"
    echo "    brew untap finfra/tap"
}

# ==========================================
# 공용: 리포트 출력
# ==========================================
print_report() {
    local pass="$1" fail="$2"
    shift 2
    local results=("$@")

    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║         Brew Deploy 결과                 ║"
    echo "╠══════════════════════════════════════════╣"
    for r in "${results[@]}"; do
        printf "║  %-40s║\n" "$r"
    done
    echo "╠══════════════════════════════════════════╣"
    if [ "$fail" -eq 0 ]; then
        printf "║  🎉 ALL CLEAR: %d PASS / %d FAIL         ║\n" "$pass" "$fail"
    else
        printf "║  ⚠️  ISSUES: %d PASS / %d FAIL           ║\n" "$pass" "$fail"
    fi
    echo "╚══════════════════════════════════════════╝"
}

# ==========================================
# 디스패치
# ==========================================
SUB="${1:-}"
case "$SUB" in
    local)
        cmd_local
        ;;
    publish)
        # publish 성공 시 로컬 머신에도 설치 (사용자 요청: deploy 시 local install 동반).
        # 원격 tap push 후 개발 머신이 최신 릴리스를 곧바로 실행하도록 cmd_local 체이닝.
        if cmd_publish; then
            echo ""
            echo "╔══════════════════════════════════════════╗"
            echo "║  publish 후속: 로컬 install (brew local) ║"
            echo "╚══════════════════════════════════════════╝"
            cmd_local
        else
            PUB_STATUS=$?
            echo "❌ publish 실패 (exit=$PUB_STATUS) — 로컬 install 생략"
            exit "$PUB_STATUS"
        fi
        ;;
    status)
        cmd_status
        ;;
    uninstall)
        cmd_uninstall
        ;;
    "")
        usage
        exit 1
        ;;
    *)
        echo "❌ 알 수 없는 서브커맨드: $SUB"
        echo ""
        usage
        exit 1
        ;;
esac
