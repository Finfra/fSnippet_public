import Cocoa
import SwiftUI

class HistoryViewerManager: NSObject, NSWindowDelegate {
    static let shared = HistoryViewerManager()

    private(set) var window: NSWindow?
    private var previousApp: NSRunningApplication?
    private var viewModel: HistoryViewModel?
    private var hostingController: NSHostingController<UnifiedHistoryViewer>?

    // ✅ Issue 346: 내부 클립보드(플레이스홀더 입력)에 대한 콜백
    private var onSelection: ((String) -> Void)?

    // [Issue782] 클립보드 팝업창이 열려있는지 확인
    var isVisible: Bool { window?.isVisible == true }

    // [Issue383] 초기화 및 알림 등록
    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleCloseAuxiliaryWindows(_:)),
            name: .closeAuxiliaryWindows, object: nil)
    }

    // [Issue383] 보조 윈도우 닫기 처리
    @objc private func handleCloseAuxiliaryWindows(_ notification: Notification) {
        if window?.isVisible == true {
            logI("🎞️ [HistoryViewerManager] 설정창 활성화로 인한 히스토리 닫기 (restoreFocus: false)")
            hide(restoreFocus: false)
        }
    }

    // CL048_7: 히스토리 창에 대한 견고한 확인
    func isHistoryWindow(_ window: NSWindow) -> Bool {
        return self.window === window
    }

    func show(cursorRect: CGRect? = nil, onSelection: ((String) -> Void)? = nil) {
        logD("🎞️ [HistoryViewerManager] show() called")

        // 콜백 저장
        self.onSelection = onSelection

        // ✅ CL061: "유령 미리보기" 방지를 위한 상태 강제 재설정
        // 표시하기 전에 비활성 상태를 엄격히 보장 (포커스 시 .list로 업데이트됨)
        ClipboardManager.shared.chvMode = .deactive
        HistoryPreviewManager.shared.hide()

        // 1. 현재 전면 앱 저장 (fSnippet이 아닌 경우에만)
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            if frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
                self.previousApp = frontApp
                logD(
                    "🎞️ [HistoryViewerManager] Stored previous app: \(frontApp.localizedName ?? "Unknown")"
                )
            } else {
                // ✅ Issue 346 수정: fSnippet에 있다면, 이것이 플레이스홀더 입력 창인지 확인.
                // 만약 그렇다면, 자신에게 붙여넣기 할 수 있도록 fSnippet을 "이전 앱"으로 취급함.
                if let keyWindow = NSApp.keyWindow, keyWindow.title == "플레이스홀더 입력" {
                    self.previousApp = frontApp  // fSnippet 자체
                    logI(
                        "🎞️ [HistoryViewerManager] Placeholder Input Window detected. Setting previousApp to self (fSnippet) for self-paste."
                    )
                }
            }
        }

        if window == nil {
            logD("🎞️ [HistoryViewerManager] Creating new window")
            let initialSettings = SettingsManager.shared.load()
            let initialWidth =
                initialSettings.historyViewerWidth
                + (initialSettings.historyShowPreview ? initialSettings.historyPreviewWidth : 0)
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: 420),
                // [CL064] 제목 표시줄 제거하지만 크기 조정 유지
                styleMask: [.titled, .fullSizeContentView, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "Clipboard History"
            win.isReleasedWhenClosed = false
            win.level = .floating
            win.delegate = self

            // XCUITest 식별자 설정
            win.setAccessibilityIdentifier("HistoryWindow")

            // [CL064] 제목 표시줄 세부 정보 숨기기
            win.titleVisibility = .hidden
            win.titlebarAppearsTransparent = true
            win.backgroundColor = .clear
            win.isOpaque = false
            win.isMovableByWindowBackground = true
            win.standardWindowButton(.closeButton)?.isHidden = true
            win.standardWindowButton(.miniaturizeButton)?.isHidden = true
            win.standardWindowButton(.zoomButton)?.isHidden = true
            self.window = win
        }

        guard let win = window else { return }

        // HostingController + ViewModel 캐싱: 첫 호출 시에만 생성, 이후 refresh()로 데이터 갱신
        if viewModel == nil {
            viewModel = HistoryViewModel()
        }
        if hostingController == nil {
            let content = UnifiedHistoryViewer(viewModel: viewModel!)
            hostingController = NSHostingController(rootView: content)
            win.contentViewController = hostingController
        } else {
            viewModel!.refresh()
        }

        // ✅ Issue 543: 통합 너비 계산
        let settings = SettingsManager.shared.load()
        let rows = settings.popupRows
        let showStatusBar = settings.historyShowStatusBar
        let height = PopupUIConstants.calculateHistoryWindowHeight(
            rows: rows + 2, showStatusBar: showStatusBar)
        let totalWidth =
            settings.historyViewerWidth
            + (settings.historyShowPreview ? settings.historyPreviewWidth : 0)

        if win.contentView?.frame.height != height || win.contentView?.frame.width != totalWidth {
            win.setContentSize(NSSize(width: totalWidth, height: height))
        }

        // ✅ CL028 개선: 앱 활성화 **전에** 목표 위치 계산
        // 이는 CursorTracker가 fSnippet이 아닌 원래 앱의 포커스를 보게 함
        let targetPos = calculateTargetPosition(
            for: win, width: totalWidth, height: height, passedCursorRect: cursorRect)

        // [Issue758] 클립보드 팝업 표시 시 설정창 임시 숨김
        SettingsWindowManager.shared.temporarilyHide()

        NSApp.activate(ignoringOtherApps: true)
        // NSApp.activate(ignoringOtherApps: true)

        // 스니펫 팝업 동작 일치: 커서 따라가기
        win.setFrameOrigin(targetPos)

        win.makeKeyAndOrderFront(nil)

        // ✅ Issue616: 팝업이 표시될 때 마우스 커서가 창을 가리면 밖으로 이동
        MouseUtils.ensureMouseOutside(of: win.frame)

        // ✅ CL061: 즉시 상호작용을 보장하기 위해 명시적으로 .list 모드 설정
        // (지연될 수 있는 비동기 windowDidBecomeKey에 의존하지 않음)
        ClipboardManager.shared.chvMode = .list

        // HistoryViewer에 show 이벤트 전달 (이벤트 모니터 등록, 포커스 설정)
        NotificationCenter.default.post(name: .historyViewerDidShow, object: nil)

        logD(
            "🎞️ [HistoryViewerManager] Window made key and front (height: \(height))"
        )
    }

    func hide(restoreFocus: Bool = true) {
        // HistoryViewer에 hide 이벤트 전달 (이벤트 모니터 해제, InputSource 복원)
        NotificationCenter.default.post(name: .historyViewerDidHide, object: nil)

        // ✅ CL038: 숨기고 앱을 전환하기 전에 입력 소스를 명시적으로 복원
        // onDisappear에 의존하는 것은 앱 포커스가 즉시 전환될 경우 너무 늦을 수 있음
        InputSourceManager.shared.restoreInputSource()

        window?.orderOut(nil)

        // [Issue758] 클립보드 팝업 닫힘 시 설정창 복원
        SettingsWindowManager.shared.restoreFromTemporaryHide()

        // 미리보기 창 숨기기
        HistoryPreviewManager.shared.hide()

        // ✅ Issue 수정: 포커스 복원 로직 (취소/Esc 지원)
        if restoreFocus {
            logD("🎞️ [HistoryViewerManager] hide(restoreFocus: true) - Attempting to restore focus")
            if let app = previousApp {
                logD("🎞️     - Activating stored previous app: \(app.localizedName ?? "Unknown")")
                if #available(macOS 14.0, *) {
                    app.activate(options: [])
                } else {
                    app.activate(options: .activateIgnoringOtherApps)
                }
                // 여기서 previousApp을 지우지 않음. 다른 용도로 필요할 수 있음?
                // 보통 Cancel의 경우 괜찮음. Paste의 경우 hide(refreshFocus: false)가 호출됨.
                previousApp = nil
            } else {
                logD("🎞️     - No stored previous app, using NSApp.hide(nil)")
                NSApp.hide(nil)
            }
        }
    }

    // var ignoreResignKey: Bool = false // 제거됨: 포커스 유지 패턴

    // MARK: - NSWindowDelegate
    func windowDidResignKey(_ notification: Notification) {
        // if ignoreResignKey { ... } // 제거됨

        // CL054: 포커스가 어디로 갔는지 확인하는 비동기 체크
        DispatchQueue.main.async {
            // 포커스가 미리보기 창으로 이동했는지 확인
            // 통합 윈도우 아키텍처에서는 프리뷰가 같은 윈도우 내에 있으므로 별도 윈도우 체크 불필요

            // ✅ 개선: 포커스 유지 - 포커스가 에디터 창으로 이동했는지 확인
            if let keyWindow = NSApp.keyWindow,
                SnippetEditorWindowManager.shared.isEditorWindow(keyWindow)
            {
                logD(
                    "🎞️ [HistoryViewerManager] Focus moved to Editor Window. Maintaining state (Focus Retention)."
                )
                return
            }

            // 외부로 포커스 잃음 -> 비활성 + 숨기기
            ClipboardManager.shared.chvMode = .deactive
            logD(
                "🎞️ [HistoryViewerManager] Window resigned key -> chvMode set to .deactive & Hiding")

            // ✅ 수정: 이미 포커스를 잃었다면 복원을 시도하지 않음 (루프/중복 방지)
            self.hide(restoreFocus: false)
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        // CL054: 포커스 시 리스트 뷰로 복구
        ClipboardManager.shared.chvMode = .list
        logD("🎞️ [HistoryViewerManager] Window became key -> chvMode reset to .list")
    }

    // MARK: - NSWindowDelegate (CL062)
    func windowDidMove(_ notification: Notification) {
        // ✅ CL062: 미리보기 창 위치 동기화
        // 통합 윈도우에서는 위치 동기화가 불필요함
    }

    /// 창을 닫고, 이전 앱으로 포커스를 돌린 후 붙여넣기 수행
    func hideAndPaste() {
        logD("🎞️ [HistoryViewerManager] hideAndPaste() called")

        // ✅ Issue 346: 콜백 모드 (예: 플레이스홀더 입력)
        // 콜백이 등록되어 있으면 이전 앱에 붙여넣는 대신 텍스트를 반환함.
        if let callback = self.onSelection {
            logI(
                "🎞️ [HistoryViewerManager] Callback registered. Invoking callback instead of auto-paste."
            )

            // 텍스트는 이미 클립보드에 있음 (HistoryViewer.confirmSelection에 의해)
            // 그냥 다시 읽어옴.
            if let str = NSPasteboard.general.string(forType: .string) {
                callback(str)
            } else {
                logW("🎞️ 📋 [HistoryViewerManager] Clipboard content is empty or not string.")
                callback("")
            }

            // 콜백 초기화
            self.onSelection = nil

            // 그냥 숨김, 아직 포커스 복원 안 함 (호출자 창이 포커스 처리)
            hide(restoreFocus: false)
            return
        }

        // ✅ 수정: hide()는 포커스를 복원하면 안 됨. 아래에서 수동으로 처리하기 때문.
        hide(restoreFocus: false)

        guard let app = previousApp else {
            logW("🎞️ 📋 [HistoryViewerManager] No previous app stored to restore focus")
            return
        }

        logI("🎞️ [HistoryViewerManager] Restoring focus to: \(app.localizedName ?? "Unknown")")

        // 1. 이전 앱 활성화
        if #available(macOS 14.0, *) {
            app.activate(options: [])
        } else {
            app.activate(options: .activateIgnoringOtherApps)
        }

        // 2. 포커스 전환 대기 후 붙여넣기 (Command+V)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            logI("🎞️ [HistoryViewerManager] Triggering auto-paste (Cmd+V)")
            _ = TextReplacer.shared.sendCmdVSync()
            self.previousApp = nil  // 사용 후 초기화
        }
    }
    private func calculateTargetPosition(
        for window: NSWindow, width: CGFloat, height: CGFloat, passedCursorRect: CGRect? = nil
    ) -> NSPoint {
        // 내용 크기로부터 전체 프레임 크기(제목 표시줄 포함) 계산
        let contentRect = NSRect(x: 0, y: 0, width: width, height: height)
        let frameRect = window.frameRect(forContentRect: contentRect)

        let popupWidth = frameRect.width
        let popupHeight = frameRect.height

        // 1. CursorTracker(선호) 또는 마우스 위치(폴백)에서 커서 사각형 가져오기
        // ✅ Issue 288: 사용 가능한 경우 전달된 cursorRect 사용 (핫키 시점에 미리 캡처됨)
        let cursorRect: CGRect? = passedCursorRect ?? CursorTracker.shared.getCursorRect()
        let targetPoint: NSPoint

        if let rect = cursorRect {
            // 커서 사각형 발견
            let cursorPoint = NSPoint(x: rect.midX, y: rect.midY)

            // 커서를 포함하는 화면 찾기
            var targetScreen: NSScreen? = nil
            for screen in NSScreen.screens {
                if screen.frame.contains(cursorPoint) {
                    targetScreen = screen
                    break
                }
            }
            let screenFrame =
                targetScreen?.frame ?? NSScreen.main?.frame
                ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

            // 위치 지정 로직
            let textMargin: CGFloat = 45  // 사용자 요청에 따라 25에서 45로 증가
            var popupX = rect.origin.x

            // 윈도우 상단(제목 표시줄 포함)이 커서 아래에 오도록 전체 프레임 높이를 기준으로 Y 계산
            var popupY = rect.origin.y - popupHeight - textMargin

            // 경계 확인 X
            if popupX + popupWidth > screenFrame.maxX {
                popupX = screenFrame.maxX - popupWidth - 10
            }
            if popupX < screenFrame.minX {
                popupX = screenFrame.minX + 10
            }

            // 경계 확인 Y
            if popupY < screenFrame.minY {
                // 아래 공간 부족, 위로 강제 이동
                // 윈도우 하단을 커서 상단 위에 배치
                popupY = rect.origin.y + rect.height + textMargin
            }
            // 상단 오버플로우 확인 (위로 강제되거나 엄격하게 배치된 경우)
            if popupY + popupHeight > screenFrame.maxY {
                // ✅ Issue 288 Fix: 상단 가장자리 아래에 있어야 하므로 10을 더하는 것이 아니라(화면 벗어남) 10을 빼야 함
                popupY = screenFrame.maxY - popupHeight - 10
            }

            targetPoint = NSPoint(x: popupX, y: popupY)
            logD(
                "🎞️ [HistoryViewerManager] Position matched to cursor: \(targetPoint) (Frame H: \(popupHeight))"
            )

        } else {
            // 폴백: 마우스 위치
            let mouseLocation = NSEvent.mouseLocation
            var mouseScreen: NSScreen? = nil
            for screen in NSScreen.screens {
                if NSMouseInRect(mouseLocation, screen.frame, false) {
                    mouseScreen = screen
                    break
                }
            }
            let screenFrame =
                mouseScreen?.frame ?? NSScreen.main?.frame
                ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

            let cursorMargin: CGFloat = 20
            var popupX = mouseLocation.x
            var popupY = mouseLocation.y - popupHeight - cursorMargin

            if popupX + popupWidth > screenFrame.maxX {
                popupX = screenFrame.maxX - popupWidth - 10
            }
            if popupX < screenFrame.minX {
                popupX = screenFrame.minX + 10
            }

            if popupY < screenFrame.minY {
                popupY = mouseLocation.y + cursorMargin
            }
            if popupY + popupHeight > screenFrame.maxY {
                popupY = screenFrame.maxY - popupHeight - 10
            }

            targetPoint = NSPoint(x: popupX, y: popupY)
            logD("🎞️ [HistoryViewerManager] Position matched to mouse: \(targetPoint)")
        }

        return targetPoint
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
