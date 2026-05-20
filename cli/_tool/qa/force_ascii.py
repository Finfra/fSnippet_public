#!/usr/bin/env python3
"""
force_ascii.py — switch the keyboard input source to a plain ASCII layout.

AppleScript `keystroke` (used by qa_type.py) renders through the active input
method: a Korean IME would turn 'test' into Hangul, so the engine never sees
the intended abbreviation. Run this once before the keyboard harness.

Uses the Carbon Text Input Source (TIS) API via pyobjc.
"""
import sys

import objc
from Foundation import NSBundle

_HI_PATH = "/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework"


def force_ascii() -> str:
    bundle = NSBundle.bundleWithPath_(_HI_PATH)
    objc.loadBundleFunctions(bundle, globals(), [
        ("TISCreateInputSourceList", b"@@Z"),
        ("TISSelectInputSource", b"i@"),
    ])
    for sid in ("com.apple.keylayout.ABC", "com.apple.keylayout.US"):
        lst = TISCreateInputSourceList({"TISPropertyInputSourceID": sid}, False)
        if lst and len(lst):
            TISSelectInputSource(lst[0])
            return sid
    return ""


if __name__ == "__main__":
    chosen = force_ascii()
    if chosen:
        print(f"input source -> {chosen}")
        sys.exit(0)
    print("warning: no ASCII keyboard layout found", file=sys.stderr)
    sys.exit(1)
