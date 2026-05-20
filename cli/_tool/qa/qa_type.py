#!/usr/bin/env python3
"""
qa_type.py — hybrid keystroke typer for the FolderTest QA harness (Issue138).

  literal chars     -> Quartz unicode keystroke (CGEventKeyboardSetUnicodeString).
                       Bypasses the IME entirely, so the active input source /
                       Hangul does not matter, and every character (incl. '-',
                       'ø', '∆', …) is delivered. AppleScript `keystroke` went
                       through the IME and silently dropped some characters.
  plain-key tokens  -> AppleScript `key code` (f1/f2/keypad). These accumulate
                       into the engine buffer as tokens; Quartz tap_key made the
                       same key resolve as folderPrefix and open a popup.
  modifier tokens   -> Quartz flagsChanged (right_command/option/control).
                       AppleScript `key code` does not emit the flagsChanged
                       event the engine needs for a modifier trigger.

CLI:
  python3 qa_type.py "test{f1}"
  python3 qa_type.py --delay 0.05 -- "{right_option}test{right_command}"
"""
import argparse
import re
import subprocess
import sys
import time

import Quartz

from keycode_map import classify

# Default inter-keystroke delay (seconds). Tunable via --delay.
DEFAULT_KEY_DELAY = 0.04
# Hold time for a modifier flagsChanged down before the matching up.
MODIFIER_HOLD = 0.05
# Settle after a {token}: an AppleScript `key code` subprocess returns before
# the OS finishes the event, so a following Quartz keystroke is lost without
# this pause (observed: {f1} prefix swallowed the next literal). (Issue138)
TOKEN_SETTLE = 0.3

_TOKEN_RE = re.compile(r"(\{[^}]+\})")


def type_char(ch: str, delay: float) -> None:
    """Post a unicode keyDown/keyUp pair — IME-independent, any character."""
    for is_down in (True, False):
        ev = Quartz.CGEventCreateKeyboardEvent(None, 0, is_down)
        Quartz.CGEventKeyboardSetUnicodeString(ev, len(ch), ch)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)
        time.sleep(delay)


def as_keycode(code: int) -> None:
    """Press a plain key (f1, f2, keypad_num_lock) via AppleScript System Events.

    A trailing `delay` keeps the osascript process alive until the OS has
    finished the key event — otherwise a following Quartz keystroke posted
    immediately after can be lost.
    """
    subprocess.run(
        ["osascript",
         "-e", f'tell application "System Events" to key code {code}',
         "-e", "delay 0.35"],
        check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def tap_key(keycode: int, delay: float) -> None:
    """Quartz keyDown/keyUp — for keys AppleScript `key code` ignores.

    AppleScript silently drops a `key code` for a key absent on the active
    physical layout (e.g. keypad_comma=95, a JIS-only key). Quartz posts the
    keycode directly regardless of layout.
    """
    for is_down in (True, False):
        ev = Quartz.CGEventCreateKeyboardEvent(None, keycode, is_down)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)
        time.sleep(delay)


def tap_modifier(keycode: int, flags: int) -> None:
    """Post a flagsChanged down (with flags) then up (cleared) via Quartz."""
    down = Quartz.CGEventCreateKeyboardEvent(None, keycode, True)
    Quartz.CGEventSetType(down, Quartz.kCGEventFlagsChanged)
    Quartz.CGEventSetFlags(down, flags)
    Quartz.CGEventPost(Quartz.kCGHIDEventTap, down)
    time.sleep(MODIFIER_HOLD)

    up = Quartz.CGEventCreateKeyboardEvent(None, keycode, False)
    Quartz.CGEventSetType(up, Quartz.kCGEventFlagsChanged)
    Quartz.CGEventSetFlags(up, 0)
    Quartz.CGEventPost(Quartz.kCGHIDEventTap, up)


def type_string(text: str, delay: float = DEFAULT_KEY_DELAY) -> None:
    """Tokenize `text` into {tokens} + literals and type each."""
    for part in _TOKEN_RE.split(text):
        if not part:
            continue
        if part.startswith("{") and part.endswith("}"):
            kind, meta = classify(part)
            if kind == "modifier":
                tap_modifier(meta["keycode"], meta["flags"])
                time.sleep(TOKEN_SETTLE)
            elif kind == "key":
                # keypad_comma (95) is absent on US layouts — AppleScript
                # `key code` drops it, so post it via Quartz instead.
                if part == "{keypad_comma}":
                    tap_key(meta, delay)
                else:
                    as_keycode(meta)
                time.sleep(TOKEN_SETTLE)
            else:
                # Unknown token: type it literally so the failure is visible.
                for ch in part:
                    type_char(ch, delay)
        else:
            for ch in part:
                type_char(ch, delay)


def main() -> int:
    ap = argparse.ArgumentParser(description="hybrid keystroke typer")
    ap.add_argument("text", help="abbreviation string to type")
    ap.add_argument("--delay", type=float, default=DEFAULT_KEY_DELAY,
                    help=f"inter-keystroke delay seconds (default {DEFAULT_KEY_DELAY})")
    args = ap.parse_args()
    type_string(args.text, args.delay)
    return 0


if __name__ == "__main__":
    sys.exit(main())
