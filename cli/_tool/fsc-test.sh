#!/bin/bash
# Issue40: ZTest 통합 테스트 (Issue36에서 run.sh full 모드로 구현된 흐름 이주)
# Issue50: pairApp fwc-test.sh 오케스트레이션 패턴 역이식 (API/CMD/로그 3단계 삽입)
# Usage: ./fsc-test.sh
#
# 12단계 체인:
#   Step 0:  기존 프로세스 종료
#   Step 1:  testForCli 폴더 확인
#   Step 2:  launchctl setenv + Debug 빌드·배포·실행 (fsc-run-xcode.sh build-deploy)
#   Step 3:  ZTest 스니펫 파일 생성
#   Step 4:  testBoard.txt 초기화
#   Step 5:  REST API 응답 확인
#   Step 6:  TextEdit 자동화 (ztdo + right_command)
#   Step 7:  testBoard 내용 확인
#   Step 8:  flog.log 트리거 확장 확인
#   Step 9:  apiTestDo.sh all 호출 (Issue50)
#   Step 10: cmdTestDo.sh all 호출 (Issue50)
#   Step 11: ERROR/CRITICAL 로그 자동 검사 (Issue50)
#   Step 12: 결과 알림 + launchctl unsetenv 원복
#
# 빌드 구성: Debug (fsc-run-xcode.sh 통해 — TCC 회피 일관성)
# 설계 근거: Issue.md Issue40 (office-hours 2026-04-18 결정)
#           pairApp fwc-test.sh 리포팅 패턴 이식 (record_result 기반 집계)
#           Issue50 — fwc-test.sh Step 5/6/7 (API/CMD/로그) 오케스트레이션 역이식

set +e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_DIR="$(dirname "$SCRIPT_DIR")"
RUN_XCODE="$SCRIPT_DIR/fsc-run-xcode.sh"
TEST_ROOT="$HOME/Documents/finfra/fSnippetData_testForCli"
TEST_BOARD="$SCRIPT_DIR/testBoard.txt"
LOG_FILE="$TEST_ROOT/logs/flog.log"

TOTAL_PASS=0
TOTAL_FAIL=0
STEP_RESULTS=()

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

# 실패 경로에서 공통 뒷정리 (환경변수 원복)
cleanup_env() {
    launchctl unsetenv fSnippetCli_config 2>/dev/null || true
}

echo "╔══════════════════════════════════════════╗"
echo "║        fSnippetCli ZTest Integration     ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "📋 로그 모니터링 (별도 터미널):"
echo "   tail -f $LOG_FILE"
echo ""

# --- Step 0: 기존 프로세스 종료 ---
echo "=== Step 0: 기존 프로세스 종료 ==="
bash "$SCRIPT_DIR/kill.sh"

# --- Step 1: testForCli 폴더 확인 ---
echo ""
echo "=== Step 1: testForCli 폴더 확인 ==="
if [ ! -d "$TEST_ROOT" ]; then
    record_result "testForCli 폴더" "FAIL" "$TEST_ROOT 없음"
    echo ""; echo "❌ 테스트 루트 폴더 부재 — 중단"
    cleanup_env
    exit 1
fi
record_result "testForCli 폴더" "PASS" "$TEST_ROOT"

# --- Step 2: 환경변수 설정 + Debug 빌드·배포·실행 ---
echo ""
echo "=== Step 2: launchctl setenv + Debug 빌드·배포·실행 ==="
launchctl setenv fSnippetCli_config "$TEST_ROOT"
echo "fSnippetCli_config=$TEST_ROOT"
if bash "$RUN_XCODE" build-deploy; then
    record_result "빌드 & 배포" "PASS" "Xcode Debug 빌드 성공"
else
    record_result "빌드 & 배포" "FAIL" "빌드 또는 배포 실패"
    echo ""; echo "❌ 빌드 실패 — 중단"
    cleanup_env
    exit 1
fi
sleep 4

# --- Step 3: ZTest 스니펫 파일 생성 ---
echo ""
echo "=== Step 3: ZTest 스니펫 생성 ==="
mkdir -p "$TEST_ROOT/snippets/ZTest"
if echo "ZTest-do" > "$TEST_ROOT/snippets/ZTest/do.txt"; then
    record_result "ZTest 스니펫" "PASS" "ZTest/do.txt (abbreviation: ztdo + right_command)"
