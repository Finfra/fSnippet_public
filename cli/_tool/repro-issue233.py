#!/usr/bin/env python3
"""
Issue233 reproduction: swallowed keys must not count toward the input-path asymmetry check.

Opens a one-shot REST key-capture session before every synthetic keyDown, so the
CGEventTap swallows each key (`captureKeyIfActive` -> return nil). Swallowed events never
reach the NSEvent monitors. Cycling 3 distinct keyCodes for longer than two 3s watchdog
windows used to satisfy `tapDistinctN >= 3 && monN == 0` twice in a row and tear the tap
down as "permission lost" while permission was fine.

Usage: python3 repro-issue233.py [seconds=10]
Pass: no "[Watchdog] 입력 경로 비대칭" line in flog_cliApp.log during the run.
"""
import json
import sys
import time
import urllib.request

import Quartz

API = "http://localhost:3015/api/v2/key-capture"
KEY_CODES = [0, 1, 2]  # a, s, d -- only keyDown is swallowed; a bare keyUp is harmless


def post(path, method="POST"):
    req = urllib.request.Request(f"{API}/{path}", method=method, data=b"" if method == "POST" else None)
    with urllib.request.urlopen(req, timeout=2) as r:
        return json.loads(r.read() or b"{}")


def key(code, down):
    ev = Quartz.CGEventCreateKeyboardEvent(None, code, down)
    Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)


def main():
    seconds = float(sys.argv[1]) if len(sys.argv) > 1 else 10.0
    end = time.time() + seconds
    sent = captured = 0
    i = 0
    while time.time() < end:
        code = KEY_CODES[i % len(KEY_CODES)]
        post("start")
        key(code, True)
        time.sleep(0.03)
        key(code, False)
        sent += 1
        time.sleep(0.25)
        try:
            res = urllib.request.urlopen(f"{API}/result", timeout=2).read().decode()
            if "captured" in res:
                captured += 1
        except Exception:
            pass
        i += 1
    try:
        post("stop", method="DELETE")
    except Exception:
        pass
    print(json.dumps({"sent": sent, "captured": captured, "seconds": seconds}))


if __name__ == "__main__":
    main()
