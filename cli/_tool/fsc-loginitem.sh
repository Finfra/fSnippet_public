#!/bin/bash
# Issue44: fSnippetCli Login Item 자동 등록 관리
# Usage: ./fsc-loginitem.sh <register|unregister|status>
#
# 목적:
#   - Homebrew 설치본 fSnippetCli.app을 사용자 로그인 시 자동 기동하도록 Login Item 등록
#   - brew services(launchd) 경로는 메뉴바 Agent 앱 특성상 부적합 → System Events 기반 Login Item 사용
#
# 설계 근거: ~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md §7-5
# 주의사항:
#   - 시스템 전역 상태(사용자 Login Items) 변경 — 암묵적 적용 금지, 옵트인만 허용
#   - SMAppService 등록과 동시 사용 금지 (이중 기동 유발)
#   - 앱 경로는 Homebrew --prefix 기준으로 동적 산출

set +e

APP_NAME="fSnippetCli"
FORMULA_NAME="fsnippetcli"

usage() {
    cat <<'USAGE'
Usage: ./fsc-loginitem.sh <subcommand>

  subcommand    설명
  -----------   ----------------------------------------------------------
  register      fSnippetCli.app을 Login Item에 등록 (중복 체크)
  unregister    Login Item에서 제거 (미등록 시 무해)
  status        현재 등록 상태 조회 (존재 여부 + 실제 경로)

예시:
  ./fsc-loginitem.sh register
  ./fsc-loginitem.sh status
  ./fsc-loginitem.sh unregister

설계 근거: ~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md §7-5
⚠️ SMAppService(앱 내부 자동 시작)와 동시 사용 금지 — 이중 기동 발생
USAGE
}

# .app 절대 경로 산출 (우선순위: /Applications/_nowage_app 심링크 → brew --prefix fallback)
# Issue44: Cellar 버전 폴더는 Homebrew 업그레이드 시 stale 경로가 됨 → 안정적 심링크 우선
resolve_app_path() {
    local stable_app="/Applications/_nowage_app/$APP_NAME.app"
    if [ -L "$stable_app" ] || [ -d "$stable_app" ]; then
        echo "$stable_app"
        return 0
    fi

    local brew_prefix
    brew_prefix="$(brew --prefix "$FORMULA_NAME" 2>/dev/null)"
    if [ -z "$brew_prefix" ] || [ ! -d "$brew_prefix/$APP_NAME.app" ]; then
        echo ""
        return 1
    fi
    echo "$brew_prefix/$APP_NAME.app"
}

# 등록된 path가 안정적 엔트리 포인트(심링크)를 사용하는지 검증
is_stable_path() {
    local registered="$1"
    [ "$registered" = "/Applications/_nowage_app/$APP_NAME.app" ]
}

cmd_register() {
    local app_path
    app_path="$(resolve_app_path)" || {
        echo "❌ Homebrew 설치본 없음 — 먼저 '/deploy brew local' 실행 필요"
        echo "   brew --prefix $FORMULA_NAME 로 경로 확인"
        return 1
    }

    echo "── Login Item 등록 시도"
    echo "   요청 path: $app_path"
    echo "   (macOS AppleScript는 심링크를 자동 resolve하므로"
    echo "    실제 저장 경로는 Cellar 버전 폴더가 됨 — 재등록 자동화로 stale 방지)"

    # Issue44: 기존 등록이 있으면 강제 재등록 (Homebrew 업그레이드 시 Cellar 경로 갱신용)
    local already
    already=$(osascript <<APPLESCRIPT 2>/dev/null
tell application "System Events"
    if exists login item "$APP_NAME" then
        return "exists"
    else
        return "missing"
    end if
end tell
APPLESCRIPT
    )

    if [ "$already" = "exists" ]; then
        echo "── 기존 등록 발견 — 재등록(unregister → register)"
        osascript <<APPLESCRIPT >/dev/null 2>&1
tell application "System Events"
    set matched to every login item whose name is "$APP_NAME"
    set cnt to count of matched
    repeat with i from cnt to 1 by -1
        delete (item i of matched)
    end repeat
end tell
APPLESCRIPT
    fi

    # 신규 등록
    local result
    result=$(osascript <<APPLESCRIPT 2>&1
tell application "System Events"
    make login item at end with properties ¬
        {path:"$app_path", hidden:false, name:"$APP_NAME"}
end tell
APPLESCRIPT
    )
    local rc=$?

    if [ "$rc" -eq 0 ]; then
        echo "✅ Login Item 등록 완료"
        echo "   다음 로그인부터 자동 기동됨"
        echo ""
        echo "⚠️  주의: SMAppService(앱 내부 AutoStartManager)가 활성화되어 있으면"
        echo "   중복 기동 방지를 위해 앱 설정에서 비활성화 권장"
    else
        echo "❌ 등록 실패 (exit=$rc)"
        echo "   osascript 결과: $result"
        echo ""
        echo "   수동 등록 경로:"
        echo "   시스템 설정 → 일반 → 로그인 항목 및 확장 프로그램 → + 버튼"
        echo "   대상: $app_path"
        return 1
    fi
}

