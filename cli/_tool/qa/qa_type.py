#!/usr/bin/env python3
"""
qa_type.py — keystroke typer for the FolderTest QA harness (Issue138).

Two delivery paths, chosen per abbreviation — they are NEVER mixed within one
case, because running an osascript subprocess invalidates this process's later
Quartz CGEventPost (a literal typed after an AppleScript token was dropped).

  * abbreviation contains {f1}/{f2}/{keypad_num_lock}
      -> ALL of it via a single AppleScript (osascript) session: literal runs
         as `keystroke`, those tokens as `key code`. These keys need real
         keycodes that accumulate into the engine buffer (Quartz tap_key made
         them resolve as folderPrefix and open a popup).
  * everything else
      -> ALL of it via Quartz: literals as unicode keystrokes (IME-independent,
         every char incl. '-'), {keypad_comma} as a Quartz keycode (AppleScript
         drops keycode 95 on US layouts), modifier tokens as flagsChanged.

Run force_ascii.py first so the AppleScript `keystroke` path is not garbled by
a Korean IME.

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

DEFAULT_KEY_DELAY = 0.04
MODIFIER_HOLD = 0.05

_TOKEN_RE = re.compile(r"(\{[^}]+\})")

# Tokens that must go through AppleScript `key code` (real keycode → buffer
# accumulation). Their presence routes the whole abbreviation to AppleScript.
_APPLESCRIPT_TOKENS = {"{f1}", "{f2}", "{keypad_num_lock}"}


# --- Quartz path ---

def type_char(ch: str, delay: float) -> None:
    """Quartz unicode keyDown/keyUp — IME-independent, any character."""
    for is_down in (True, False):
        ev = Quartz.CGEventCreateKeyboardEvent(None, 0, is_down)
        Quartz.CGEventKeyboardSetUnicodeString(ev, len(ch), ch)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)
        time.sleep(delay)


def tap_key(keycode: int, delay: float) -> None:
    """Quartz keyDown/keyUp for a fixed keycode (e.g. keypad_comma=95)."""
    for is_down in (True, False):
        ev = Quartz.CGEventCreateKeyboardEvent(None, keycode, is_down)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)
        time.sleep(delay)


def tap_modifier(keycode: int, flags: int) -> None:
    """Quartz flagsChanged down/up — a modifier tap."""
    down = Quartz.CGEventCreateKeyboardEvent(None, keycode, True)
    Quartz.CGEventSetType(down, Quartz.kCGEventFlagsChanged)
    Quartz.CGEventSetFlags(down, flags)
    Quartz.CGEventPost(Quartz.kCGHIDEventTap, down)
    time.sleep(MODIFIER_HOLD)

    up = Quartz.CGEventCreateKeyboardEvent(None, keycode, False)
    Quartz.CGEventSetType(up, Quartz.kCGEventFlagsChanged)
    Quartz.CGEventSetFlags(up, 0)
    Quartz.CGEventPost(Quartz.kCGHIDEventTap, up)


def type_via_quartz(text: str, delay: float) -> None:
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
                time.sleep(delay)
            else:
                for ch in part:
                    type_char(ch, delay)
        else:
            for ch in part:
                type_char(ch, delay)


# --- AppleScript path (single osascript session) ---

def type_via_applescript(text: str) -> None:
    """Type the whole abbreviation in one osascript invocation.

    A single session keeps token (`key code`) and literal (`keystroke`) in the
    same process, in order — no Quartz is involved, so nothing is dropped.
    """
    args = ["osascript"]
    for part in _TOKEN_RE.split(text):
        if not part:
            continue
        if part.startswith("{") and part.endswith("}"):
            kind, meta = classify(part)
            if kind == "key":
                args += ["-e",
                         f'tell application "System Events" to key code {meta}']
            elif kind == "modifier":
                args += ["-e",
                         f'tell application "System Events" to key code {meta["keycode"]}']
            else:
                esc = part.replace("\\", "\\\\").replace('"', '\\"')
                args += ["-e",
                         f'tell application "System Events" to keystroke "{esc}"']
        else:
            esc = part.replace("\\", "\\\\").replace('"', '\\"')
            args += ["-e",
                     f'tell application "System Events" to keystroke "{esc}"']
        args += ["-e", "delay 0.12"]
    subprocess.run(args, check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def type_string(text: str, delay: float = DEFAULT_KEY_DELAY) -> None:
    """Route the whole abbreviation to one path — never mix within a case."""
    if any(tok in text for tok in _APPLESCRIPT_TOKENS):
        type_via_applescript(text)
    else:
        type_via_quartz(text, delay)


def main() -> int:
    ap = argparse.ArgumentParser(description="keystroke typer")
    ap.add_argument("text", help="abbreviation string to type")
    ap.add_argument("--delay", type=float, default=DEFAULT_KEY_DELAY,
                    help=f"inter-keystroke delay seconds (default {DEFAULT_KEY_DELAY})")
    args = ap.parse_args()
    type_string(args.text, args.delay)
    return 0


if __name__ == "__main__":
    sys.exit(main())
