#!/bin/bash
# qa_run_batch.sh — FolderTest 35-case keyboard automation paste harness.
#
# Parses a testTable_org.md matrix, types each `abbreviation` into TextEdit via
# Quartz CGEvents (qa_type.py), waits for the cliApp engine to expand it, then
# compares the resulting document text against the expected snippet content.
#
# Usage:
#   sh qa_run_batch.sh [TABLE] [--delay N] [--case N] [--dry-run]
#     TABLE      path to testTable_org.md
#                (default: cli/fSnippetCliTests/FolderTest/testTable_org.md)
#     --delay N  inter-keystroke delay seconds (default 0.03)
#     --case N   run only case N
#     --dry-run  healthz + parse only, no typing
#
# Requires: cliApp running on :3015, Accessibility permission for the shell,
# the pyobjc Quartz binding.
#
# Issue138: an earlier run reported case20-23 as FAIL and concluded a
# "by-design" engine limit. That was WRONG — manual typing of the same cases
# expands correctly (flog: Rule '_caseN' matched + expansion). Root cause was a
# harness timing race: literal keystrokes are dispatched async to the engine's
# main queue, and a too-fast inter-key delay let a following special-key token
# fire as a trigger before the buffer was populated. Fixed in qa_type.py via
# TOKEN_SETTLE + a larger default delay.
set -u

# --- locate paths (no hardcoded user paths; resolve dynamically) ---
QA_DIR="$(cd "$(dirname "$0")" && pwd)"
PUBLIC_ROOT="$(cd "$QA_DIR/../../.." && pwd)"
DEFAULT_TABLE="$PUBLIC_ROOT/cli/fSnippetCliTests/FolderTest/testTable_org.md"
RESULT_DIR="$QA_DIR/results"

APP_ROOT="$(defaults read kr.finfra.fSnippetCli appRootPath 2>/dev/null)"
[ -z "$APP_ROOT" ] && APP_ROOT="$HOME/Documents/finfra/fSnippetData"
SNIPPET_DIR="$APP_ROOT/snippets"

# --- args ---
TABLE="$DEFAULT_TABLE"
DELAY="0.06"
ONLY_CASE=""
DRY_RUN=0
NO_RETRY=0        # skip the isolated retry phase
RETRY_MAX=10      # run the retry phase only if batch failures <= this
SETTLE=0.6        # delay after TextEdit activate before typing
EXPAND_WAIT=1.0   # delay after typing for the engine to finish expansion
RETRY_SETTLE=3    # extra idle before each retry case — drains cross-case state

while [ $# -gt 0 ]; do
  case "$1" in
    --delay)    DELAY="$2"; shift 2 ;;
    --case)     ONLY_CASE="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=1; shift ;;
    --no-retry) NO_RETRY=1; shift ;;
    --*)        echo "unknown option: $1" >&2; exit 2 ;;
    *)          TABLE="$1"; shift ;;
  esac
done

[ -f "$TABLE" ] || { echo "❌ testTable not found: $TABLE" >&2; exit 1; }

# --- Phase 0: cliApp healthz ---
echo "▶ Phase 0 — cliApp healthz"
HEALTH="$(curl -s -m 3 http://localhost:3015/ 2>/dev/null)"
case "$HEALTH" in
  *'"status" : "ok"'*|*'"status":"ok"'*) echo "  ✅ cliApp running" ;;
  *) echo "  ❌ cliApp not responding on :3015 — start it first" >&2; exit 1 ;;
esac

# --- parse testTable: emit "id<TAB>abbreviation" per case row ---
parse_table() {
  awk -F'|' '
    /^\|/ {
      id=$2; gsub(/[ \t]/,"",id)
      if (id ~ /^[0-9]+$/) {
        abbr=$7; sub(/^[ \t]+/,"",abbr); sub(/[ \t]+$/,"",abbr)
        print id "\t" abbr
      }
    }
  ' "$TABLE"
}

TOTAL="$(parse_table | wc -l | tr -d ' ')"
echo "▶ Parsed $TOTAL case(s) from $(basename "$TABLE")"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "▶ --dry-run — parsed cases:"
  parse_table | while IFS=$(printf '\t') read -r id abbr; do
    exp_file="$SNIPPET_DIR/_case${id}/test===case${id}.txt"
    if [ -f "$exp_file" ]; then exp="$(cat "$exp_file")"; else exp="<MISSING>"; fi
    printf "  case%-3s abbr=%-40s expect=%s\n" "$id" "$abbr" "$exp"
  done
  exit 0
fi

# --- TextEdit helpers ---
te_new_doc() {
  osascript -e 'tell application "TextEdit"' -e 'activate' \
    -e 'if (count of documents) = 0 then make new document' \
    -e 'set text of front document to ""' -e 'end tell' >/dev/null 2>&1
}
te_clear() {
  osascript -e 'tell application "TextEdit"' -e 'activate' \
    -e 'set text of front document to ""' -e 'end tell' >/dev/null 2>&1
}
# Recreate the document: close all + make new. The window-id change triggers
# WindowContextManager.onContextChange in cliApp, which clears the engine's
# abbreviation buffer (KeyEventMonitor.swift "Context Change"). A plain
# set-text="" does NOT change the window id, so it never flushes the buffer.
te_reset() {
  osascript -e 'tell application "TextEdit"' -e 'activate' \
    -e 'if (count of documents) > 0 then close every document saving no' \
    -e 'make new document' -e 'end tell' >/dev/null 2>&1
}
te_read() {
  osascript -e 'tell application "TextEdit" to get text of front document' 2>/dev/null
}

# --- Phase 1-4: run cases ---
# Note: no initial te_new_doc — te_reset (run per case) creates the document.
# Two back-to-back osascript activations (new_doc then reset) destabilised the
# TextEdit window so unicode keystrokes were dropped. (Issue138)
# run a single case in isolation. Sets RC_STATUS (ok|fail) and RC_ACTUAL.
run_one_case() {
  rc_abbr="$1"; rc_exp="$2"
  # recreate the document so the window-id change flushes the cliApp
  # abbreviation buffer (context-change) — drains carry-over special-key tokens
  te_reset
  sleep "$SETTLE"
  python3 "$QA_DIR/qa_type.py" --delay "$DELAY" -- "$rc_abbr"
  sleep "$EXPAND_WAIT"
  rc_exp_trim="$(printf '%s' "$rc_exp" | sed -e 's/[[:space:]]*$//')"
  RC_ACTUAL="$(te_read | sed -e 's/[[:space:]]*$//')"
  if [ "$RC_ACTUAL" = "$rc_exp_trim" ]; then RC_STATUS=ok; else RC_STATUS=fail; fi
  # placeholder for empty actual: an empty TAB-field collapses under `read`
  # (TAB is IFS-whitespace) and shifts later columns. Keep every field non-empty.
  [ -z "$RC_ACTUAL" ] && RC_ACTUAL="∅"
}

TS="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULT_DIR"
REPORT="$RESULT_DIR/result_${TS}.md"
# one line per case: id<TAB>abbr<TAB>exp<TAB>actual<TAB>status
RESULTS_TMP="$(mktemp)"

# --- Phase 1: batch run ---
echo "▶ Phase 1 — batch run (delay=${DELAY}s)"
while IFS=$(printf '\t') read -r id abbr; do
  [ -n "$ONLY_CASE" ] && [ "$id" != "$ONLY_CASE" ] && continue

  exp_file="$SNIPPET_DIR/_case${id}/test===case${id}.txt"
  if [ ! -f "$exp_file" ]; then
    printf '%s\t%s\t∅\t∅\tSKIP\n' "$id" "$abbr" >> "$RESULTS_TMP"
    printf "  case%-3s ⚠️ SKIP\n" "$id"
    continue
  fi
  expected="$(cat "$exp_file")"
  exp_trim="$(printf '%s' "$expected" | sed -e 's/[[:space:]]*$//')"

  run_one_case "$abbr" "$expected"
  if [ "$RC_STATUS" = ok ]; then
    printf "  case%-3s ✅ OK\n" "$id"
    printf '%s\t%s\t%s\t%s\tOK\n' "$id" "$abbr" "$exp_trim" "$RC_ACTUAL" >> "$RESULTS_TMP"
  else
    printf "  case%-3s ❌ FAIL\n" "$id"
    printf '%s\t%s\t%s\t%s\tFAIL\n' "$id" "$abbr" "$exp_trim" "$RC_ACTUAL" >> "$RESULTS_TMP"
  fi
