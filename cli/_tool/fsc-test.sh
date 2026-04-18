#!/bin/bash
# Issue40: ZTest 통합 테스트 (Issue36에서 run.sh full 모드로 구현된 흐름 이주)
# Usage: ./fsc-test.sh
#
# 9단계 체인:
#   Step 0: 기존 프로세스 종료
#   Step 1: testForCli 폴더 확인
#   Step 2: launchctl setenv + Debug 빌드·배포·실행 (fsc-run-xcode.sh build-deploy)
#   Step 3: ZTest 스니펫 파일 생성
#   Step 4: testBoard.txt 초기화
#   Step 5: REST API 응답 확인
#   Step 6: TextEdit 자동화 (ztdo + right_command)
#   Step 7: testBoard 내용 확인
#   Step 8: flog.log 트리거 확장 확인
#   Step 9: 결과 알림 + launchctl unsetenv 원복
#
# 빌드 구성: Debug (fsc-run-xcode.sh 통해 — TCC 회피 일관성)
# 설계 근거: Issue.md Issue40 (office-hours 2026-04-18 결정)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_DIR="$(dirname "$SCRIPT_DIR")"
RUN_XCODE="$SCRIPT_DIR/fsc-run-xcode.sh"
TEST_ROOT="$HOME/Documents/finfra/fSnippetData_testForCli"
TEST_BOARD="$SCRIPT_DIR/testBoard.txt"
LOG_FILE="$TEST_ROOT/logs/flog.log"

echo "🧪 [fsc-test] ZTest 통합 테스트 시작"
echo ""
echo "📋 로그 모니터링 (별도 터미널):"
echo "   tail -f $LOG_FILE"
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

# Step 2: 환경변수 설정 + Debug 빌드·배포·실행
echo "── Step 2: fSnippetCli_config 환경변수 설정 (launchctl)"
launchctl setenv fSnippetCli_config "$TEST_ROOT"
echo "✅ fSnippetCli_config=$TEST_ROOT"
echo "🔨 Debug 빌드·배포·실행 (fsc-run-xcode.sh build-deploy)..."
if ! bash "$RUN_XCODE" build-deploy; then
    echo "❌ 빌드 또는 배포 실패"
    launchctl unsetenv fSnippetCli_config
    exit 1
fi
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
osascript <<APPLESCRIPT
tell application "TextEdit"
    activate
    open POSIX file "$TEST_BOARD"
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
python3 "$SCRIPT_DIR/send_right_cmd.py"
sleep 2
# Cmd+S 저장 + "Save Anyway" 다이얼로그 자동 처리
osascript <<'APPLESCRIPT'
tell application "TextEdit" to activate
delay 0.3
tell application "System Events" to keystroke "s" using {command down}
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

# Step 9: 결과 알림 + 환경변수 원복
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
echo "✅ fSnippetCli_config 해제"
echo ""
echo "🧪 [fsc-test] 통합 테스트 완료"