cmd_unregister() {
    echo "── Login Item 해제 시도"

    local exists_flag
    exists_flag=$(osascript <<APPLESCRIPT 2>/dev/null
tell application "System Events"
    if exists login item "$APP_NAME" then
        return "exists"
    else
        return "missing"
    end if
end tell
APPLESCRIPT
    )

    if [ "$exists_flag" != "exists" ]; then
        echo "ℹ️  등록된 Login Item 없음 — 작업 없음"
        return 0
    fi

    local result
    result=$(osascript <<APPLESCRIPT 2>&1
tell application "System Events"
    delete login item "$APP_NAME"
end tell
APPLESCRIPT
    )
    local rc=$?

    if [ "$rc" -eq 0 ]; then
        echo "✅ Login Item 제거 완료"
    else
        echo "❌ 제거 실패 (exit=$rc)"
        echo "   osascript 결과: $result"
        return 1
    fi
}

cmd_status() {
    echo "╔══════════════════════════════════════════╗"
    echo "║  fSnippetCli Login Item Status           ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    local info
    info=$(osascript <<APPLESCRIPT 2>/dev/null
tell application "System Events"
    set matched to every login item whose name is "$APP_NAME"
    if (count of matched) is 0 then
        return "NOT_REGISTERED"
    end if
    set outList to {}
    repeat with li in matched
        set end of outList to (name of li) & "|" & (path of li) & "|" & (hidden of li as string)
    end repeat
    set AppleScript's text item delimiters to linefeed
    return outList as text
end tell
APPLESCRIPT
    )

    if [ "$info" = "NOT_REGISTERED" ] || [ -z "$info" ]; then
        echo "❌ 등록되지 않음"
        echo ""
        echo "등록하려면: ./fsc-loginitem.sh register"
    else
        echo "✅ 등록됨"
        echo ""
        # name|path|hidden 형식으로 출력됨 (여러 행 가능)
        while IFS='|' read -r name path hidden; do
            [ -z "$name" ] && continue
            echo "  name   : $name"
            echo "  path   : $path"
            echo "  hidden : $hidden"
            echo ""
        done <<< "$info"
    fi

    # Issue44: stale 경로 탐지 (실제 문제가 있을 때만 경고)
    # macOS AppleScript는 심링크를 자동 resolve하므로 Login Item은 항상 Cellar 경로로 저장됨
    # 이는 정상 동작 — Homebrew 업그레이드로 Cellar 버전 폴더가 바뀌면 재등록 필요
    # 전략: register는 항상 강제 재등록으로 stale을 원천 차단 (`/deploy brew local` 재실행 시마다 갱신)
    if [ "$info" != "NOT_REGISTERED" ] && [ -n "$info" ]; then
        local current_cellar=""
        if command -v brew >/dev/null 2>&1; then
            local prefix
            prefix="$(brew --prefix "$FORMULA_NAME" 2>/dev/null)"
            # /opt/homebrew/opt/fsnippetcli → readlink로 현재 Cellar 버전 추출
            if [ -L "$prefix" ]; then
                current_cellar="$(readlink "$prefix")"
                # 상대 경로면 prefix 부모 기준으로 절대화
                case "$current_cellar" in
                    /*) ;;
                    *) current_cellar="$(cd "$(dirname "$prefix")" && cd "$current_cellar" && pwd)" ;;
                esac
            fi
        fi

        local has_stale=false
        local has_missing=false
        while IFS='|' read -r _n registered_path _h; do
            [ -z "$registered_path" ] && continue
            if [ "$registered_path" = "missing value" ]; then
                has_missing=true
                continue
            fi
            # Cellar 경로인데 현재 brew --prefix 버전과 다르면 stale
            if echo "$registered_path" | grep -q "/opt/homebrew/Cellar/"; then
                if [ -n "$current_cellar" ] && ! echo "$registered_path" | grep -qF "$current_cellar"; then
                    has_stale=true
                fi
            fi
            # 파일 자체가 존재하지 않으면 stale
            [ -e "$registered_path" ] || has_missing=true
        done <<< "$info"

        if [ "$has_missing" = "true" ]; then
            echo "⚠️  경고: 등록된 path의 실제 파일이 존재하지 않음 (stale alias)"
            echo "   원인: 심링크 재생성 / Homebrew 재설치 / 앱 번들 삭제"
            echo "   재등록: ./fsc-loginitem.sh register"
        elif [ "$has_stale" = "true" ]; then
            echo "⚠️  경고: Cellar 경로가 현재 Homebrew 설치 버전과 다름"
            echo "   current: $current_cellar"
            echo "   Homebrew 업그레이드 후 재등록 필요: ./fsc-loginitem.sh register"
        fi
    fi
}

# ==========================================
# 디스패치
# ==========================================
SUB="${1:-}"
case "$SUB" in
    register)
        cmd_register
        ;;
    unregister)
        cmd_unregister
        ;;
    status)
        cmd_status
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
