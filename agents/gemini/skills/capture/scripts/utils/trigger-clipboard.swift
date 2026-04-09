import Cocoa

let src = CGEventSource(stateID: .hidSystemState)

// cmd + ;
let eventDown = CGEvent(keyboardEventSource: src, virtualKey: 41, keyDown: true)
let eventUp = CGEvent(keyboardEventSource: src, virtualKey: 41, keyDown: false)
let flags: CGEventFlags = [.maskCommand]

eventDown?.flags = flags
eventUp?.flags = flags

eventDown?.post(tap: .cghidEventTap)
eventUp?.post(tap: .cghidEventTap)
