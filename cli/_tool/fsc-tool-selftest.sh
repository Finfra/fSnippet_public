#!/bin/bash
# fsc-tool-selftest.sh — regression tests for the cli/_tool test & deploy scripts themselves (Issue244 ③④⑤⑥, Issue252 ③)
#
# Each case cuts the function under test out of the real script (sed) and runs it against fakes
# (xcodebuild / brew / fSnippetCli / a throw-away git tap) — no build, no brew, no running app.
# Run with the system bash on purpose: jma's /bin/bash is 3.2 and that is where ④ broke.
#
#   /bin/bash cli/_tool/fsc-tool-selftest.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0; NG=0
ok() { echo "ok   $1"; PASS=$((PASS + 1)); }
ng() { echo "FAIL $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/     | /'; NG=$((NG + 1)); }

# extract_fn <file> <name> — print the body of shell function <name>() { ... } (closing brace at col 0)
extract_fn() { sed -n "/^$2() *{/,/^}/p" "$1"; }

# ── ④ fsc-official-build-check.sh build(): empty sign_args under set -u (bash 3.2) ──────────
mkdir -p "$WORK/bin4"
cat > "$WORK/bin4/xcodebuild" <<'SH'
#!/bin/bash
echo "xcodebuild $*" >> "$FAKE_LOG"
exit "${FAKE_XCB_RC:-0}"
SH
chmod +x "$WORK/bin4/xcodebuild"
extract_fn "$HERE/fsc-official-build-check.sh" build > "$WORK/build.sh"
if [ ! -s "$WORK/build.sh" ]; then
    ng "④ build() not found in fsc-official-build-check.sh"
else
    run_build() {  # run_build <xcodebuild rc> → prints rc
        FAKE_LOG="$WORK/xcb.log" FAKE_XCB_RC=$1 PATH="$WORK/bin4:$PATH" CLI_DIR="$WORK" DD="$WORK/dd" \
            /bin/bash -c 'set -u; sign_args=(); source "$1"; build FSNIPPET_OFFICIAL_BUILD=YES; echo "rc=$?"' _ "$WORK/build.sh" 2>&1
    }
    : > "$WORK/xcb.log"
    out=$(run_build 0)
    if printf '%s' "$out" | grep -q 'rc=0' && grep -q 'FSNIPPET_OFFICIAL_BUILD=YES' "$WORK/xcb.log"; then
        ok "④ empty sign_args + set -u on bash 3.2 still runs xcodebuild"
    else
        ng "④ empty sign_args + set -u on bash 3.2 still runs xcodebuild" "$out"
    fi
    out=$(run_build 65)
    if printf '%s' "$out" | grep -q 'rc=65'; then
        ok "④ xcodebuild failure is returned by build() (not masked by | tail)"
    else
        ng "④ xcodebuild failure is returned by build() (not masked by | tail)" "$out"
    fi
fi

# ── ③a fsc-test.sh suite_verdict: a suite with failures must not be recorded as PASS ─────────
extract_fn "$HERE/fsc-test.sh" suite_verdict > "$WORK/verdict.sh"
if [ ! -s "$WORK/verdict.sh" ]; then
    ng "③a suite_verdict() not found in fsc-test.sh"
else
    v() { /bin/bash -c 'set -u; record_result() { echo "$2|$3"; }; source "$1"; suite_verdict CMD "$2" "$3"' _ "$WORK/verdict.sh" "$1" "$2"; }
    [ "$(v 30 0 | cut -d'|' -f1)" = PASS ] && ok "③a 30 run / 0 failed → PASS" || ng "③a 30 run / 0 failed → PASS" "$(v 30 0)"
    [ "$(v 30 1 | cut -d'|' -f1)" = FAIL ] && ok "③a 30 run / 1 failed → FAIL" || ng "③a 30 run / 1 failed → FAIL" "$(v 30 1)"
    [ "$(v 0 0 | cut -d'|' -f1)" = FAIL ]  && ok "③a nothing ran → FAIL"       || ng "③a nothing ran → FAIL" "$(v 0 0)"
fi

# ── ③b cmdTest v2/25.clipboard-get: look up a real id, SKIP (77) on empty history ─────────────
mkdir -p "$WORK/bin3"
cat > "$WORK/bin3/fakecli" <<'SH'
#!/bin/bash
echo "$*" >> "$FAKE_LOG"
case "$1 $2" in
  "clipboard list")
    [ -n "${FAKE_LIST_FAIL:-}" ] && { echo "service not running" >&2; exit 3; }
    if [ "$FAKE_HIST" = empty ]; then echo '{"ok":true,"data":[],"meta":{"total":0}}'
    else echo '{"ok":true,"data":[{"id":7,"kind":"text"}],"meta":{"total":1}}'; fi ;;
  "clipboard get") [ "$3" = 7 ] && { echo "id 7"; exit 0; }; echo "not found" >&2; exit 4 ;;
