import Cocoa

let src = CGEventSource(stateID: .hidSystemState)

// cmd + s
let eventDown = CGEvent(keyboardEventSource: src, virtualKey: 1, keyDown: true)
let eventUp = CGEvent(keyboardEventSource: src, virtualKey: 1, keyDown: false)
let flags: CGEventFlags = [.maskCommand]

eventDown?.flags = flags
eventUp?.flags = flags

eventDown?.post(tap: .cghidEventTap)
eventUp?.post(tap: .cghidEventTap)
