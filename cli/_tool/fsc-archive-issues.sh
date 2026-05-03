#!/bin/bash
# fsc-archive-issues.sh — Move completed issues from Issue.md to z_old/old_issue.md
#
# Usage: bash cli/_tool/fsc-archive-issues.sh [version]
#   version: optional release tag for the archive header (default: VERSION file)
#
# Behavior:
#   - Reads `_public/Issue.md` `# ✅ 완료` section body (between `# ✅ 완료` and the
#     next top-level header).
#   - Appends body to `_public/z_old/old_issue.md` under a release-tagged subsection.
#   - Strips the body from Issue.md, leaving the `# ✅ 완료` header + a pointer line.
#   - Idempotent: if the completed section is empty (only whitespace + pointer),
#     exits 0 without changes.

set -euo pipefail

PUBLIC_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ISSUE_FILE="$PUBLIC_DIR/Issue.md"
ARCHIVE_DIR="$PUBLIC_DIR/z_old"
ARCHIVE_FILE="$ARCHIVE_DIR/old_issue.md"

[ -f "$ISSUE_FILE" ] || { echo "❌ Issue.md not found: $ISSUE_FILE" >&2; exit 1; }

VERSION="${1:-$(cat "$PUBLIC_DIR/VERSION" 2>/dev/null | tr -d '[:space:]')}"
[ -n "$VERSION" ] || VERSION="unversioned"
TODAY=$(date +%Y-%m-%d)

# Locate the `# ✅ 완료` line and the next top-level header line.
COMPLETE_LINE=$(grep -n "^# ✅ 완료" "$ISSUE_FILE" | head -1 | cut -d: -f1)
[ -n "$COMPLETE_LINE" ] || { echo "❌ '# ✅ 완료' header not found"; exit 1; }

NEXT_HEADER_LINE=$(awk -v start="$COMPLETE_LINE" 'NR>start && /^# / {print NR; exit}' "$ISSUE_FILE")
[ -n "$NEXT_HEADER_LINE" ] || NEXT_HEADER_LINE=$(($(wc -l < "$ISSUE_FILE") + 1))

BODY_START=$((COMPLETE_LINE + 1))
BODY_END=$((NEXT_HEADER_LINE - 1))

if [ "$BODY_END" -lt "$BODY_START" ]; then
    echo "ℹ️  완료 섹션 비어있음 — 아카이브 생략"
    exit 0
fi

BODY_CONTENT=$(sed -n "${BODY_START},${BODY_END}p" "$ISSUE_FILE")

# Determine if body has any actual issue content (## headers).
if ! echo "$BODY_CONTENT" | grep -q "^## "; then
    echo "ℹ️  완료 섹션에 이슈 항목 없음 — 아카이브 생략"
    exit 0
fi

mkdir -p "$ARCHIVE_DIR"

# Initialize archive file if absent.
if [ ! -f "$ARCHIVE_FILE" ]; then
    cat > "$ARCHIVE_FILE" <<'HEADER'
---
name: old_issue
description: fSnippetCli Issue.md 완료 섹션 아카이브 (릴리스별 이동)
date: 2026-05-03
---

# ✅ 완료 (아카이브)

HEADER
fi

# Append release-tagged section.
{
    echo ""
    echo "## Release ${VERSION} — ${TODAY}"
    echo ""
    echo "$BODY_CONTENT"
} >> "$ARCHIVE_FILE"

# Rewrite Issue.md: keep through `# ✅ 완료`, insert pointer, then remainder.
{
    sed -n "1,${COMPLETE_LINE}p" "$ISSUE_FILE"
    echo ""
    echo "> 누적된 완료 이슈는 [z_old/old_issue.md](z_old/old_issue.md)로 아카이브됨 (Release ${VERSION}, ${TODAY})."
    echo ""
    sed -n "${NEXT_HEADER_LINE},\$p" "$ISSUE_FILE"
} > "${ISSUE_FILE}.tmp"
mv "${ISSUE_FILE}.tmp" "$ISSUE_FILE"

ARCHIVED_COUNT=$(echo "$BODY_CONTENT" | grep -c "^## " || true)
echo "✅ ${ARCHIVED_COUNT}개 이슈 아카이브: $ARCHIVE_FILE (Release ${VERSION})"
