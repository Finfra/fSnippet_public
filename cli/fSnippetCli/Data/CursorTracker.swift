import Foundation
import ApplicationServices
import Cocoa

/// NSAccessibility API를 사용하여 시스템 전체에서 텍스트 커서 위치를 추적하는 클래스
class CursorTracker {

    // MARK: - 싱글톤

    static let shared = CursorTracker()

    /// CursorTracker가 현재 키 이벤트를 전송 중인지 나타내는 플래그
    /// KeyEventProcessor에서 이를 감지하여 자가 생성 키 이벤트를 무시함
    private(set) var isMovingCursor = false

    // MARK: - Caching Properties
    
    /// 마지막으로 성공한 커서 위치 (캐싱)
    private var cachedCursorRect: CGRect?
    
    /// 마지막 커서 위치 업데이트 시간
    private var lastCursorUpdateTime: Date?
    
    /// 커서 위치 캐시 유효 시간 (초) - 100ms
    private let cacheTTL: TimeInterval = 0.1
    
    private init() {
        logV("📍 CursorTracker 초기화됨")
    }
    
    // MARK: - 공개 메서드
    
    /// 접근성 권한이 활성화되어 있는지 확인
    /// - Returns: 접근성 권한 여부
    func isAccessibilityEnabled() -> Bool {
        // prompt: false — 앱 시작 시 1회만 다이얼로그 표시 (fSnippetCliApp에서 처리)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let result = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        logV("📍 접근성 권한 확인: \(result)")
        
        if !result {
             logE("📍 ⚠️ [CursorTracker] 접근성 권한이 없습니다. 시스템 팝업이 뜨면 허용해주세요.")
        }
        
        return result
    }
    
    /// 현재 텍스트 커서의 화면 좌표를 반환
    /// - Parameter forceUpdate: 캐시를 무시하고 강제로 업데이트할지 여부
    /// - Returns: 커서의 CGPoint 좌표 (실패 시 nil)
    func getCurrentCursorPosition(forceUpdate: Bool = false) -> CGPoint? {
        guard let cursorRect = getCursorRect(forceUpdate: forceUpdate) else {
            logW("📍 커서 위치 획득 실패 - getCursorRect() 반환값 없음")
            return nil
        }
        
        let position = CGPoint(x: cursorRect.origin.x, y: cursorRect.origin.y)
        logTrace("📍 커서 위치: \(position)")
        return position
    }
    
    /// 캐시를 무효화하여 다음 요청 시 강제로 위치를 다시 가져오도록 함
    func invalidateCache() {
        cachedCursorRect = nil
        lastCursorUpdateTime = nil
        logTrace("📍 CursorTracker 캐시 무효화됨")
    }
    
    /// 현재 텍스트 커서의 화면 영역을 반환
    /// - Parameter forceUpdate: 캐시를 무시하고 강제로 업데이트할지 여부
    /// - Returns: 커서 영역의 CGRect (실패 시 nil)
    func getCursorRect(forceUpdate: Bool = false) -> CGRect? {
        // 1. 캐시 유효성 검사
        if !forceUpdate, let cached = cachedCursorRect, let lastUpdate = lastCursorUpdateTime {
            let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
            if timeSinceLastUpdate < cacheTTL {
                logTrace("📍 [CursorTracker] 캐시된 커서 위치 반환 (Age: \(String(format: "%.3f", timeSinceLastUpdate))s)")
                return cached
            }
        }
        
        // 2. 접근성 권한 확인
        guard isAccessibilityEnabled() else {
            logW("📍 ⚠️ 접근성 권한이 없음 - 커서 위치 추적 불가")
            return nil
        }
        
        // 시스템 전체 접근 요소 생성
        let systemWideElement = AXUIElementCreateSystemWide()
        
        // 현재 포커스된 요소 획득
        guard let focusedElement = getFocusedElement(from: systemWideElement) else {
            logW("📍 포커스된 요소를 찾을 수 없음 (SystemWideElement에서)")
            return nil
        }
        
        // [Issue379] 포커스된 요소 소유자 검증
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
             var pid: pid_t = 0
             let pidResult = AXUIElementGetPid(focusedElement, &pid)
             if pidResult == .success {
                 if pid != frontmostApp.processIdentifier {
                     logW("📍 ⚠️ [CursorTracker] 포커스 요소 PID(\(pid))와 Frontmost App PID(\(frontmostApp.processIdentifier)) 불일치 - Ignore")
                     return nil
                 }
             } else {
                 logW("📍 ⚠️ [CursorTracker] 포커스 요소 PID 획득 실패: \(pidResult.rawValue)")
             }
        }

        
        // 포커스된 앱 정보 로깅 (디버깅용) - Issue181: logD로 변경하여 확인
        logFocusedAppInfo(focusedElement)
        
