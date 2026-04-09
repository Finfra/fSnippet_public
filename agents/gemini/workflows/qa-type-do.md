---
name: qa-type-do
description: "앱 실행 -> 텍스트에디터 열기 -> 'd{keypad_comma}' 입력 -> 저장 -> 검증"
---

# QA Type Do Workflow

앱을 실행하고, TextEdit를 사용하여 스니펫 입력을 시뮬레이션한 뒤 결과를 검증합니다.

## 1. 앱 빌드 및 실행 (Build & Run)
`/run` 워크플로우(또는 `_tool/run.sh`)를 사용하여 앱을 실행합니다.

```bash
// turbo
sh _tool/run.sh
```

## 2. 테스트 준비 (Prepare)
테스트 보드 파일이 준비되었는지 확인합니다.

```bash
// turbo
touch _tool/testBoard.txt
```

## 3. 자동화 테스트 실행 (Simulate Typing)
TextEdit를 열고 'd'와 키패드 콤마를 입력하여 스니펫 확장을 유도합니다.

```bash
# Extract user input (default: d{keypad_comma})
INPUT_STRING="${1:-"d{keypad_comma}"}"

# Check if input is a valid CSV or Markdown file -> Batch Mode
if [[ "$INPUT_STRING" =~ \.(csv|md)$ ]] && [ -f "$INPUT_STRING" ]; then
    echo "📂 Detected Batch File: $INPUT_STRING"
    echo "🚀 Switching to Batch Mode..."
    
    # Run Batch Runner with In-place update (Input == Output)
    python3 _tool/qa/qa_batch_runner.py "$INPUT_STRING" "$INPUT_STRING"
    
    echo "✅ Batch processing completed for $INPUT_STRING"
    exit 0
fi

# Run Single Test Module
sh _tool/qa/qa_run_single.sh "$INPUT_STRING"

# For Reporting Phase compatibility
if [[ "$INPUT_STRING" =~ \{([^}]+)\}$ ]]; then
    TRIGGER_NAME="${BASH_REMATCH[1]}"
    BASE_TEXT="${INPUT_STRING%\{*\}}"
    TRIGGER_CODE=$(python3 _tool/qa/get_key_code.py "$TRIGGER_NAME")
    if [[ $? -eq 0 && ! -z "$TRIGGER_CODE" ]]; then
        APPLESCRIPT_ARG="${BASE_TEXT}{${TRIGGER_CODE}}"
    else
        APPLESCRIPT_ARG="$INPUT_STRING"
    fi
else
    APPLESCRIPT_ARG="$INPUT_STRING"
fi
```

## 4. 결과 검증 및 리포트 저장 (Verify & Report)
결과를 검증하고 `_doc_work/ReportQa`에 타임스탬프와 함께 저장합니다.

```bash
REPORT_DIR="_doc_work/ReportQa"
mkdir -p "$REPORT_DIR"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_FILE="$REPORT_DIR/qa_result_$TIMESTAMP.txt"

echo "📝 QA Execution Report - $TIMESTAMP" > "$REPORT_FILE"
echo "Target Input: $INPUT_STRING" >> "$REPORT_FILE"
echo "Resolved Arg: $APPLESCRIPT_ARG" >> "$REPORT_FILE"
echo "----------------------------------------" >> "$REPORT_FILE"
echo "Test Board Content:" >> "$REPORT_FILE"
cat _tool/testBoard.txt >> "$REPORT_FILE"
echo "\n----------------------------------------" >> "$REPORT_FILE"

echo "\n🔍 --- Result in testBoard.txt ---"
cat _tool/testBoard.txt
echo "\n-----------------------------"
echo "✅ Report saved to: $REPORT_FILE"
```

## 5. 로그 확인 (Check Logs)
최근 로그를 확인하여 스니펫 동작 기록을 검토합니다.

```bash
echo "🔍 --- Recent Logs ---"
tail -n 20 ~/Documents/finfra/fSnippetData/logs/flog.log
```
