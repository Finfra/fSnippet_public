#!/bin/bash
# Usage: run.sh [run-only|full]
#   인자 없음: 빌드 후 배포 및 실행
#   run-only: 빌드 없이 실행만
#   full: 통합 테스트 (testForCli 환경에서 ZTest 스니펫 확장 검증)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DEST="/Applications/_nowage_app"
APP_NAME="fSnippetCli"

# ─── full 통합 테스트 ────────────────────────────────────────────────────────
if [ "$1" = "full" ]; then
    TEST_ROOT="/Users/nowage/Documents/finfra/fSnippetData_testForCli"
    TEST_BOARD="$SCRIPT_DIR/testBoard.txt"
    LOG_FILE="$TEST_ROOT/logs/flog.log"

    echo "🧪 [full] 통합 테스트 시작"
    echo ""
    echo "📋 로그 모니터링 (별도 터미널에서 실행):"
    echo "   tail -f $TEST_ROOT/logs/flog.log"
    echo ""

    # Step 0: kill
    echo "── Step 0: 프로세스 종료"
    bash "$SCRIPT_DIR/kill.sh"

    # Step 1: testForCli 폴더 확인
    echo "── Step 1: testForCli 폴더 확인"
    if [ ! -d "$TEST_ROOT" ]; then
        echo "❌ testForCli 폴더 없음: $TEST_ROOT"
        exit 1
    fi
    echo "✅ $TEST_ROOT"

    # Step 2: 환경변수 설정 후 빌드·배포·실행
    # PreferencesManager는 UserDefaults가 아닌 환경변수 fSnippetCli_config를 우선 사용
    # GUI 앱에 환경변수를 전달하려면 launchctl setenv 사용
    echo "── Step 2: fSnippetCli_config 환경변수 설정 (launchctl)"
    launchctl setenv fSnippetCli_config "$TEST_ROOT"
    echo "✅ fSnippetCli_config=$TEST_ROOT"
    echo "🔨 빌드..."
    cd "$CLI_DIR"
    xcodebuild -scheme "$APP_NAME" -configuration Release build -quiet
    echo "✅ 빌드 완료"
    BUILD_DIR=$(xcodebuild -scheme "$APP_NAME" -configuration Release -showBuildSettings 2>/dev/null \
        | grep " TARGET_BUILD_DIR =" | awk -F " = " '{print $2}' | xargs)
    mkdir -p "$APP_DEST"
    rm -rf "$APP_DEST/$APP_NAME.app"
    cp -R "$BUILD_DIR/$APP_NAME.app" "$APP_DEST/"
    xattr -cr "$APP_DEST/$APP_NAME.app"
    echo "🚀 실행..."
    open "$APP_DEST/$APP_NAME.app"
    sleep 4

    # Step 3: ZTest 스니펫 파일 생성
    echo "── Step 3: ZTest 스니펫 생성"
    mkdir -p "$TEST_ROOT/snippets/ZTest"
    echo "ZTest-do" > "$TEST_ROOT/snippets/ZTest/do.txt"
    echo "✅ ZTest/do.txt 생성 (abbreviation: ztdo + right_command)"
    sleep 2  # 파일 감시 감지 대기

    # Step 4: testBoard.txt 초기화
    echo "── Step 4: testBoard.txt 초기화"
    : > "$TEST_BOARD"

    # Step 5: API 동작 확인
    echo "── Step 5: API 응답 확인"
    curl -s http://localhost:3015/ | python3 -m json.tool 2>/dev/null || echo "⚠️ API 응답 없음"

    # Step 6: TextEdit에서 ztdo 입력 후 Python으로 right_command 전송
    echo "── Step 6: TextEdit에서 ztdo + right_command 입력"
    # TextEdit 열기 + "ztdo" 입력 (AppleScript)
    # 포커스 경쟁 방지: activate를 키 입력 직전에 한 번 더 호출
    osascript <<'APPLESCRIPT'
tell application "TextEdit"
    activate
    open POSIX file "/Users/nowage/_git/__all/fSnippet/_public/cli/_tool/testBoard.txt"
end tell
delay 2
tell application "TextEdit" to activate
delay 0.5
tell application "System Events"
    tell process "TextEdit"
        set frontmost to true
    end tell
    delay 0.3
    keystroke "ztdo"
    delay 0.5
end tell
APPLESCRIPT
    # right_command 전송: AppleScript key code 54는 NX_DEVICERCMDKEYMASK를 세팅하지 않으므로
    # Python+Quartz로 올바른 CGEvent 전송
    python3 "$SCRIPT_DIR/send_right_cmd.py"
    sleep 2
    # Cmd+S 저장 (TextEdit 포커스 재확인) + "Save Anyway" 다이얼로그 자동 처리
    osascript <<'APPLESCRIPT'
tell application "TextEdit" to activate
delay 0.3
tell application "System Events" to keystroke "s" using {command down}
-- "Save Anyway" 다이얼로그 대기 및 클릭 (최대 5초)
repeat 10 times
    delay 0.5
    tell application "System Events"
        tell process "TextEdit"
            if exists sheet 1 of window 1 then
                click button "Save Anyway" of sheet 1 of window 1
                exit repeat
            end if
        end tell
    end tell
end repeat
APPLESCRIPT
    sleep 0.5

    # Step 7: testBoard.txt 내용 확인
    echo "── Step 7: testBoard.txt 내용 확인"
    BOARD_CONTENT=$(cat "$TEST_BOARD" 2>/dev/null || echo "")
    echo "내용: '$BOARD_CONTENT'"

    # Step 8: flog.log 트리거 확장 확인
    echo "── Step 8: flog.log 트리거 확장 확인"
    if grep -q "🚦 트리거 확장" "$LOG_FILE" 2>/dev/null; then
        LOG_OK=true
        grep "🚦 트리거 확장" "$LOG_FILE" | tail -3
    else
        LOG_OK=false
        echo "⚠️ '🚦 트리거 확장' 미확인"
    fi

    # Step 9: 결과 알림 + appRootPath 원복
    echo "── Step 9: 결과 알림"
    if [ "$LOG_OK" = "true" ]; then
        echo "✅ 테스트 성공"
        say "f-snippet-cli ok"
    else
        echo "❌ 테스트 실패"
        say "f-snippet-cli fail"
    fi

    echo "── 환경변수 원복 (launchctl unsetenv)"
    launchctl unsetenv fSnippetCli_config
    echo "✅ fSnippetCli_config 해제 (기본값으로 복원)"
    echo ""
    echo "🧪 [full] 통합 테스트 완료"
    exit 0
fi
# ─────────────────────────────────────────────────────────────────────────────

# Step 1: 기존 프로세스 종료
bash "$SCRIPT_DIR/kill.sh"

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