        // 실제 커서 위치 획득 로직
        var finalRect: CGRect?
        
        // 1. 표준: AXSelectedTextRange
        if let selectedRangeValue = getSelectedTextRange(from: focusedElement),
           let rawCursorRect = getBoundsForRange(from: focusedElement, rangeValue: selectedRangeValue) {
            
            // Issue181: (0,0,0,0)과 같은 유효하지 않은 Rect 필터링
            // Fix: Electron 앱(Obsidian 등)은 좌표는 유효하지만 크기가 0인 Rect를 반환할 수 있음.
            // 따라서 width/height가 0이어도 origin이 (0,0)이 아니면 유효한 것으로 간주함.
            var effectiveRect = rawCursorRect
            
            if effectiveRect.width <= 0 && effectiveRect.height <= 0 {
                if effectiveRect.origin == .zero {
                    logD("📍 [CursorTracker] 유효하지 않은 커서 크기 및 위치 감지: \(rawCursorRect) - Fallback 시도")
                    // 다음 메서드로 대체
                } else {
                    logD("📍 [CursorTracker] 크기가 0이지만 유효한 좌표 감지: \(rawCursorRect) - 기본 크기(1x15) 적용")
                    effectiveRect.size = CGSize(width: 1, height: 15) // 기본 커서 크기 부여
                    
                    let convertedRect = convertToScreenCoordinates(effectiveRect)
                    
                    // [Issue379] 화면 교차 검증 (0 크기 우회 수정)
                    if isRectVisibleOnAnyScreen(convertedRect) {
                        finalRect = convertedRect
                    } else {
                         logW("📍 ⚠️ [CursorTracker] (0-size) 커서 좌표가 화면 밖임: \(convertedRect) - Fallback")
                         // Fallback to nil, will try next method or return nil
                    }
                }
            } else {
                let convertedRect = convertToScreenCoordinates(effectiveRect)
                
                // [Issue379] 화면 교차 검증
                if isRectVisibleOnAnyScreen(convertedRect) {
                    finalRect = convertedRect
                } else {
                     logW("📍 ⚠️ [CursorTracker] 커서 좌표가 화면 밖임: \(convertedRect) - Fallback")
                     // Fallback to nil
                }
            }
        }

        
        // 2. 대체: AXSelectedTextMarkerRange (VS Code, Discord, Copilot 같은 WebKit/Electron 앱용)
        if finalRect == nil {
            // AXTextMarkerRange는 표준 헤더에 상수로 공식 노출되지 않으므로 문자열 리터럴을 사용함.
            logD("📍 [CursorTracker] Standard Range failed, trying TextMarkerRange fallback...")
            if let rawCursorRect = getBoundsForTextMarkerRange(from: focusedElement) {
                logV("📍 TextMarkerRange로 커서 위치 획득 성공")
                let convertedRect = convertToScreenCoordinates(rawCursorRect)
                
                // [Issue379] 화면 교차 검증
                if isRectVisibleOnAnyScreen(convertedRect) {
                    finalRect = convertedRect
                } else {
                     logW("📍 ⚠️ [CursorTracker] TextMarkerRange 커서 좌표가 화면 밖임: \(convertedRect) - Fallback")
                }
            }
        }
        
