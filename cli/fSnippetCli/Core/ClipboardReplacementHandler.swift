import ApplicationServices
import Cocoa
import Foundation

/// 클립보드 기반 텍스트 삭제/삽입/복원 담당 (Issue793: TextReplacer에서 분리)
class ClipboardReplacementHandler {

    private let pasteboard = NSPasteboard.general
    private let eventPool: CGEventPool

    init(eventPool: CGEventPool) {
        self.eventPool = eventPool
    }

    // MARK: - Public API

    /// 동기식 텍스트 대체 (삭제 → 삽입 → 커서 이동)
    func performSyncTextReplacement(
        deleteCount: Int, insertText: String, snippetPath: String? = nil,
        replaceDynamicPlaceholders: (String, String?) -> String,
        processClipboardMarker: (String) -> String,
        processCursorMarker: (String) throws -> (cleanedText: String, cursorOffset: Int),
        showErrorAlert: @escaping (Error, TimeInterval?) -> Void
    ) -> Bool {
        return autoreleasepool {
            // 1. 문자 삭제
            if deleteCount > 0 {
                if !deleteCharactersSync(count: deleteCount) {
                    return false
                }
                usleep(50000)  // 50ms 대기
            }

            // 2. 동적 플레이스홀더 치환
            let dynamicProcessedText = replaceDynamicPlaceholders(insertText, snippetPath)

            // 3. @clipboard 마커 처리
            let clipboardProcessedText = processClipboardMarker(dynamicProcessedText)

            // 4. @cursor 마커 처리
            let cleanedText: String
            let cursorOffset: Int

            do {
                (cleanedText, cursorOffset) = try processCursorMarker(clipboardProcessedText)
            } catch {
                logW("🖊️ [ClipboardReplacementHandler] @cursor 검증 실패: \(error.localizedDescription)")
                cleanedText = clipboardProcessedText.replacingOccurrences(of: "@cursor", with: "")
                cursorOffset = 0
                DispatchQueue.main.async {
                    showErrorAlert(error, 2.0)
                }
            }

            // 5. 텍스트 삽입
            if !insertTextSync(cleanedText) {
                return false
            }

            // 6. 커서 이동
            if cursorOffset != 0 {
                moveCursorAfterInsertion(offset: cursorOffset)
            }

            // Issue798: @cursor 거리 제한 초과 알림은 processCursorMarker에서
            // asyncAfter(deadline: .now() + 1.0)로 지연 표시됨

            return true
        }
    }

    // MARK: - 문자 삭제

    /// 동기식 문자 삭제 (CGEvent)
    func deleteCharactersSync(count: Int) -> Bool {
        logV("🖊️ [백스페이스] \(count)자 삭제 시작")

        for i in 0..<count {
            logV("🖊️ [백스페이스] \(i+1)/\(count) 삭제 중...")

            let stepSuccess = autoreleasepool { () -> Bool in
                return sendBackspaceKey()
            }

            if !stepSuccess {
                logE("🖊️ [백스페이스] \(i+1)번째 백스페이스 전송 실패")
                return false
            } else {
                logV("🖊️ [백스페이스] \(i+1)번째 백스페이스 전송 성공")
            }

            usleep(8000)
        }

        logV("🖊️ [백스페이스] \(count)자 삭제 완료")
        return true
    }

    /// 단일 백스페이스 키 전송
    private func sendBackspaceKey() -> Bool {
        logV("🖊️ [백스페이스키] 풀에서 CGEvent 획득 시작 (keyCode: 51)")

        guard let keyDownEvent = eventPool.getBackspaceEvent(keyDown: true),
            let keyUpEvent = eventPool.getBackspaceEvent(keyDown: false)
        else {
            logE("🖊️ [백스페이스키] CGEvent 풀에서 획득 실패")
            return false
        }

        logV("🖊️ [백스페이스키] CGEvent 풀에서 획득 성공, 키 전송 시작")

        keyDownEvent.post(tap: .cgSessionEventTap)
        usleep(5000)
        logV("🖊️ [백스페이스키] KeyDown 전송 완료")

        keyUpEvent.post(tap: .cgSessionEventTap)
        usleep(5000)
        logV("🖊️ [백스페이스키] KeyUp 전송 완료")

        eventPool.returnBackspaceEvent(keyDownEvent)
        eventPool.returnBackspaceEvent(keyUpEvent)

        return true
    }

    // MARK: - 텍스트 삽입 (클립보드 방식)

