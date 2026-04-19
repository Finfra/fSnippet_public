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
ROOT_DIR="$(dirname "$CLI_DIR")"
TAP_DIR="/opt/homebrew/Library/Taps/finfra/homebrew-tap"
TAP_FORMULA="$TAP_DIR/Formula/fsnippetcli.rb"
TARBALL="/tmp/fSnippetCli-local.tar.gz"
LOCAL_VERSION="0.0.0-local"

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
  publish     원격 finfra/homebrew-tap 저장소에 Formula 반영 + push        🚧 TODO
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

    # Step 2: 기존 프로세스 정리
    echo ""
    echo "=== Step 2: 기존 프로세스 정리 ==="
    if pgrep -f "MacOS/fSnippetCli" > /dev/null 2>&1; then
        echo "fSnippetCli 프로세스 감지 — pkill"
        pkill -f "MacOS/fSnippetCli" 2>/dev/null || true
        sleep 0.5
    fi
    record_result "기존 프로세스 정리" "PASS" "pkill"

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

    # Step 4: 로컬 tarball 생성
    echo ""
    echo "=== Step 4: 로컬 tarball 생성 ==="
    pushd "$ROOT_DIR" > /dev/null || { record_result "tarball 생성" "FAIL" "cd $ROOT_DIR 실패"; print_report "$TOTAL_PASS" "$TOTAL_FAIL" "${STEP_RESULTS[@]}"; return 1; }
    tar czf "$TARBALL" cli/
    local TAR_STATUS=$?
    popd > /dev/null || true
    if [ "$TAR_STATUS" -eq 0 ]; then
        local SHA
        SHA=$(shasum -a 256 "$TARBALL" | awk '{print $1}')
        echo "tarball: $TARBALL"
        echo "sha256 : $SHA"
        record_result "tarball 생성" "PASS" "$(du -h "$TARBALL" | awk '{print $1}')"
    else
        record_result "tarball 생성" "FAIL" "tar czf 실패 (exit=$TAR_STATUS)"
        print_report "$TOTAL_PASS" "$TOTAL_FAIL" "${STEP_RESULTS[@]}"
        return 1
    fi

    # Step 5: 로컬 tap Formula 작성
    echo ""
    echo "=== Step 5: 로컬 tap Formula 갱신 ==="
    mkdir -p "$(dirname "$TAP_FORMULA")"
    cat > "$TAP_FORMULA" <<FORMULA
class Fsnippetcli < Formula
  desc "Text snippet expansion engine daemon for fSnippet (local build)"
  homepage "https://github.com/Finfra/fSnippet_public"
  url "file://$TARBALL"
  version "$LOCAL_VERSION"
  sha256 "$SHA"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["15.0", :build]

  def install
    # Homebrew가 tarball의 최상위 'cli/' 폴더로 자동 진입한 상태로 install 호출됨
    system "xcodebuild", "-project", "fSnippetCli.xcodeproj",
           "-scheme", "fSnippetCli",
           "-configuration", "Release",
           "-derivedDataPath", buildpath/"build",
           "MACOSX_DEPLOYMENT_TARGET=14.0",
           "SYMROOT=#{buildpath}/build",
           "CODE_SIGN_IDENTITY=-",
           "CODE_SIGNING_REQUIRED=NO",
           "CODE_SIGNING_ALLOWED=NO"
    prefix.install Dir["build/Release/fSnippetCli.app"]
  end

  service do
    run [opt_prefix/"fSnippetCli.app/Contents/MacOS/fSnippetCli"]
    keep_alive true
    log_path var/"log/fsnippetcli.log"
    error_log_path var/"log/fsnippetcli.err.log"
    process_type :interactive
  end

  def caveats
    <<~EOS
      fSnippetCli는 접근성(Accessibility) 권한이 필요합니다.

      설치 후 자동 시작 등록:
        brew services start finfra/tap/fsnippetcli

      권한 승인:
        시스템 설정 > 개인정보 보호 및 보안 > 접근성 > fSnippetCli 체크

      TCC 권한이 꼬이면 Xcode Debug 경로로 재설정: /run tcc
    EOS
  end

  test do
    assert_predicate prefix/"fSnippetCli.app/Contents/MacOS/fSnippetCli", :exist?
  end