        if let rect = finalRect {
            // 캐시 업데이트
            cachedCursorRect = rect
            lastCursorUpdateTime = Date()
            return rect
        }
        
        logW("📍 모든 방식으로 커서 위치 획득 실패")
        return nil
    }
    
    /// 좌표계 변환: NSAccessibility (좌상단 기준) → NSWindow (좌하단 기준)
    /// - Parameter rawCursorRect: AX API로부터 획득한 원본 좌표 (좌상단 기준)
    /// - Returns: 화면 좌표계로 변환된 좌표 (좌하단 기준)
    /// 좌표계 변환: NSAccessibility (좌상단 기준) → NSWindow (좌하단 기준)
    /// - Parameter rawCursorRect: AX API로부터 획득한 원본 좌표 (좌상단 기준)
    /// - Returns: 화면 좌표계로 변환된 좌표 (좌하단 기준)
    private func convertToScreenCoordinates(_ rawCursorRect: CGRect) -> CGRect {
        // Issue181: _tool/get_cursor.swift의 검증된 로직으로 단순화
        let mainHeight = NSScreen.main?.frame.height ?? 1080
        
        let convertedCursorRect = CGRect(
            x: rawCursorRect.origin.x,
            y: mainHeight - rawCursorRect.origin.y - rawCursorRect.height,
            width: rawCursorRect.width,
            height: rawCursorRect.height
        )
        
        logTrace("📍 좌표 변환 (Simple): Raw(\(rawCursorRect)) -> Converted(\(convertedCursorRect)) [MainHeight: \(mainHeight)]")
        
        return convertedCursorRect
    }
    
    // MARK: - 포커스 요소
    
    /// 현재 포커스된 UI 요소를 가져옵니다.
    func getFocusedElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        if result == .success, let element = focusedElement {
            if CFGetTypeID(element) == AXUIElementGetTypeID() {
                return (element as! AXUIElement)
            } else {
                logTrace("📍 [CursorTracker] Focused element is not an AXUIElement")
                return nil
            }
        } else {
            // 포커스 요소를 찾을 수 없는 경우 (권한 문제 등)
            if result == .apiDisabled {
                logTrace("📍 포커스된 요소를 찾을 수 없음 - API Disabled (접근성 권한 확인 필요)")
            } else if result == .noValue {
                logTrace("📍 포커스된 요소를 찾을 수 없음")
            } else {
                logTrace("📍 포커스된 요소를 가져오는데 실패함: \(result.rawValue)")
            }
            return nil
        }
    }
    
    /// 선택된 텍스트 범위의 화면 좌표(CGRect)를 가져옵니다.
    func getSelectedTextRect() -> CGRect? {
        guard let focusedElement = getFocusedElement() else { return nil }
        
        // 1. 선택된 텍스트 범위(CFRange) 가져오기
        var selectedRangeValue: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue)
        
        guard rangeResult == .success, let selectedRange = selectedRangeValue else {
            logTrace("📍 선택된 텍스트 범위를 찾을 수 없음")
            return nil
        }
        
        // 2. 해당 범위의 화면 좌표(Direct bounds) 가져오기
        var boundsValue: AnyObject?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(focusedElement, kAXBoundsForRangeParameterizedAttribute as CFString, selectedRange, &boundsValue)
        
        if boundsResult == .success, let bounds = boundsValue {
            var rect = CGRect.zero
            if CFGetTypeID(bounds) == AXValueGetTypeID() {
                let boundsAXValue = bounds as! AXValue
                AXValueGetValue(boundsAXValue, .cgRect, &rect)
                return rect
            } else {
                logTrace("📍 [CursorTracker] bounds 값이 AXValue가 아닙니다.")
                return nil
            }
        } else {
            logTrace("📍 텍스트 범위의 화면 좌표를 찾을 수 없음")
            return nil
        }
    }

    /// getBoundsForTextMarkerRange (비공개)
    /// Electron/WebKit 등에서 사용하는 AXSelectedTextMarkerRange를 통해 커서 좌표를 얻습니다.
    private func getBoundsForTextMarkerRange(from element: AXUIElement) -> CGRect? {
        // 1. 선택된 마커 범위(MarkerRange) 가져오기
        var markerRangeValue: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(element, "AXSelectedTextMarkerRange" as CFString, &markerRangeValue)
        
        guard rangeResult == .success, let markerRange = markerRangeValue else {
            logTrace("📍 AXSelectedTextMarkerRange 미지원 또는 값 없음 (Result: \(rangeResult.rawValue))")
            return nil
        }
        
        // 2. 해당 마커 범위의 화면 좌표 가져오기
        var boundsValue: AnyObject?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(element, "AXBoundsForTextMarkerRange" as CFString, markerRange, &boundsValue)
        
        if boundsResult == .success, let bounds = boundsValue {
            var rect = CGRect.zero
            if CFGetTypeID(bounds) == AXValueGetTypeID() {
                let boundsAXValue = bounds as! AXValue
                AXValueGetValue(boundsAXValue, .cgRect, &rect)
                return rect
            } else {
                logTrace("📍 [CursorTracker] TextMarkerRange bounds 값이 AXValue가 아닙니다.")
                return nil
            }
        } else {
            logTrace("📍 AXBoundsForTextMarkerRange 좌표 획득 실패 (Result: \(boundsResult.rawValue))")
            return nil
        }
    }
    
    // MARK: - 안전한 화면 좌표 변환
    
    /// 커서 위치가 어떤 화면에 속하는지 확인하고 해당 화면 기준으로 좌표를 조정할 필요가 있는지 판단합니다.
    /// macOS의 AX API는 이미 글로벌 좌표계(메인 스크린 좌하단 0,0 기준이 아님, 좌상단 기준)를 사용할 수 있으므로,
    /// 여기서는 디버깅 정보를 제공하고 필요한 경우 보정합니다.
    private func getScreenForCursor(_ cursorRect: CGRect) -> NSScreen? {
        // 커서 중심점 계산
        let centerPoint = NSPoint(x: cursorRect.midX, y: cursorRect.midY)
        
        // 해당 점을 포함하는 스크린 찾기
        for screen in NSScreen.screens {
            if NSMouseInRect(centerPoint, screen.frame, false) {
                return screen
            }
        }
        return NSScreen.main
    }
    
    private func logCursorInfo(_ rawCursorRect: CGRect, _ convertedCursorRect: CGRect, _ targetScreen: NSScreen?) {
        guard let screenFrame = targetScreen?.frame else { return }
        logTrace("📍 멀티 디스플레이 커서 위치 변환:")
        logTrace("📍    - 감지된 화면: \(targetScreen?.localizedName ?? "Unknown") (\(screenFrame))")
        logTrace("📍    - 원본 커서 (NSAccessibility): \(rawCursorRect)")
        logTrace("📍    - 변환된 커서 (NSWindow): \(convertedCursorRect)")
    }
    
    // [Issue379] rect가 보이는지 확인하는 헬퍼
    private func isRectVisibleOnAnyScreen(_ rect: CGRect) -> Bool {
        // 커서의 중심점이나 일부가 화면 내에 있는지 확인
        // 엄격하게는 전체가 들어와야 하지만, 경계에 걸친 경우도 허용
        for screen in NSScreen.screens {
            if screen.frame.intersects(rect) {
                return true
            }
        }
        return false
    }
    
    // MARK: - 비공개 메서드
    
    /// 포커스된 앱 정보 로깅 (디버깅용)
    /// - Parameter focusedElement: 포커스된 AXUIElement
    private func logFocusedAppInfo(_ focusedElement: AXUIElement) {
        // 앱 이름 가져오기
        var appNameValue: AnyObject?
        let appNameError = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXTitleAttribute as CFString,
            &appNameValue
        )
        let appName = (appNameError == .success && appNameValue != nil) ? 
            (appNameValue as? String ?? "알 수 없음") : "알 수 없음"
        
        // 역할 가져오기
        var roleValue: AnyObject?
        let roleError = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXRoleAttribute as CFString,
            &roleValue
        )
        let role = (roleError == .success && roleValue != nil) ? 
            (roleValue as? String ?? "알 수 없음") : "알 수 없음"
        
        logD("📍 [CursorTracker] 포커스된 요소 정보: 앱='\(appName)', 역할='\(role)'")
    }
    
    /// 시스템에서 현재 포커스된 UI 요소를 획득 (재시도 로직 포함)
    /// - Parameter systemElement: 시스템 전체 접근 요소
    /// - Returns: 포커스된 AXUIElement (실패 시 nil)
    private func getFocusedElement(from systemElement: AXUIElement) -> AXUIElement? {
        var focusedElement: AnyObject?
        var error: AXError = .success
        
        // Issue181: -25204 (kAXErrorCannotComplete) 대응을 위한 재시도 로직
        // 시스템 부하가 있거나 포커스 전환 중일 때 일시적으로 실패할 수 있음
        let maxRetries = 3
        
        for i in 0..<maxRetries {
            error = AXUIElementCopyAttributeValue(
                systemElement,
                kAXFocusedUIElementAttribute as CFString,
                &focusedElement
            )
            
            if error == .success, let element = focusedElement {
                if i > 0 {
                    logD("📍 [CursorTracker] 포커스된 요소 획득 성공 (재시도 \(i+1)회차)")
                }
                
                if CFGetTypeID(element) == AXUIElementGetTypeID() {
                    return (element as! AXUIElement)
                } else {
                    return nil
                }
            }
            
            // 실패 시 잠시 대기
            if error == .cannotComplete {
                logD("📍 [CursorTracker] 포커스 요소 획득 일시 실패(-25204), 재시도 중... (\(i+1)/\(maxRetries))")
                Thread.sleep(forTimeInterval: 0.02) // 20ms 대기
            } else {
                // 다른 에러면 즉시 중단
                break
            }
        }
        
        // 최종 실패 로그
        logD("📍 [CursorTracker] 포커스된 요소 획득 최종 실패: \(error.rawValue)")
        return nil
    }
    
    /// 포커스된 요소에서 선택된 텍스트 범위를 획득
    /// - Parameter element: 포커스된 AXUIElement
    /// - Returns: 선택된 텍스트 범위 AXValue (실패 시 nil)
    private func getSelectedTextRange(from element: AXUIElement) -> AXValue? {
        var selectedRangeValue: AnyObject?
        
        let error = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeValue
        )
        
        guard error == .success, let rangeValue = selectedRangeValue else {
            logD("📍 [CursorTracker] 선택된 텍스트 범위 획득 실패: \(error.rawValue)")
            return nil
        }
        
        // 선택된 범위 정보 로깅 (디버깅용)
        var selectedRange = CFRange()
        if CFGetTypeID(rangeValue) == AXValueGetTypeID() {
            let rangeAXValue = rangeValue as! AXValue
            if AXValueGetValue(rangeAXValue, AXValueType(rawValue: kAXValueCFRangeType)!, &selectedRange) {
                logV("📍 선택된 텍스트 범위: location=\(selectedRange.location), length=\(selectedRange.length)")
            }
            return rangeAXValue
        }
        
        return nil
    }
    
    /// 텍스트 범위에 대한 화면 좌표를 획득
    /// - Parameters:
    ///   - element: 포커스된 AXUIElement
    ///   - rangeValue: 선택된 텍스트 범위 AXValue
    /// - Returns: 텍스트 범위의 CGRect (실패 시 nil)
    private func getBoundsForRange(from element: AXUIElement, rangeValue: AXValue) -> CGRect? {
        var boundsValue: AnyObject?
        
        let error = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsValue
        )
        
        guard error == .success, let bounds = boundsValue else {
            logV("📍 텍스트 범위 좌표 획득 실패: \(error.rawValue)")
            return nil
        }
        
        var cursorRect = CGRect()
        
        guard CFGetTypeID(bounds) == AXValueGetTypeID() else {
             logV("📍 [CursorTracker] bounds 값이 AXValue가 아님")
             return nil
        }
        
        let boundsAXValue = bounds as! AXValue
        guard AXValueGetValue(boundsAXValue, .cgRect, &cursorRect) else {
            logV("📍 CGRect 변환 실패")
            return nil
        }
        
        return cursorRect
    }
    
    // MARK: - 커서 이동
    
    /// 커서를 지정된 문자 개수만큼 이동 (좌측으로 이동은 음수)
    /// - Parameter offset: 이동할 문자 개수 (양수: 우측, 음수: 좌측)
    /// - Returns: 성공 여부
    func moveCursorByCharacters(_ offset: Int) -> Bool {
        guard offset != 0 else {
            logV("📍 커서 이동 offset이 0 - 이동하지 않음")
            return true
        }

        logV("📍 커서 이동 시작: \(offset)자")
        
        // 캐시 무효화 (커서가 이동하므로)
        invalidateCache()

        // ✅ 무한 루프 방지: 커서 이동 플래그 설정
        isMovingCursor = true
        defer {
            // 키 이벤트가 처리될 시간을 보장하기 위해 약간의 지연 후 플래그 해제
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.isMovingCursor = false
                logV("📍 커서 이동 플래그 해제됨 (지연)")
            }
        }

        let isLeftMovement = offset < 0
        let moveCount = abs(offset)
        let keyCode: CGKeyCode = isLeftMovement ? 123 : 124  // Left: 123, Right: 124

        var success = true

        for i in 0..<moveCount {
            if !sendArrowKey(keyCode: keyCode) {
                logE("📍 커서 이동 실패 at step \(i+1)/\(moveCount)")
                success = false
                break
            }

            // 각 키 사이에 짧은 딜레이
            Thread.sleep(forTimeInterval: 0.01)
        }

        if success {
            logV("📍 커서 이동 완료: \(offset)자")
        } else {
            logE("📍 커서 이동 중 오류 발생")
        }

        return success
    }
    
    /// 화살표 키 이벤트를 전송
    /// - Parameter keyCode: 키코드 (123: Left, 124: Right, 125: Down, 126: Up)
    /// - Returns: 성공 여부
    private func sendArrowKey(keyCode: CGKeyCode) -> Bool {
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            logE("📍 화살표 키 이벤트 생성 실패")
            return false
        }
        
        // Key down
        keyDownEvent.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.005)
        
        // Key up
        keyUpEvent.post(tap: .cghidEventTap)
        
        return true
    }
}

// MARK: - 더 나은 에러 처리를 위한 확장

extension AXError: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .success:
            return "success"
        case .failure:
            return "failure"
        case .illegalArgument:
            return "illegalArgument"
        case .invalidUIElement:
            return "invalidUIElement"
        case .invalidUIElementObserver:
            return "invalidUIElementObserver"
        case .cannotComplete:
            return "cannotComplete"
        case .attributeUnsupported:
            return "attributeUnsupported"
        case .actionUnsupported:
            return "actionUnsupported"
        case .notificationUnsupported:
            return "notificationUnsupported"
        case .notImplemented:
            return "notImplemented"
        case .notificationAlreadyRegistered:
            return "notificationAlreadyRegistered"
        case .notificationNotRegistered:
            return "notificationNotRegistered"
        case .apiDisabled:
            return "apiDisabled"
        case .noValue:
            return "noValue"
        case .parameterizedAttributeUnsupported:
            return "parameterizedAttributeUnsupported"
        case .notEnoughPrecision:
            return "notEnoughPrecision"
        @unknown default:
            return "unknown(\(self.rawValue))"
        }
    }
}