    /// 동기식 텍스트 삽입 — 클립보드 백업/복원 포함
    func insertTextSync(_ text: String) -> Bool {
        logV("🖊️ [ClipboardReplacementHandler] 텍스트 삽입 시작: '\(text.prefix(50))...'")

        return autoreleasepool {
            // 1. 클립보드 백업
            let originalContent = pasteboard.string(forType: .string).map { String($0) }
            let backupContent = originalContent
            logV("🖊️ [ClipboardReplacementHandler] 원본 클립보드 백업: '\((originalContent ?? "nil").prefix(30))...'")

            // 2. 클립보드에 텍스트 설정
            pasteboard.clearContents()
            guard pasteboard.setString(text, forType: .string) else {
                logE("🖊️ [ClipboardReplacementHandler] 클립보드에 텍스트 설정 실패")
                _ = self.restoreClipboard(backupContent)
                return false
            }

            logV("🖊️ [ClipboardReplacementHandler] 클립보드 설정 완료: '\(text.prefix(30))...'")

            // 3. Cmd+V 실행
            let pasteSuccess = sendCmdVSync()

            if !pasteSuccess {
                logE("🖊️ [ClipboardReplacementHandler] Cmd+V 실행 실패")
                _ = self.restoreClipboard(backupContent)
                return false
            }

            logV("🖊️ [ClipboardReplacementHandler] Cmd+V 실행 성공")

            // 4. 붙여넣기 완료 대기
            let adaptiveWaitTime = calculateOptimalWaitTime(for: text)
            logV("🖊️ [ClipboardReplacementHandler] 붙여넣기 완료 대기: \(adaptiveWaitTime)ms")
            usleep(useconds_t(adaptiveWaitTime * 1000))

            // 5. 클립보드 복원
            let restoreSuccess = restoreClipboard(backupContent)
            if !restoreSuccess {
                logW("🖊️ [ClipboardReplacementHandler] 클립보드 복원 실패")
            }

            return true
        }
    }

    // MARK: - Cmd+V 실행

    /// 동기식 Cmd+V 실행 (메모리 최적화)
    func sendCmdVSync() -> Bool {
        logV("🖊️ [Cmd+V] 풀에서 키 조합 이벤트 획득 시작")

        guard let cmdDownEvent = eventPool.getCmdEvent(keyDown: true),
            let vDownEvent = eventPool.getVEvent(keyDown: true),
            let vUpEvent = eventPool.getVEvent(keyDown: false),
            let cmdUpEvent = eventPool.getCmdEvent(keyDown: false)
        else {
            logE("🖊️ [Cmd+V] CGEvent 풀에서 획득 실패")
            return false
        }

        logV("🖊️ [Cmd+V] Command Down 전송")
        cmdDownEvent.post(tap: .cgSessionEventTap)
        usleep(8000)

        logV("🖊️ [Cmd+V] V Down (with Cmd flag) 전송")
        vDownEvent.post(tap: .cgSessionEventTap)
        usleep(8000)

        logV("🖊️ [Cmd+V] V Up (with Cmd flag) 전송")
        vUpEvent.post(tap: .cgSessionEventTap)
        usleep(8000)

        logV("🖊️ [Cmd+V] Command Up 전송")
        cmdUpEvent.post(tap: .cgSessionEventTap)
        usleep(8000)

        logV("🖊️ [Cmd+V] 키 조합 전송 완료")

        eventPool.returnCmdEvent(cmdDownEvent)
        eventPool.returnVEvent(vDownEvent)
        eventPool.returnVEvent(vUpEvent)
        eventPool.returnCmdEvent(cmdUpEvent)

        return true
    }

    // MARK: - 클립보드 복원

    /// 안전한 클립보드 복원
    func restoreClipboard(_ originalContent: String?) -> Bool {
        guard let original = originalContent else {
            logV("🖊️ [ClipboardReplacementHandler] 원본 클립보드가 없어 복원하지 않음")
            return true
        }

        pasteboard.clearContents()
        let success = pasteboard.setString(original, forType: .string)

        if success {
            logV("🖊️ [ClipboardReplacementHandler] 클립보드 복원 완료: '\(original.prefix(30))...'")
            return true
        } else {
            logE("🖊️ [ClipboardReplacementHandler] 클립보드 복원 설정 실패")
            return false
        }
    }

    // MARK: - 유틸리티

    /// 텍스트 길이 기반 적응형 대기 시간
    private func calculateOptimalWaitTime(for text: String) -> Double {
        let baseTime: Double = 150.0
        let textLength = text.count
        let additionalTime = min(Double(textLength) / 100.0 * 10.0, 100.0)
        return baseTime + additionalTime
    }

    /// 커서 이동
    private func moveCursorAfterInsertion(offset: Int) {
        guard offset != 0 else { return }
        logV("🖊️ [@cursor] 커서 이동 시작: \(offset)자")
        Thread.sleep(forTimeInterval: 0.1)
        let success = CursorTracker.shared.moveCursorByCharacters(offset)
        if success {
            logV("🖊️ [@cursor] 커서 이동 완료")
        } else {
            logE("🖊️ [@cursor] 커서 이동 실패")
        }
    }

    /// 접근성 권한 확인
    func isAccessibilityPermissionGranted() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
