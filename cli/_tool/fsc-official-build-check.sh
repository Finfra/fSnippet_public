#!/bin/bash
# tdd #17 official-build-marker (Issue238) — build-level check of the Official Build split.
#
# Property under test:
#   1. An official build (FSNIPPET_OFFICIAL_BUILD=YES) carries Official/official-build.txt and
#      Legal/{LICENSE,NOTICE,TRADEMARK.md,DISTRIBUTION-TERMS.md,DISTRIBUTION-TERMS_ko.md}, and its
#      code signature is still valid (the files are copied before signing, so the seal covers them).
#      The Korean terms ship too (Issue241): §10 gives them equal force for individuals resident
#      in Korea, and §6 presents the terms inside the package.
#   2. A source build in the same DerivedData right after it carries neither — nothing an
#      official build left behind may leak into a source build.
#   3. An official build on top of that source build (publish from a developer's DerivedData)
#      is again complete and validly signed. 2 and 3 guard against Xcode skipping CodeSign
#      when only the build phase changed the bundle (seen before the OfficialBuildState stamp).
#   4. `fSnippetCli --version` of the official build prints the "Finfra Official Build" line
#      (needs a running service on :3015 — reported as SKIP when absent, never as PASS).
#   5. (tdd #18, Issue242) The app icon is an Official Build Component too: the official build
#      ships Resources/AppIcon.icns made from cli/resources/official/AppIcon.iconset, while the
#      source build carries no icon at all (no AppIcon.icns, no icon in Assets.car, no
#      CFBundleIconName) and shows the macOS default app icon.
#   6. (Issue241) The publish gate (fsc-deploy-brew.sh Step 2.6) refuses a release that lacks any
#      of the Legal files above — the bundle list and the gate list must not drift apart.
#
# Usage: bash cli/_tool/fsc-official-build-check.sh
#   DEPLOY_NO_SIGN=1  build unsigned (SSH-only hosts such as jma); the signature check is SKIPped
# Exit: 0 = all checks passed (SKIPs listed), 1 = at least one FAIL

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$CLI_DIR")"
DD="$(mktemp -d /tmp/fsc-official-build-check.XXXXXX)"
APP="$DD/Build/Products/Release/fSnippetCli.app"
RES="$APP/Contents/Resources"
LEGAL_FILES=(LICENSE NOTICE TRADEMARK.md DISTRIBUTION-TERMS.md DISTRIBUTION-TERMS_ko.md)
ICONSET="$CLI_DIR/resources/official/AppIcon.iconset"
EXPECTED_ICNS="$DD/expected-AppIcon.icns"

PASS=0
FAIL=0
SKIP=0
pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP  $1"; SKIP=$((SKIP + 1)); }

sign_args=()
if [ "${DEPLOY_NO_SIGN:-0}" = "1" ]; then
    sign_args=(CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO)
fi

build() {
    # $@ = extra build settings
    (cd "$CLI_DIR" && xcodebuild -project fSnippetCli.xcodeproj -scheme fSnippetCli \
        -configuration Release -derivedDataPath "$DD" build "${sign_args[@]}" "$@" 2>&1 | tail -3)
    return "${PIPESTATUS[0]}"
}

check_signature() {
    if [ "${DEPLOY_NO_SIGN:-0}" = "1" ]; then
        skip "$1: signature (DEPLOY_NO_SIGN=1)"
    elif codesign --verify --strict "$APP" 2>/dev/null; then
        pass "$1: codesign --verify --strict"
    else
        fail "$1: codesign --verify --strict"
    fi
}

plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$1" "$APP/Contents/Info.plist" 2>/dev/null
}

check_no_catalog_icon() {
    # $1 = label. CFBundleIconName (an asset-catalog icon) would override CFBundleIconFile.
    if [ -n "$(plist_value CFBundleIconName)" ]; then
        fail "$1: Info.plist has CFBundleIconName (asset-catalog icon)"
    else
        pass "$1: Info.plist has no CFBundleIconName"
    fi
    if [ -f "$RES/Assets.car" ] \
        && assetutil --info "$RES/Assets.car" 2>/dev/null | grep -Eq '"AssetType" : "Icon Image"|"Name" : "AppIcon"'; then
        fail "$1: Assets.car carries an app icon"
    else
        pass "$1: Assets.car carries no app icon"
    fi
}