esac
SH
chmod +x "$WORK/bin3/fakecli"
run25() { : > "$WORK/cli.log"; FAKE_LIST_FAIL="${FAKE_LIST_FAIL:-}" FAKE_LOG="$WORK/cli.log" FAKE_HIST=$1 CLI="$WORK/bin3/fakecli" /bin/bash "$HERE/cmdTest/v2/25.clipboard-get.sh" > "$WORK/25.out" 2>&1; echo $?; }
rc=$(run25 empty)
if [ "$rc" = 77 ] && grep -q SKIP "$WORK/25.out" && ! grep -q '^clipboard get' "$WORK/cli.log"; then
    ok "③b empty history → SKIP (77), no blind get"
else
    ng "③b empty history → SKIP (77), no blind get" "rc=$rc; $(cat "$WORK/25.out" "$WORK/cli.log")"
fi
rc=$(run25 one)
if [ "$rc" = 0 ] && grep -q '^clipboard get 7' "$WORK/cli.log"; then
    ok "③b gets the id the list returned"
else
    ng "③b gets the id the list returned" "rc=$rc; $(cat "$WORK/25.out" "$WORK/cli.log")"
fi

rc=$(FAKE_LIST_FAIL=1 run25 one)
if [ "$rc" != 0 ] && [ "$rc" != 77 ] && grep -q FAIL "$WORK/25.out"; then
    ok "③b failing clipboard list → FAIL, not SKIP"
else
    ng "③b failing clipboard list → FAIL, not SKIP" "rc=$rc; $(cat "$WORK/25.out")"
fi

# ── ③c cmdTestDo run_normal: skip(77) is counted apart from success and failure ──────────────
mkdir -p "$WORK/suite"
printf '#!/bin/bash\nexit 0\n'  > "$WORK/suite/01.a.sh"
printf '#!/bin/bash\nexit 77\n' > "$WORK/suite/02.b.sh"
printf '#!/bin/bash\nexit 1\n'  > "$WORK/suite/03.c.sh"
extract_fn "$HERE/cmdTest/cmdTestDo.sh" run_normal > "$WORK/runnormal.sh"
out=$(/bin/bash -c 'source "$1"; run_normal "$2"' _ "$WORK/runnormal.sh" "$WORK/suite" 2>&1 | grep '결과:')
if printf '%s' "$out" | grep -q '성공=1' && printf '%s' "$out" | grep -q '실패=1' && printf '%s' "$out" | grep -q '건너뜀=1'; then
    ok "③c run_normal counts 성공=1 실패=1 건너뜀=1"
else
    ng "③c run_normal counts 성공=1 실패=1 건너뜀=1" "$out"
fi

# ── ⑥ / Issue252 ③ fsc-deploy-brew.sh: `local` leaves the tap work tree exactly as found ──────
DEPLOY="$HERE/fsc-deploy-brew.sh"
TAP="$WORK/tap"
mkdir -p "$TAP/Formula"
git -C "$TAP" init -q
printf 'class FsnippetCli < Formula\n  url "https://github.com/Finfra/fSnippet_public/releases/download/cli-v1.1.1/x.tar.gz"\nend\n' > "$TAP/Formula/fsnippet-cli.rb"
git -C "$TAP" add -A && git -C "$TAP" -c user.name=t -c user.email=t@t commit -qm init
{ for fn in tap_formula_guard tap_formula_backup tap_formula_restore cmd_local; do extract_fn "$DEPLOY" "$fn"; done; } > "$WORK/deploy-fns.sh"
if ! grep -q '^tap_formula_restore()' "$WORK/deploy-fns.sh" || ! grep -q '^cmd_local()' "$WORK/deploy-fns.sh"; then
    ng "⑥ tap_formula_* helpers / cmd_local wrapper not found in fsc-deploy-brew.sh"
