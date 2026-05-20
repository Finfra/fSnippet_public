#!/usr/bin/env python3
"""
qa_type.py — Quartz CGEvent keystroke typer for the FolderTest QA harness.

Types a testTable_org.md `abbreviation` string into the focused app:
  * literal characters  -> unicode keystroke (handles 한글, ø, ¥, ∆, ...)
  * {modifier} tokens   -> flagsChanged down/up tap (right_command, ...)
  * {key} tokens        -> normal keyDown/keyUp (f1, keypad_comma, ...)

CLI:
  python3 qa_type.py "test{right_command}"
  python3 qa_type.py --delay 0.04 "{right_option}test{right_command}"

Requires the pyobjc Quartz binding and Accessibility permission for the
process posting the events (Terminal / python).
"""
import argparse
import re
import sys
import time

import Quartz

from keycode_map import classify

# Default inter-keystroke delay (seconds). Tunable via --delay.
DEFAULT_KEY_DELAY = 0.03
# Hold time for a modifier flagsChanged down before the matching up.
MODIFIER_HOLD = 0.05

_TOKEN_RE = re.compile(r"(\{[^}]+\})")


def type_char(ch: str, delay: float) -> None:
    """Post a unicode keyDown/keyUp pair carrying a single character."""
    for is_down in (True, False):
        ev = Quartz.CGEventCreateKeyboardEvent(None, 0, is_down)
        Quartz.CGEventKeyboardSetUnicodeString(ev, len(ch), ch)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)
        time.sleep(delay)


def tap_modifier(keycode: int, flags: int) -> None:
    """Post a flagsChanged down (with flags) then up (cleared) — a modifier tap."""
    down = Quartz.CGEventCreateKeyboardEvent(None, keycode, True)
    Quartz.CGEventSetType(down, Quartz.kCGEventFlagsChanged)
    Quartz.CGEventSetFlags(down, flags)
    Quartz.CGEventPost(Quartz.kCGHIDEventTap, down)
    time.sleep(MODIFIER_HOLD)

    up = Quartz.CGEventCreateKeyboardEvent(None, keycode, False)
    Quartz.CGEventSetType(up, Quartz.kCGEventFlagsChanged)
    Quartz.CGEventSetFlags(up, 0)
    Quartz.CGEventPost(Quartz.kCGHIDEventTap, up)


def tap_key(keycode: int, delay: float) -> None:
    """Post a normal keyDown/keyUp pair for a fixed keycode."""
    for is_down in (True, False):
        ev = Quartz.CGEventCreateKeyboardEvent(None, keycode, is_down)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)
        time.sleep(delay)


def type_string(text: str, delay: float = DEFAULT_KEY_DELAY) -> None:
    """Tokenize `text` into {tokens} + literals and post each as a keystroke."""
    for part in _TOKEN_RE.split(text):
        if not part:
            continue
        if part.startswith("{") and part.endswith("}"):
            kind, meta = classify(part)
            if kind == "modifier":
                tap_modifier(meta["keycode"], meta["flags"])
                time.sleep(delay)
            elif kind == "key":
                tap_key(meta, delay)
            else:
                # Unknown token: type it literally so the failure is visible.
                for ch in part:
                    type_char(ch, delay)
        else:
            for ch in part:
                type_char(ch, delay)


def main() -> int:
    ap = argparse.ArgumentParser(description="CGEvent keystroke typer")
    ap.add_argument("text", help="abbreviation string to type")
    ap.add_argument("--delay", type=float, default=DEFAULT_KEY_DELAY,
                    help=f"inter-keystroke delay seconds (default {DEFAULT_KEY_DELAY})")
    args = ap.parse_args()
    type_string(args.text, args.delay)
    return 0


if __name__ == "__main__":
    sys.exit(main())
