import Cocoa

/// 기본 텍스트 편집 단축키(Cmd+C, Cmd+V, Cmd+X, Cmd+A 등)를 처리하는 공통 로직
private func handleCommandKeyEquivalent(with event: NSEvent, from sender: Any) -> Bool {
    guard event.modifierFlags.contains(.command) else { return false }
    switch event.charactersIgnoringModifiers {
    case "x":
        return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: sender)
    case "c":
        return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: sender)
    case "v":
        return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: sender)
    case "z":
        if event.modifierFlags.contains(.shift) {
            return NSApp.sendAction(Selector(("redo:")), to: nil, from: sender)
        }
        return NSApp.sendAction(Selector(("undo:")), to: nil, from: sender)
    case "a":
        return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: sender)
    default:
        return false
    }
}

/// 기본 텍스트 편집 단축키(Cmd+C, Cmd+V, Cmd+X 등)를 SwiftUI View 내 텍스트 필드로 전달하기 위한 NSWindow 서브클래스
class CommandHandlingWindow: NSWindow {
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if super.performKeyEquivalent(with: event) {
        return true
    }
    return handleCommandKeyEquivalent(with: event, from: self)
  }
}

/// NSPanel 버전 — nonactivatingPanel 등 패널 전용 스타일이 필요한 윈도우에서 사용
class CommandHandlingPanel: NSPanel {
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if super.performKeyEquivalent(with: event) {
        return true
    }
    return handleCommandKeyEquivalent(with: event, from: self)
  }
}