else
    # cmd_local_body stands in for the real 9 steps: it overwrites the formula like Step 5 does,
    # records whether auto-update was disabled, and then succeeds or fails.
    run_local() {
        BODY_RC=$1 /bin/bash -c '
            TAP_DIR="$1"; TAP_FORMULA="$1/Formula/fsnippet-cli.rb"; source "$2"
            cmd_local_body() {
                echo "url \"file:///tmp/fSnippetCli-local.tar.gz\"" > "$TAP_FORMULA"
                echo "auto_update_off=${HOMEBREW_NO_AUTO_UPDATE:-}"
                return "$BODY_RC"
            }
            cmd_local; echo "rc=$?"' _ "$TAP" "$WORK/deploy-fns.sh" 2>&1
    }
    out=$(run_local 0)
    st=$(git -C "$TAP" status --porcelain)
    if [ -z "$st" ] && printf '%s' "$out" | grep -q 'auto_update_off=1' && printf '%s' "$out" | grep -q 'rc=0'; then
        ok "⑥ local success → tap clean, auto-update off during install"
    else
        ng "⑥ local success → tap clean, auto-update off during install" "$out; status=[$st]"
    fi
    out=$(run_local 3)
    st=$(git -C "$TAP" status --porcelain)
    if [ -z "$st" ] && printf '%s' "$out" | grep -q 'rc=3'; then
        ok "⑥ local failure → tap still restored, rc propagated"
    else
        ng "⑥ local failure → tap still restored, rc propagated" "$out; status=[$st]"
    fi
    # conflicted tap (the jm4 state of Issue252): refuse, touch nothing
    git -C "$TAP" checkout -q -b other
    printf 'class FsnippetCli < Formula\n  url "file:///tmp/a"\nend\n' > "$TAP/Formula/fsnippet-cli.rb"
    git -C "$TAP" -c user.name=t -c user.email=t@t commit -qam other
    git -C "$TAP" checkout -q -
    printf 'class FsnippetCli < Formula\n  url "file:///tmp/b"\nend\n' > "$TAP/Formula/fsnippet-cli.rb"
    git -C "$TAP" -c user.name=t -c user.email=t@t commit -qam main2
    git -C "$TAP" merge -q other >/dev/null 2>&1
    before=$(shasum "$TAP/Formula/fsnippet-cli.rb")
    out=$(run_local 0)
    after=$(shasum "$TAP/Formula/fsnippet-cli.rb")
    if printf '%s' "$out" | grep -q 'rc=1' && [ "$before" = "$after" ] && ! printf '%s' "$out" | grep -q 'auto_update_off'; then
        ok "⑥ conflicted tap → refuse before touching it"
    else
        ng "⑥ conflicted tap → refuse before touching it" "$out"
    fi
fi

# ── ⑤ fsc-deploy-brew.sh publish: the follow-up install is the published formula, not a local rebuild ──
if extract_fn "$DEPLOY" post_publish_install | grep -q .; then
    pp=$(extract_fn "$DEPLOY" post_publish_install)
    if printf '%s' "$pp" | grep -q 'cmd_local' || printf '%s' "$pp" | grep -q 'TAP_FORMULA"* *<<\|> *"*\$TAP_FORMULA'; then
        ng "⑤ post_publish_install must not rebuild locally or write the tap formula" "$pp"
    else
        ok "⑤ post_publish_install does not rebuild locally or write the tap formula"
    fi
else
    ng "⑤ post_publish_install() not found in fsc-deploy-brew.sh"
fi
dispatch=$(sed -n '/^    publish)/,/;;/p' "$DEPLOY")
if printf '%s' "$dispatch" | grep -q 'cmd_local'; then
    ng "⑤ publish dispatch still chains cmd_local" "$dispatch"
else
    ok "⑤ publish dispatch does not chain cmd_local"
fi

echo "== $PASS passed, $NG failed"
[ "$NG" -eq 0 ]