end
FORMULA
    echo "$TAP_FORMULA"
    record_result "Formula 갱신" "PASS" "file:// URL + SHA256 + version=$LOCAL_VERSION"

    # Step 6: brew uninstall + install
    echo ""
    echo "=== Step 6: brew uninstall + install ==="
    brew uninstall fsnippetcli 2>/dev/null || true
    brew install --build-from-source finfra/tap/fsnippetcli 2>&1 | tail -20
    local INSTALL_STATUS=${PIPESTATUS[0]}
    if [ "$INSTALL_STATUS" -eq 0 ]; then
        record_result "brew install" "PASS" "finfra/tap/fsnippetcli"
    else
        record_result "brew install" "FAIL" "exit=$INSTALL_STATUS"
    fi

    # Step 7: /Applications/_nowage_app 심링크 + 앱 실행
    echo ""
    echo "=== Step 7: 심링크 생성 + 앱 실행 ==="
    local STABLE_APP="/Applications/_nowage_app/fSnippetCli.app"
    if [ "$INSTALL_STATUS" -ne 0 ]; then
        record_result "앱 실행" "FAIL" "brew install 실패로 skip"
    else
        local INSTALLED_APP
        INSTALLED_APP="$(brew --prefix fsnippetcli 2>/dev/null)/fSnippetCli.app"
        if [ -d "$INSTALLED_APP" ]; then
            # Issue44: Cellar 경로 stale 문제 방지 — /Applications/_nowage_app 심링크로 안정적 엔트리 포인트 제공
            mkdir -p /Applications/_nowage_app
            ln -sfn "$INSTALLED_APP" "$STABLE_APP"
            echo "[symlink] $STABLE_APP → $INSTALLED_APP"
            echo "[open] $STABLE_APP"
            open "$STABLE_APP"
            local OPEN_STATUS=$?
            if [ "$OPEN_STATUS" -eq 0 ]; then
                record_result "심링크 + 앱 실행" "PASS" "$STABLE_APP"
            else
                record_result "심링크 + 앱 실행" "FAIL" "open 실패 (exit=$OPEN_STATUS)"
            fi
        else
            record_result "심링크 + 앱 실행" "FAIL" "설치 경로 미존재: $INSTALLED_APP"
        fi
    fi

    # Step 8: brew services 자동 등록 (FSC_AUTOSTART=1 옵트인 — Issue45)
    # Formula의 service do 블록을 LaunchAgent plist로 변환 + load
    echo ""
    echo "=== Step 8: brew services 자동 시작 등록 (옵트인) ==="
    if [ "${FSC_AUTOSTART:-0}" = "1" ]; then
        # 기존 서비스 중지 (idempotent — 미시작 상태에서도 무해)
        brew services stop fsnippetcli 2>/dev/null || true
        brew services start finfra/tap/fsnippetcli 2>&1 | tail -3
        local SVC_STATUS=${PIPESTATUS[0]}
        if [ "$SVC_STATUS" -eq 0 ]; then
            record_result "brew services start" "PASS" "finfra/tap/fsnippetcli"
        else
            record_result "brew services start" "FAIL" "exit=$SVC_STATUS"
        fi
    else
        echo "ℹ️  FSC_AUTOSTART 미설정 — 로그인 시 자동 기동을 원하면:"
        echo "    FSC_AUTOSTART=1 /deploy brew local"
        echo "   또는 개별 등록: brew services start finfra/tap/fsnippetcli"
        record_result "brew services" "PASS" "skip (FSC_AUTOSTART 미설정)"
    fi

    # Step 9: REST API 헬스 체크
    echo ""
    echo "=== Step 9: REST API 헬스 체크 ==="
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

    print_report "$TOTAL_PASS" "$TOTAL_FAIL" "${STEP_RESULTS[@]}"
    tcc_notice
    return "$TOTAL_FAIL"
}

# ==========================================
# 서브커맨드: publish (TODO)
# ==========================================
cmd_publish() {
    echo "🚧 /deploy brew publish 는 아직 미구현 (Issue43 Phase B)"
    echo ""
    echo "예정 동작:"
    echo "  1. GitHub 태그 생성 (예: cli-v0.0.1)"
    echo "  2. gh release create + tarball 업로드"
    echo "  3. Formula 'url'/'sha256'/'version' 갱신"
    echo "  4. 원격 finfra/homebrew-tap 저장소 push"
    echo ""
    echo "사전 조건:"
    echo "  - 원격 finfra/homebrew-tap GitHub 저장소 생성 (public)"
    echo "  - gh CLI 인증 (gh auth login)"
    echo "  - HOMEBREW_TAP_TOKEN (tap 레포 write PAT)"
    echo ""
    echo "참고 가이드: ~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md"
    return 1
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
    if brew list fsnippetcli &>/dev/null; then
        local VERSION
        VERSION=$(brew list --versions fsnippetcli | awk '{print $2}')
        local PREFIX
        PREFIX=$(brew --prefix fsnippetcli 2>/dev/null)
        echo "✅ 설치됨: fsnippetcli $VERSION"
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
    local STABLE_APP="/Applications/_nowage_app/fSnippetCli.app"
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
    svc_info=$(brew services info fsnippetcli 2>&1)
    if echo "$svc_info" | grep -q "Loaded: true"; then
        echo "✅ LaunchAgent 등록됨"
        echo "$svc_info" | grep -E "^(fsnippetcli|Running|Loaded|Schedulable|File|User):" | sed 's/^/  /'
    elif brew list fsnippetcli &>/dev/null; then
        echo "ℹ️  설치됐으나 brew services 미등록"
        echo "   등록: brew services start finfra/tap/fsnippetcli"
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
    brew services stop fsnippetcli 2>/dev/null || true
    sleep 0.3

    # 프로세스 종료 (services stop 실패 대비)
    if pgrep -f "MacOS/fSnippetCli" > /dev/null 2>&1; then
        echo "── 프로세스 종료"
        pkill -f "MacOS/fSnippetCli" 2>/dev/null || true
        sleep 0.3
    fi

    # Issue44 (obsolete): /Applications/_nowage_app 심링크 제거 (§7-4 심링크 전략은 유지, 파일만 정리)
    local STABLE_APP="/Applications/_nowage_app/fSnippetCli.app"
    if [ -L "$STABLE_APP" ] || [ -e "$STABLE_APP" ]; then
        echo "── 심링크 제거"
        rm -f "$STABLE_APP"
        echo "✅ 제거: $STABLE_APP"
    fi

    echo "── brew uninstall fsnippetcli"
    brew uninstall fsnippetcli 2>&1 | tail -5

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
        cmd_publish
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