else
    record_result "ZTest 스니펫" "FAIL" "do.txt 생성 실패"
fi
sleep 2  # 파일 감시 감지 대기

# --- Step 4: testBoard.txt 초기화 ---
echo ""
echo "=== Step 4: testBoard.txt 초기화 ==="
if : > "$TEST_BOARD"; then
    record_result "testBoard 초기화" "PASS" "$TEST_BOARD"
else
    record_result "testBoard 초기화" "FAIL" "$TEST_BOARD 쓰기 실패"
fi

# --- Step 5: REST API 응답 확인 (최대 10초 대기) ---
echo ""
echo "=== Step 5: REST API 응답 확인 ==="
HEALTH=""
for _i in $(seq 1 10); do
    HEALTH=$(curl -s --connect-timeout 2 http://localhost:3015/ 2>/dev/null)
    if [ -n "$HEALTH" ]; then
        break
    fi
    sleep 1
done
if [ -n "$HEALTH" ]; then
    echo "$HEALTH" | python3 -m json.tool 2>/dev/null || echo "$HEALTH"
    HEALTH_MSG=$(echo "$HEALTH" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(f"status={d.get(\"status\",\"?\")}")' 2>/dev/null || echo "응답 수신")
    record_result "REST API" "PASS" "$HEALTH_MSG"
else
    record_result "REST API" "FAIL" "10초 내 응답 없음 (포트 3015)"
fi

# --- Step 6: TextEdit에서 ztdo 입력 후 Python으로 right_command 전송 ---
echo ""
echo "=== Step 6: TextEdit 자동화 (ztdo + right_command) ==="
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
OSA_TYPE_STATUS=$?
python3 "$SCRIPT_DIR/send_right_cmd.py"
PY_STATUS=$?
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
OSA_SAVE_STATUS=$?
sleep 0.5
if [ "$OSA_TYPE_STATUS" -eq 0 ] && [ "$PY_STATUS" -eq 0 ] && [ "$OSA_SAVE_STATUS" -eq 0 ]; then
    record_result "TextEdit 자동화" "PASS" "type=${OSA_TYPE_STATUS}, cmd=${PY_STATUS}, save=${OSA_SAVE_STATUS}"
else
    record_result "TextEdit 자동화" "FAIL" "type=${OSA_TYPE_STATUS}, cmd=${PY_STATUS}, save=${OSA_SAVE_STATUS}"
fi

# --- Step 7: testBoard.txt 내용 확인 ---
echo ""
echo "=== Step 7: testBoard.txt 내용 확인 ==="
BOARD_CONTENT=$(cat "$TEST_BOARD" 2>/dev/null || echo "")
echo "내용: '$BOARD_CONTENT'"
if [ -n "$BOARD_CONTENT" ] && [ "$BOARD_CONTENT" != "ztdo" ]; then
    record_result "testBoard 확장" "PASS" "'$BOARD_CONTENT' (ztdo → 확장)"
elif [ "$BOARD_CONTENT" = "ztdo" ]; then
    record_result "testBoard 확장" "FAIL" "트리거 미확장 ('ztdo' 그대로)"
else
    record_result "testBoard 확장" "FAIL" "내용 비어있음"
fi

# --- Step 8: flog.log 트리거 확장 확인 ---
echo ""
echo "=== Step 8: flog.log 트리거 확장 확인 ==="
if grep -q "🚦 트리거 확장" "$LOG_FILE" 2>/dev/null; then
    LOG_HITS=$(grep -c "🚦 트리거 확장" "$LOG_FILE" 2>/dev/null || echo 0)
    grep "🚦 트리거 확장" "$LOG_FILE" | tail -3
    record_result "flog.log 트리거" "PASS" "🚦 트리거 확장 ${LOG_HITS}건"
else
    record_result "flog.log 트리거" "FAIL" "'🚦 트리거 확장' 미확인"
fi

# --- Step 9: apiTestDo.sh all 호출 (Issue50) ---
echo ""
echo "=== Step 9: apiTestDo.sh all (API 통합 테스트) ==="
if [ -f "$SCRIPT_DIR/apiTestDo.sh" ]; then
    # v1/17.cli-quit 자동 skip 을 위해 stdin 에 N 주입
    API_RESULT=$(echo "N" | bash "$SCRIPT_DIR/apiTestDo.sh" all 2>&1)
    echo "$API_RESULT" | tail -60
    API_TOTAL=$(echo "$API_RESULT" | grep -c '^===' || true)
    API_FAIL=$(echo "$API_RESULT" | grep -cE '"status": *"error"|❌' || true)
    if [ "$API_TOTAL" -gt 0 ]; then
        record_result "API 통합 테스트" "PASS" "${API_TOTAL}개 실행 (error/❌=${API_FAIL})"
    else
        record_result "API 통합 테스트" "FAIL" "테스트 실행 안 됨"
    fi
else
    record_result "API 통합 테스트" "FAIL" "apiTestDo.sh 없음"
fi

# --- Step 10: cmdTestDo.sh all 호출 (Issue50) ---
echo ""
echo "=== Step 10: cmdTestDo.sh all (CMD 통합 테스트) ==="
if [ -f "$SCRIPT_DIR/cmdTestDo.sh" ]; then
    CMD_RESULT=$(bash "$SCRIPT_DIR/cmdTestDo.sh" all 2>&1)
    echo "$CMD_RESULT" | tail -60
    CMD_TOTAL=$(echo "$CMD_RESULT" | grep -c '^===' || true)
    CMD_FAIL=$(echo "$CMD_RESULT" | grep -cE '실패=[1-9]' || true)
    if [ "$CMD_TOTAL" -gt 0 ]; then
        record_result "CMD 통합 테스트" "PASS" "${CMD_TOTAL}개 실행 (실패 라인=${CMD_FAIL})"
    else
        record_result "CMD 통합 테스트" "FAIL" "테스트 실행 안 됨"
    fi
else
    record_result "CMD 통합 테스트" "FAIL" "cmdTestDo.sh 없음"
fi

# --- Step 11: ERROR/CRITICAL 로그 자동 검사 (Issue50) ---
echo ""
echo "=== Step 11: flog.log ERROR/CRITICAL 자동 검사 ==="
if [ -f "$LOG_FILE" ]; then
    LOG_ERRORS=$(grep -cE "ERROR|CRITICAL" "$LOG_FILE" 2>/dev/null || echo 0)
    LOG_LINES=$(wc -l < "$LOG_FILE" | tr -d ' ')
    echo "로그 파일: ${LOG_LINES}줄, ERROR/CRITICAL: ${LOG_ERRORS}건"
    if [ "$LOG_ERRORS" -eq 0 ]; then
        record_result "로그 검사" "PASS" "ERROR/CRITICAL 0건"
    else
        record_result "로그 검사" "FAIL" "ERROR/CRITICAL ${LOG_ERRORS}건"
        echo "--- 최근 에러 로그 5건 ---"
        grep -E "ERROR|CRITICAL" "$LOG_FILE" | tail -5
    fi
else
    record_result "로그 검사" "FAIL" "$LOG_FILE 없음"
fi

# --- Step 12: 환경변수 원복 ---
echo ""
echo "=== Step 12: 환경변수 원복 (launchctl unsetenv) ==="
launchctl unsetenv fSnippetCli_config
echo "fSnippetCli_config 해제"

# --- 최종 리포트 ---
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║          ZTest Integration 결과          ║"
echo "╠══════════════════════════════════════════╣"
for r in "${STEP_RESULTS[@]}"; do
    printf "║  %-40s║\n" "$r"
done
echo "╠══════════════════════════════════════════╣"
if [ "$TOTAL_FAIL" -eq 0 ]; then
    printf "║  🎉 ALL CLEAR: %d PASS / %d FAIL         ║\n" "$TOTAL_PASS" "$TOTAL_FAIL"
else
    printf "║  ⚠️  ISSUES: %d PASS / %d FAIL           ║\n" "$TOTAL_PASS" "$TOTAL_FAIL"
fi
echo "╚══════════════════════════════════════════╝"

if [ "$TOTAL_FAIL" -eq 0 ]; then
    say "f-snippet-cli ok" 2>/dev/null &
else
    say "f-snippet-cli fail" 2>/dev/null &
fi

exit "$TOTAL_FAIL"
