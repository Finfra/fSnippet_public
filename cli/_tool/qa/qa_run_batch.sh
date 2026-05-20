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
DELAY="0.03"
ONLY_CASE=""
DRY_RUN=0
SETTLE=0.6        # delay after TextEdit activate before typing
EXPAND_WAIT=1.0   # delay after typing for the engine to finish expansion

while [ $# -gt 0 ]; do
  case "$1" in
    --delay)   DELAY="$2"; shift 2 ;;
    --case)    ONLY_CASE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --*)       echo "unknown option: $1" >&2; exit 2 ;;
    *)         TABLE="$1"; shift ;;
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
te_read() {
  osascript -e 'tell application "TextEdit" to get text of front document' 2>/dev/null
}

# --- Phase 1-4: run cases ---
echo "▶ Typing harness — delay=${DELAY}s"
te_new_doc
sleep 0.5

TS="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULT_DIR"
REPORT="$RESULT_DIR/result_${TS}.md"
PASS=0
FAIL=0
ROWS=""

while IFS=$(printf '\t') read -r id abbr; do
  [ -n "$ONLY_CASE" ] && [ "$id" != "$ONLY_CASE" ] && continue

  exp_file="$SNIPPET_DIR/_case${id}/test===case${id}.txt"
  if [ ! -f "$exp_file" ]; then
    ROWS="${ROWS}| $id | \`$abbr\` | <no snippet file> | — | ⚠️ SKIP |
"
    continue
  fi
  expected="$(cat "$exp_file")"

  te_clear
  sleep "$SETTLE"
  python3 "$QA_DIR/qa_type.py" --delay "$DELAY" -- "$abbr"
  sleep "$EXPAND_WAIT"
  actual="$(te_read)"

  # normalize trailing whitespace/newlines for comparison
  exp_trim="$(printf '%s' "$expected" | sed -e 's/[[:space:]]*$//')"
  act_trim="$(printf '%s' "$actual"  | sed -e 's/[[:space:]]*$//')"

  if [ "$act_trim" = "$exp_trim" ]; then
    PASS=$((PASS + 1))
    status="✅ OK"
  else
    FAIL=$((FAIL + 1))
    status="❌ FAIL"
  fi
  printf "  case%-3s %s\n" "$id" "$status"
  ROWS="${ROWS}| $id | \`$abbr\` | \`$exp_trim\` | \`$act_trim\` | $status |
"
done <<EOF
$(parse_table)
EOF

RAN=$((PASS + FAIL))

# --- write report ---
cat > "$REPORT" <<EOF
---
title: QA Keyboard Batch Result (Issue137)
date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
passed: ${PASS}/${RAN}
---

# 결과 요약

* 통과: ${PASS}/${RAN}
* 실패: ${FAIL}
* testTable: $(basename "$TABLE")
* delay: ${DELAY}s

# 케이스별 상세

| id | abbreviation | expected | actual | status |
| -- | ------------ | -------- | ------ | ------ |
${ROWS}
EOF

echo "▶ 완료 — PASS ${PASS} / FAIL ${FAIL} (총 ${RAN})"
echo "▶ 리포트: $REPORT"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
