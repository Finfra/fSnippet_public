import Cocoa

let src = CGEventSource(stateID: .hidSystemState)

// cmd + e
let eventDown = CGEvent(keyboardEventSource: src, virtualKey: 14, keyDown: true)
let eventUp = CGEvent(keyboardEventSource: src, virtualKey: 14, keyDown: false)
let flags: CGEventFlags = [.maskCommand]

eventDown?.flags = flags
eventUp?.flags = flags

eventDown?.post(tap: .cghidEventTap)
eventUp?.post(tap: .cghidEventTap)
