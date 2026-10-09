#!/bin/bash
# selftest.sh - proves apiTestDo.sh turns a failing case into a non-zero exit (Issue258).
# Runs against a stub HTTP server, never against a real fSnippetCli instance.
# Usage: bash cli/_tool/apiTest/selftest.sh
HERE="$(cd "$(dirname "$0")" && pwd)"
PORT="${SELFTEST_PORT:-3199}"
WORK="$(mktemp -d)"
trap 'kill $STUB_PID 2>/dev/null; rm -rf "$WORK"' EXIT

cat > "$WORK/stub.py" <<'PY'
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def _send(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        if self.path.endswith("/boom"): return self._send(500, {"ok": False})
        if self.path.endswith("/empty"): return self._send(200, {"ok": True, "data": {}})
        return self._send(200, {"ok": True, "data": {"name": "x"}})
    do_POST = do_PUT = do_PATCH = do_DELETE = do_GET
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY
python3 "$WORK/stub.py" "$PORT" & STUB_PID=$!
for _ in $(seq 20); do curl -s -m1 -o /dev/null "http://127.0.0.1:$PORT/" && break; sleep 0.2; done

mkdir -p "$WORK/v2"
fail=0
# check <name> <expected rc> <expected output regex>
check() {
  local out rc
  out=$(FSC_API_PORT=$PORT APITEST_BURST_DELAY=0 APITEST_DIR="$WORK" bash "$HERE/apiTestDo.sh" v2 2>&1); rc=$?
  if [ "$rc" -ne "$2" ] || ! echo "$out" | grep -qE "$3"; then
    echo "❌ selftest $1: rc=$rc (want $2), want /$3/"; echo "$out" | sed 's/^/    /'; fail=1
  else
    echo "✅ selftest $1"
  fi
}

# case 1: passing script -> rc 0, 실패=0
cat > "$WORK/v2/00.ok.sh" <<'CASE'
. "$APITEST_LIB"
expect_status "get ok" 200 GET /settings/x
expect_jq "has name" '.data.name == "x"'
api_finish
CASE
check "pass" 0 '실패=0'

# case 2: wrong HTTP status -> rc != 0
cat > "$WORK/v2/01.badstatus.sh" <<'CASE'
. "$APITEST_LIB"
expect_status "boom is 200?" 200 GET /boom
api_finish
CASE
check "bad-status" 1 '실패=1'

# case 3: status ok but field missing -> failure
rm "$WORK/v2/01.badstatus.sh"
cat > "$WORK/v2/02.badfield.sh" <<'CASE'
. "$APITEST_LIB"
expect_status "empty" 200 GET /empty
expect_jq "needs name" '.data.name != null'
api_finish
CASE
check "bad-field" 1 '실패=1'

# case 4: legacy script with no assertions -> counted as failure (no silent pass)
rm "$WORK/v2/02.badfield.sh"
printf '#!/bin/bash\ncurl -s localhost:1 | jq .\n' > "$WORK/v2/03.legacy.sh"
check "no-assertion" 1 '실패=1'

# case 5: script that dies without reaching api_finish -> failure
rm "$WORK/v2/03.legacy.sh"
printf '. "$APITEST_LIB"\nexit 0\n' > "$WORK/v2/04.noverdict.sh"
check "no-verdict" 1 '실패=1'

exit $fail