check_official() {
    # $1 = label
    local marker="$RES/Official/official-build.txt"
    if [ -f "$marker" ] && awk 'NF { print; exit }' "$marker" | grep -q '^Finfra Official Build'; then
        pass "$1: Official/official-build.txt starts with 'Finfra Official Build'"
    else
        fail "$1: Official/official-build.txt missing or wrong banner"
    fi
    for f in "${LEGAL_FILES[@]}"; do
        if [ -f "$RES/Legal/$f" ] && cmp -s "$RES/Legal/$f" "$REPO_ROOT/$f"; then
            pass "$1: Legal/$f matches repository"
        else
            fail "$1: Legal/$f missing or differs from repository"
        fi
    done
    if [ -f "$RES/AppIcon.icns" ] && [ -f "$EXPECTED_ICNS" ] && cmp -s "$RES/AppIcon.icns" "$EXPECTED_ICNS"; then
        pass "$1: AppIcon.icns is the official icon (resources/official/AppIcon.iconset)"
    else
        fail "$1: AppIcon.icns missing or not the official icon"
    fi
    if [ "$(plist_value CFBundleIconFile)" = "AppIcon" ]; then
        pass "$1: Info.plist CFBundleIconFile = AppIcon"
    else
        fail "$1: Info.plist CFBundleIconFile is '$(plist_value CFBundleIconFile)', not AppIcon"
    fi
    if [ -e "$RES/Official/AppIcon.iconset" ]; then
        fail "$1: the iconset source was copied into Official/"
    else
        pass "$1: no iconset source under Official/"
    fi
    check_no_catalog_icon "$1"
    check_signature "$1"

    if curl -s -m 2 -o /dev/null http://localhost:3015/api/v2/status; then
        local out
        out="$("$APP/Contents/MacOS/fSnippetCli" --version 2>&1)"
        if echo "$out" | grep -q 'Distribution.*Finfra Official Build'; then
            pass "$1: --version prints the Finfra Official Build line"
        else
            fail "$1: --version lacks the Finfra Official Build line"
            echo "$out" | sed 's/^/        /'
        fi
    else
        skip "$1: --version (no service on :3015)"
    fi
}

echo "=== 0. expected official icon ← $ICONSET"
if iconutil -c icns "$ICONSET" -o "$EXPECTED_ICNS" 2>/dev/null; then
    pass "iconutil builds the official icon from the iconset"
else
    fail "iconutil could not build $ICONSET"
fi

echo "=== 0b. publish gate (fsc-deploy-brew.sh Step 2.6) requires every Legal file"
GATE_LINE="$(grep -E '^[[:space:]]*for LEGAL_F in ' "$SCRIPT_DIR/fsc-deploy-brew.sh")"
if [ "$(printf '%s\n' "$GATE_LINE" | grep -c .)" -ne 1 ]; then
    fail "publish gate: expected exactly one 'for LEGAL_F in' line in fsc-deploy-brew.sh"
else
    for f in "${LEGAL_FILES[@]}"; do
        if printf '%s\n' "$GATE_LINE" | tr ' ;' '\n\n' | grep -qxF "$f"; then
            pass "publish gate: requires Legal/$f"
        else
            fail "publish gate: does not require Legal/$f"
        fi
    done
fi

echo "=== 1. official build (FSNIPPET_OFFICIAL_BUILD=YES) → $DD"
if build FSNIPPET_OFFICIAL_BUILD=YES; then
    check_official "official"
else
    fail "official build failed"
fi

echo "=== 2. source build in the same DerivedData (no flag)"
if build; then
    if [ -e "$RES/Official" ] || [ -e "$RES/Legal" ]; then
        fail "source: Official/ or Legal/ left in the bundle"
    else
        pass "source: no Official/ and no Legal/ in the bundle"
    fi
    if [ -e "$RES/AppIcon.icns" ]; then
        fail "source: AppIcon.icns in the bundle"
    else
        pass "source: no AppIcon.icns in the bundle"
    fi
    check_no_catalog_icon "source"
    check_signature "source"

    if curl -s -m 2 -o /dev/null http://localhost:3015/api/v2/status; then
        out="$("$APP/Contents/MacOS/fSnippetCli" --version 2>&1)"
        if echo "$out" | grep -q 'Distribution'; then
            fail "source: --version shows a Distribution line"
            echo "$out" | sed 's/^/        /'
        else
            pass "source: --version shows no Distribution line"
        fi
    else
        skip "source: --version (no service on :3015)"
    fi
else
    fail "source build failed"
fi

echo "=== 3. official build again on top of the source build"
if build FSNIPPET_OFFICIAL_BUILD=YES; then
    check_official "official-after-source"
else
    fail "official build (after source) failed"
fi

rm -rf "$DD"
echo ""
echo "result: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[ "$FAIL" -eq 0 ]