done <<EOF
$(parse_table)
EOF

BATCH_FAIL="$(awk -F'\t' '$5=="FAIL"' "$RESULTS_TMP" | wc -l | tr -d ' ')"

# --- Phase 2: isolated retry of failed cases ---
# A case that fails in batch but passes when re-run alone was a false-FAIL
# caused by cross-case interference. Retry only when failures are few enough
# that one-by-one re-verification is meaningful.
RETRY_RECOVERED=0
if [ "$NO_RETRY" -eq 0 ] && [ -z "$ONLY_CASE" ] \
   && [ "$BATCH_FAIL" -gt 0 ] && [ "$BATCH_FAIL" -le "$RETRY_MAX" ]; then
  echo "▶ Phase 2 — retry ${BATCH_FAIL} failed case(s) in isolation"
  RETRY_TMP="$(mktemp)"
  while IFS=$(printf '\t') read -r id abbr exp actual status; do
    if [ "$status" = FAIL ]; then
      sleep "$RETRY_SETTLE"          # idle so cross-case engine state drains
      run_one_case "$abbr" "$exp"
      if [ "$RC_STATUS" = ok ]; then
        printf "  case%-3s ✅ OK (retry)\n" "$id"
        RETRY_RECOVERED=$((RETRY_RECOVERED + 1))
        printf '%s\t%s\t%s\t%s\tRETRY_OK\n' "$id" "$abbr" "$exp" "$RC_ACTUAL" >> "$RETRY_TMP"
      else
        printf "  case%-3s ❌ FAIL (retry)\n" "$id"
        printf '%s\t%s\t%s\t%s\tFAIL\n' "$id" "$abbr" "$exp" "$RC_ACTUAL" >> "$RETRY_TMP"
      fi
    else
      printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$abbr" "$exp" "$actual" "$status" >> "$RETRY_TMP"
    fi
  done < "$RESULTS_TMP"
  mv "$RETRY_TMP" "$RESULTS_TMP"
elif [ "$BATCH_FAIL" -gt "$RETRY_MAX" ]; then
  echo "▶ Phase 2 생략 — 실패 ${BATCH_FAIL}건 > ${RETRY_MAX} (전수 재시도 무의미)"
fi

# --- tally + report ---
PASS=0; FAIL=0; SKIP=0; ROWS=""
while IFS=$(printf '\t') read -r id abbr exp actual status; do
  case "$status" in
    OK)        PASS=$((PASS+1)); disp="✅ OK" ;;
    RETRY_OK)  PASS=$((PASS+1)); disp="✅ OK (retry)" ;;
    FAIL)      FAIL=$((FAIL+1)); disp="❌ FAIL" ;;
    SKIP)      SKIP=$((SKIP+1)); disp="⚠️ SKIP" ;;
    *)         disp="$status" ;;
  esac
  ROWS="${ROWS}| $id | \`$abbr\` | \`$exp\` | \`$actual\` | $disp |
"
done < "$RESULTS_TMP"
RAN=$((PASS + FAIL))
rm -f "$RESULTS_TMP"

cat > "$REPORT" <<EOF
---
title: QA Keyboard Batch Result (Issue137)
date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
passed: ${PASS}/${RAN}
---

# 결과 요약

* 통과: ${PASS}/${RAN}  (batch $((PASS - RETRY_RECOVERED)) + retry 구제 ${RETRY_RECOVERED})
* 실패: ${FAIL}
* batch 실패: ${BATCH_FAIL}
* testTable: $(basename "$TABLE")
* delay: ${DELAY}s

# 케이스별 상세

| id | abbreviation | expected | actual | status |
| -- | ------------ | -------- | ------ | ------ |
${ROWS}
EOF

echo "▶ 완료 — PASS ${PASS} / FAIL ${FAIL} (총 ${RAN}), retry 구제 ${RETRY_RECOVERED}"
echo "▶ 리포트: $REPORT"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
