#!/usr/bin/env python3
"""
keycode_map.py — special token -> macOS keycode + event metadata.

SSOT: cli/_doc_arch/key-event/design_keyProcess.md "Single Shortcut Table".
Used by qa_type.py to translate testTable_org.md abbreviation tokens
(e.g. {right_command}, {f1}, {keypad_comma}) into real CGEvent keystrokes.
"""

# --- CGEventFlags (device-independent) ---
CGFLAG_COMMAND = 0x00100000
CGFLAG_OPTION = 0x00080000
CGFLAG_CONTROL = 0x00040000

# --- IOKit device-dependent modifier masks (IOLLEvent.h) ---
NX_DEVICERCMDKEYMASK = 0x00000010  # right command
NX_DEVICERALTKEYMASK = 0x00000040  # right option
NX_DEVICERCTLKEYMASK = 0x00002000  # right control

# Modifier tokens: emitted as a flagsChanged down/up tap (no character).
# flags = device-independent mask | device-dependent right-side mask,
# matching CGEventTapManager detection (see send_right_cmd.py for the
# right_command reference: 0x00100010).
MODIFIER_TOKENS = {
    "{right_command}": {"keycode": 54, "flags": CGFLAG_COMMAND | NX_DEVICERCMDKEYMASK},
    "{right_option}":  {"keycode": 61, "flags": CGFLAG_OPTION | NX_DEVICERALTKEYMASK},
    "{right_control}": {"keycode": 62, "flags": CGFLAG_CONTROL | NX_DEVICERCTLKEYMASK},
    "{right_ctrl}":    {"keycode": 62, "flags": CGFLAG_CONTROL | NX_DEVICERCTLKEYMASK},
}

# Plain key tokens: emitted as a normal keyDown/keyUp pair.
# NOTE: design_keyProcess.md's Single Shortcut Table swaps the keypad codes;
# the standard macOS HIToolbox values are authoritative here:
#   kVK_JIS_KeypadComma  = 0x5F (95)
#   kVK_ANSI_KeypadClear = 0x47 (71)  -- the "num_lock" key
KEY_TOKENS = {
    "{f1}": 122,
    "{f2}": 120,
    "{keypad_comma}": 95,
    "{keypad_num_lock}": 71,
}


def classify(token: str):
    """Return ('modifier', meta) | ('key', keycode) | (None, None) for a {token}."""
    if token in MODIFIER_TOKENS:
        return "modifier", MODIFIER_TOKENS[token]
    if token in KEY_TOKENS:
        return "key", KEY_TOKENS[token]
    return None, None
