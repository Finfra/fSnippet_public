import Cocoa

extension NSEvent.ModifierFlags {
    // Device-specific masks (based on NX_DEVICE... constants)
    static let deviceLeftShift = NSEvent.ModifierFlags(rawValue: 0x0000_0002)
    static let deviceRightShift = NSEvent.ModifierFlags(rawValue: 0x0000_0004)
    static let deviceLeftCommand = NSEvent.ModifierFlags(rawValue: 0x0000_0008)
    static let deviceRightCommand = NSEvent.ModifierFlags(rawValue: 0x0000_0010)
    static let deviceLeftOption = NSEvent.ModifierFlags(rawValue: 0x0000_0020)
    static let deviceRightOption = NSEvent.ModifierFlags(rawValue: 0x0000_0040)
    static let deviceLeftControl = NSEvent.ModifierFlags(rawValue: 0x0000_0001)
    static let deviceRightControl = NSEvent.ModifierFlags(rawValue: 0x0000_2000)  // 0x2000 confirmed for Right Control

    /// Returns a string representation identifying left/right modifiers (e.g., "right_command")
    /// Used for precise trigger key matching.
    var distinctDescription: String {
        var parts: [String] = []

        // Command
        if self.contains(.command) {
            if self.intersection(.deviceRightCommand) == .deviceRightCommand {
                parts.append("right_command")
            } else {
                parts.append("left_command")
            }
        }

        // Shift
        if self.contains(.shift) {
            if self.intersection(.deviceRightShift) == .deviceRightShift {
                parts.append("right_shift")
            } else {
                parts.append("left_shift")
            }
        }

        // Option
        if self.contains(.option) {
            if self.intersection(.deviceRightOption) == .deviceRightOption {
                parts.append("right_option")
            } else {
                parts.append("left_option")
            }
        }

        // Control
        if self.contains(.control) {
            if self.intersection(.deviceRightControl) == .deviceRightControl {
                parts.append("right_control")
            } else {
                parts.append("left_control")
            }
        }

        return parts.joined(separator: "+")
    }
}

/// 유틸리티: 마우스 커서 제어
class MouseUtils {

    /// 지정된 윈도우 프레임 내부에 마우스가 있다면, 윈도우 밖으로 이동시킵니다.
    /// - Parameters:
    ///   - windowFrame: 윈도우의 화면상 프레임 (NSRect)
    ///   - margin: 윈도우 경계로부터의 여백 (기본값: 10)
    static func ensureMouseOutside(of windowFrame: NSRect, margin: CGFloat = 10.0) {
        // 현재 마우스 위치 가져오기 (스크린 좌표계: 좌하단 원점)
        let mouseLocation = NSEvent.mouseLocation

        // 마우스가 windowFrame 내부에 있는지 확인
        if NSMouseInRect(mouseLocation, windowFrame, false) {
            logI("🖱️ [MouseUtils] Mouse check: Inside window frame \(windowFrame). Moving cursor...")

            // 현재 스크린 찾기
            var targetScreen: NSScreen? = nil
            for screen in NSScreen.screens {
                if NSMouseInRect(mouseLocation, screen.frame, false) {
                    targetScreen = screen
                    break
                }
            }
            // 스크린을 못 찾으면 메인 스크린 기준
            let screenFrame =
                targetScreen?.frame ?? NSScreen.main?.frame
                ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

            // 이동할 목표 위치 계산 (기본전략: 우측 -> 좌측 -> 하단)
            var newX = windowFrame.maxX + margin
            var newY = mouseLocation.y

            // 우측 공간 부족 시 좌측으로
            if newX > screenFrame.maxX {
                newX = windowFrame.minX - margin
            }

            // 좌측도 부족하면 현재 X 유지하고 Y 조정 (아래로)
            if newX < screenFrame.minX {
                newX = mouseLocation.x
                newY = windowFrame.minY - margin
            }

            // Y도 화면 아래로 벗어나면 위로
            if newY < screenFrame.minY {
                newY = windowFrame.maxY + margin
            }

            // Quartz 좌표계(좌상단 원점)로 변환
            // 메인 스크린 높이가 기준임
            let globalHeight = NSScreen.screens.first?.frame.height ?? 1080
            let quartzY = globalHeight - newY

            let targetPoint = CGPoint(x: newX, y: quartzY)

            logI(
                "🖱️ [MouseUtils] Warping mouse to: \(targetPoint) (Screen: \(screenFrame), Win: \(windowFrame))"
            )

            // 마우스 이동 실행
            let error = CGWarpMouseCursorPosition(targetPoint)
            if error != .success {
                logW("🖱️ ⚠️ [MouseUtils] Failed to warp mouse cursor: \(error.rawValue)")
            }
        }
    }
}
