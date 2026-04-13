#!/bin/bash
# 정상: settings snapshot export → 파일 저장 → import 로 복원
TMPFILE=$(mktemp /tmp/fsnippet_snapshot_XXXXXX.json)
$CLI settings snapshot export --output "$TMPFILE" 2>/dev/null
if [ $? -ne 0 ]; then
  # --output 미지원 시 stdout → 파일로 저장
  $CLI settings snapshot export > "$TMPFILE" 2>/dev/null
fi
RC=$?
if [ $RC -ne 0 ] || [ ! -s "$TMPFILE" ]; then
  echo "❌ FAIL: snapshot export 실패 (exit=$RC)"
  rm -f "$TMPFILE"
  exit 1
fi
echo "📦 snapshot 저장됨: $TMPFILE"
$CLI settings snapshot import "$TMPFILE"
RC=$?
rm -f "$TMPFILE"
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC
