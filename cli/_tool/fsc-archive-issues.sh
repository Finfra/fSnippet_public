#!/bin/bash
# fsc-archive-issues.sh — Move completed and canceled issues from Issue.md to z_old/old_issue.md
#
# Usage: bash cli/_tool/fsc-archive-issues.sh [version]
#   version: optional release tag for the archive header (default: VERSION file)
#
# Behavior:
#   - Reads two sections from Issue.md: `# ✅ 완료` and `# 🚫 취소`.
#   - Each section's body (## headers + their bodies) is appended to
#     `_public/z_old/old_issue.md` under a release-tagged subsection.
#   - Source body is stripped from Issue.md, leaving the section header + pointer line.
#   - Idempotent per section: if a section has no `## ` items, it is skipped.

set -euo pipefail

PUBLIC_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ISSUE_FILE="$PUBLIC_DIR/Issue.md"
ARCHIVE_DIR="$PUBLIC_DIR/z_old"
ARCHIVE_FILE="$ARCHIVE_DIR/old_issue.md"

[ -f "$ISSUE_FILE" ] || { echo "❌ Issue.md not found: $ISSUE_FILE" >&2; exit 1; }

VERSION="${1:-$(cat "$PUBLIC_DIR/VERSION" 2>/dev/null | tr -d '[:space:]')}"
[ -n "$VERSION" ] || VERSION="unversioned"
TODAY=$(date +%Y-%m-%d)

mkdir -p "$ARCHIVE_DIR"
if [ ! -f "$ARCHIVE_FILE" ]; then
    cat > "$ARCHIVE_FILE" <<'HEADER'
---
name: old_issue
description: fSnippetCli Issue.md 완료/취소 섹션 아카이브 (릴리스별 이동)
date: 2026-05-03
---

# ✅ 완료 (아카이브)

HEADER
fi

# archive_section <header> <label> <pointer-text>
archive_section() {
    local header="$1"
    local label="$2"
    local pointer="$3"

    local header_line
    header_line=$(grep -n "^${header}\$" "$ISSUE_FILE" | head -1 | cut -d: -f1 || true)
    if [ -z "$header_line" ]; then
        echo "ℹ️  '${header}' 섹션 없음 — skip"
        return 0
    fi

    local next_header
    next_header=$(awk -v start="$header_line" 'NR>start && /^# / {print NR; exit}' "$ISSUE_FILE")
    [ -n "$next_header" ] || next_header=$(($(wc -l < "$ISSUE_FILE") + 1))

    local body_start=$((header_line + 1))
    local body_end=$((next_header - 1))
    if [ "$body_end" -lt "$body_start" ]; then
        echo "ℹ️  ${label} 섹션 비어있음 — skip"
        return 0
    fi

    local body
    body=$(sed -n "${body_start},${body_end}p" "$ISSUE_FILE")
    if ! echo "$body" | grep -q "^## "; then
        echo "ℹ️  ${label} 섹션에 이슈 항목 없음 — skip"
        return 0
    fi

    {
        echo ""
        echo "## Release ${VERSION} — ${TODAY} (${label})"
        echo ""
        echo "$body"
    } >> "$ARCHIVE_FILE"

    {
        sed -n "1,${header_line}p" "$ISSUE_FILE"
        echo ""
        echo "> ${pointer}"
        echo ""
        sed -n "${next_header},\$p" "$ISSUE_FILE"
    } > "${ISSUE_FILE}.tmp"
    mv "${ISSUE_FILE}.tmp" "$ISSUE_FILE"

    local count
    count=$(echo "$body" | grep -c "^## " || true)
    echo "✅ ${count}개 ${label} 이슈 아카이브 (Release ${VERSION})"
}

archive_section "# ✅ 완료" "완료" \
    "누적된 완료 이슈는 [z_old/old_issue.md](z_old/old_issue.md)로 아카이브됨 (Release ${VERSION}, ${TODAY})."

archive_section "# 🚫 취소" "취소" \
    "취소된 이슈는 [z_old/old_issue.md](z_old/old_issue.md)로 아카이브됨 (Release ${VERSION}, ${TODAY})."
