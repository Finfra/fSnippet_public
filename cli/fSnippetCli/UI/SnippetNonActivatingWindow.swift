import Cocoa
import Foundation
import SwiftUI

// MARK: - Issue716: Beep 방지 NSPanel 서브클래스

/// Enter 등 처리되지 않은 키 이벤트에 대해 macOS 시스템 Beep을 억제하는 NSPanel
private class SilentPanel: NSPanel {
    override func noResponder(for eventSelector: Selector) {
        // 기본 구현(NSBeep() 호출)을 무시하여 Beep 소리 방지
    }
}

/// 포커스를 받지 않는 Non-Activating Snippet 팝업 윈도우
class SnippetNonActivatingWindow: NSObject, NSWindowDelegate {

    // MARK: - Properties

    private let popupWindow: NSWindow
    private let hostingController: NSHostingController<UnifiedSnippetPopupView>
    let viewModel = SnippetPopupViewModel()

    // 팝업 상태
    private(set) var isVisible: Bool = false

    // Issue 219-1: PreviewManager를 위해 기본 NSWindow 노출
    var underlyingWindow: NSWindow {
        return popupWindow
    }

    // 선택 콜백
    private var currentSelectionCallback: ((SnippetEntry) -> Void)?

    // MARK: - Initialization

    override init() {

        // 1. SwiftUI 뷰 및 호스팅 컨트롤러 생성
        let popupView = UnifiedSnippetPopupView(viewModel: viewModel)
        hostingController = NSHostingController(rootView: popupView)

        // ✅ Issue 245 리팩토링: 초기 크기 설정에 중앙 집중식 상수 사용
        let settings = SettingsManager.shared.load()
        let initialRows = settings.popupRows
        let calculatedHeight = PopupUIConstants.calculateWindowHeight(rows: initialRows)

        // ✅ Issue 355 & 560: 통합 윈도우 너비 계산 (리스트 너비 + 프리뷰 너비 (Issue 595))
        let listWidth = SettingsObservableObject.shared.effectivePopupWidth
        let previewWidth = SettingsObservableObject.shared.effectivePopupPreviewWidth
        let totalPopupWidth = listWidth + previewWidth
        let fixedSize = NSSize(width: totalPopupWidth, height: calculatedHeight)
        hostingController.preferredContentSize = fixedSize

        // ✅ View 크기 강제 설정
        let view = hostingController.view
        view.frame = NSRect(origin: .zero, size: fixedSize)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        // ✅ HostingController 크기 강제 설정 (초기화 후 수행)

        // 2. Activating Panel 생성 - 포커스를 받는 윈도우 (Issue118)
        let windowRect = NSRect(x: 0, y: 0, width: totalPopupWidth, height: calculatedHeight)
        popupWindow = SilentPanel(
            contentRect: windowRect,
            // ✅ .nonactivatingPanel 제거 -> 일반 패널 (포커스 가능)
            styleMask: [.borderless, .titled],
            backing: .buffered,
            defer: false
        )
        popupWindow.title = "SnippetPopupWindow"  // ✅ Capture Identification
        popupWindow.setAccessibilityIdentifier("SnippetPopupWindow")  // XCUITest 식별자

        // ✅ 강제 크기 설정 (생성 직후)
        popupWindow.setFrame(windowRect, display: false)

        // ✅ 초기화 시 스니펫 팝업창 크기 로깅
        let initFrame = popupWindow.frame
        logV("👻 [초기화] width: \(initFrame.width), height: \(initFrame.height)")
        logV("👻 [초기화] left: \(initFrame.origin.x), top: \(initFrame.maxY)")

        // 3. 윈도우 설정 - 포커스 허용 설정 (Issue118)
        popupWindow.contentViewController = hostingController
        popupWindow.backgroundColor = .clear
        popupWindow.isOpaque = false
        popupWindow.hasShadow = true
        popupWindow.level = .floating
        popupWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // ❗️ 핵심: 포커스 허용 (Issue118)
        popupWindow.hidesOnDeactivate = false  // 비활성화되어도 바로 사라지지 않게 (선택 후 포커스 이동 시 처리)
        popupWindow.ignoresMouseEvents = false

        // ✅ 타이틀바 숨기기 (styleMask에 .titled가 있어야 KeyWindow가 되기 쉬움)
        popupWindow.titleVisibility = .hidden
        popupWindow.titlebarAppearsTransparent = true
        popupWindow.isMovableByWindowBackground = true  // ✅ Issue256: Allow dragging by background

        // ✅ 중요: contentSize 설정 처리 (height=0 문제 해결)
        // 명시적 크기 설정 - 여러 번 시도
        let initialListWidth = SettingsObservableObject.shared.effectivePopupWidth
        let initialPreviewWidth = SettingsObservableObject.shared.effectivePopupPreviewWidth
        let initialTotalWidth = initialListWidth + initialPreviewWidth
        let targetSize = NSSize(width: initialTotalWidth, height: 300)
        if let panel = popupWindow as? NSPanel {
            panel.setContentSize(targetSize)
        }
        popupWindow.minSize = NSSize(width: 100, height: 100)  // Allow smaller width if configured
        popupWindow.maxSize = NSSize(width: 2000, height: 2000)  // Allow larger width

        // 강제 크기 설정
        popupWindow.setFrame(
            NSRect(origin: popupWindow.frame.origin, size: targetSize), display: false)

        super.init()

        // 4. ViewModel 콜백 설정
        setupViewModelCallbacks()

        // 4.5. HostingController 크기 강제 설정 (초기화 후)
        DispatchQueue.main.async {
            // ✅ Issue 245 수정: 하드코딩된 300px가 경합 조건을 유발했음. 계산된 높이 사용.
            let settingsObj = SettingsObservableObject.shared
            // ✅ Issue 245 Refactor: Use Centralized Constants
            let maxRowsHeight = PopupUIConstants.calculateWindowHeight(rows: settingsObj.popupRows)

            // ✅ Issue 245 리팩토링: 중앙 집중식 상수 사용
            // let maxRowsHeight = PopupUIConstants.calculateWindowHeight(rows: settingsObj.popupRows) // Removed duplicate
            let currentWidth = settingsObj.effectivePopupWidth  // Issue355

            let settingsSize = NSSize(width: currentWidth, height: maxRowsHeight)

            self.hostingController.view.setFrameSize(settingsSize)
            // ✅ 강제 레이아웃 업데이트
            self.hostingController.view.needsLayout = true
            self.hostingController.view.layoutSubtreeIfNeeded()

            // ✅ 윈도우 크기 재설정
            if let panel = self.popupWindow as? NSPanel {
                panel.setContentSize(settingsSize)

                // ✅ 비동기 크기 설정 후 로깅
                let asyncFrame = self.popupWindow.frame
                logV(
                    "👻 [비동기설정] width: \(asyncFrame.width), height: \(asyncFrame.height) (rows: \(settingsObj.popupRows))"
                )
                logV("👻 [비동기설정] left: \(asyncFrame.origin.x), top: \(asyncFrame.maxY)")
            }
        }

        // ✅ 초기 위치 설정 (화면 밖)
        popupWindow.setFrameOrigin(NSPoint(x: -1000, y: -1000))

        // ✅ Notification 관찰자 추가 (Issue 184/245/355)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handlePopupRowsChange(_:)), name: .popupRowsDidChange,
            object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handlePopupWidthChange(_:)), name: .popupWidthDidChange,
            object: nil)

        // ✅ 초기 위치 설정 후 로깅
        let hiddenFrame = popupWindow.frame
        logV("👻 🫥 [화면밖이동] left: \(hiddenFrame.origin.x), top: \(hiddenFrame.maxY)")

        // 4. Delegate 설정 (Issue 260: 윈도우 이동 감지)
        popupWindow.delegate = self

    }

    // MARK: - Public Methods

    /// 팝업을 표시합니다
    func show(
        with snippets: [SnippetEntry],
        initialSearchTerm: String,
        cursorRect: CGRect? = nil,  // ✅ Issue181: 미리 계산된 커서 위치 수신
        onSelection: @escaping (SnippetEntry) -> Void,
        onSearchTermChanged: @escaping (String) -> Void
    ) {
        // ✅ Issue169: 뷰모델에 초기 검색어 전달
        viewModel.initialSearchTerm = initialSearchTerm
        // ✅ Issue170: 검색어 변경 콜백 연결
        viewModel.onSearchTermChanged = onSearchTermChanged

        // guard !snippets.isEmpty else {
        //    return
        // }

        // 이미 표시 중이면 내용만 업데이트
        if isVisible {
            updateContent(with: snippets)
            currentSelectionCallback = onSelection
            return
        }

        // 1. 콜백 업데이트
        currentSelectionCallback = onSelection

        // 2. 내용 업데이트
        viewModel.updateSnippets(snippets, force: true)

        // ✅ 2.5 높이 사전 계산 (행 기반 사이징 적용)
        // Issue 245: 실시간 리사이징을 위해 라이브 SettingsObservableObject 사용
        let settingsObj = SettingsObservableObject.shared
        let maxRowsHeight = PopupUIConstants.calculateWindowHeight(rows: settingsObj.popupRows)
        let minHeight: CGFloat = 100

        // 행(Row) 기준 고정 높이 적용: 콘텐츠 개수와 무관하게 rows 기준으로 뷰포트 높이 결정
        let calculatedHeight = max(minHeight, maxRowsHeight)

        // Issue355: 동적 너비
        let popupHeight = calculatedHeight  // ✅ 동적으로 계산된 높이 사용
        let totalPopupWidth =
            settingsObj.effectivePopupWidth + settingsObj.effectivePopupPreviewWidth

        popupWindow.maxSize = NSSize(width: 2000, height: maxRowsHeight)  // ✅ 물리적 제한 강제 (Width는 Flexible하게)

        logI(
            "👻 [Show] 높이 계산(행 기준): rows=\(settingsObj.popupRows), count=\(snippets.count) -> height=\(popupHeight) (rowsHeight=\(maxRowsHeight)), totalWidth=\(totalPopupWidth)"
        )

        // 3. 커서 위치 기반 팝업 표시 (멀티 디스플레이 지원)
        let targetPoint: NSPoint

        // ✅ Issue181: 전달받은 cursorRect가 있으면 우선 사용, 없으면 직접 조회
        if let cursorRect = cursorRect ?? CursorTracker.shared.getCursorRect() {
            // ✅ 커서가 위치한 실제 화면 찾기 (멀티 디스플레이 지원)
            let cursorPoint = NSPoint(x: cursorRect.midX, y: cursorRect.midY)
            var targetScreen: NSScreen? = nil

            // 모든 화면을 검사해서 커서가 위치한 화면 찾기
            for screen in NSScreen.screens {
                if screen.frame.contains(cursorPoint) {
                    targetScreen = screen
                    break
                }
            }

            // 화면을 찾지 못한 경우 main 화면 사용
            let screenFrame =
                targetScreen?.frame ?? NSScreen.main?.frame
                ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

            // 커서 위치에서 팝업 표시 (글자가 가려지지 않도록 충분한 간격)
            let textMargin: CGFloat = 25  // 타이핑 영역과 팝업 간 충분한 간격 (글자 크기 고려)

            var popupX = cursorRect.origin.x
            var popupY = cursorRect.origin.y - popupHeight - textMargin  // ✅ 계산된 높이 사용

            // 화면 경계 체크 및 조정 (통합 너비 기준)
            if popupX + totalPopupWidth > screenFrame.maxX {
                popupX = screenFrame.maxX - totalPopupWidth - 10
            }
            if popupX < screenFrame.minX {
                popupX = screenFrame.minX + 10
            }

            // 위쪽 공간이 부족하면 커서 아래쪽에 표시
            if popupY < screenFrame.minY {
                popupY = cursorRect.origin.y + cursorRect.height + textMargin
            }
            if popupY + popupHeight > screenFrame.maxY {
                popupY = screenFrame.maxY - popupHeight - 10
            }

            targetPoint = NSPoint(x: popupX, y: popupY)

            logV("👻 멀티 디스플레이 커서 위치 기반 팝업 표시:")
            logV("👻     - 감지된 화면: \(targetScreen?.localizedName ?? "Unknown") (\(screenFrame))")
            logV("👻     - 커서 위치: \(cursorRect)")
            logV("👻     - 팝업 위치: (\(popupX), \(popupY))")
        } else {
            // 커서 위치를 가져올 수 없는 경우 fallback (마우스 위치)
            let mouseLocation = NSEvent.mouseLocation

            // NSEvent.mouseLocation은 전체 스크린 좌표계 (좌하단 0,0)
            // 해당 위치가 포함된 스크린 찾기
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

            // 마우스 커서 위치에서 팝업 표시
            let cursorMargin: CGFloat = 20

            var popupX = mouseLocation.x
            // 마우스 커서는 좌상단이 포인터이므로, 커서 아래에 표시하려면 y를 내려야 함
            var popupY = mouseLocation.y - popupHeight - cursorMargin

            // 화면 경계 체크 및 조정 (통합 너비 기준)
            if popupX + totalPopupWidth > screenFrame.maxX {
                popupX = screenFrame.maxX - totalPopupWidth - 10
            }
            if popupX < screenFrame.minX {
                popupX = screenFrame.minX + 10
            }

            // 아래쪽 공간이 부족하면 커서 위쪽에 표시
            if popupY < screenFrame.minY {
                popupY = mouseLocation.y + cursorMargin
            }
            // 위쪽 공간 체크 (위로 올렸는데 화면 벗어나면 다시 조정)
            if popupY + popupHeight > screenFrame.maxY {
                popupY = screenFrame.maxY - popupHeight - 10
            }

            targetPoint = NSPoint(x: popupX, y: popupY)

            logW("👻 ⚠️ 텍스트 커서 위치 획득 실패 - 마우스 위치로 fallback: (\(mouseLocation.x), \(mouseLocation.y))")
        }

        // 스니펫 팝업창 위치 설정
        popupWindow.setFrameOrigin(targetPoint)

        // ✅ 위치 설정 직후 로깅
        let positionFrame = popupWindow.frame
        logV("👻 [위치설정직후] width: \(positionFrame.width), height: \(positionFrame.height)")
        logV("👻 [위치설정직후] left: \(positionFrame.origin.x), top: \(positionFrame.maxY)")

        // 3.5. 크기 재설정 (표시 직전) - ✅ 계산된 크기 적용 (통합 너비)
        let finalSize = NSSize(width: totalPopupWidth, height: popupHeight)

        popupWindow.setFrame(NSRect(origin: targetPoint, size: finalSize), display: true)

        if let panel = popupWindow as? NSPanel {
            panel.setContentSize(finalSize)
        }
        hostingController.preferredContentSize = finalSize  // ✅ Issue 246: 선호 크기 업데이트
        hostingController.view.setFrameSize(finalSize)

        // ✅ 스니펫 팝업창 위치 및 크기 정보 로깅
        let frame = popupWindow.frame
        let topLeft = NSPoint(x: frame.origin.x, y: frame.maxY)
        let topRight = NSPoint(x: frame.maxX, y: frame.maxY)
        logV("👻️ [스니펫 팝업창 위치] topLeft: (\(topLeft.x), \(topLeft.y))")
        logV("👻️ [스니펫 팝업창 위치] topRight: (\(topRight.x), \(topRight.y))")
        logV("👻️ [스니펫 팝업창 크기] width: \(frame.width), height: \(frame.height)")
        logV("👻️ [스니펫 팝업창 전체] frame: \(frame)")

        // ✅ 사용자 요청: 상세 높이 디버그 로그
        logD("👻 [Height Debug] 설정된 행 수: \(settingsObj.popupRows)")
        logD("👻 [Height Debug] 계산된 윈도우 높이: \(popupHeight)")
        logD("👻 [Height Debug] 실제 Window Frame 높이: \(popupWindow.frame.height)")
        logD("👻 [Height Debug] 실제 PopupView(Hosting) 높이: \(hostingController.view.frame.height)")

        // 4. 윈도우 상태 확인 및 로그

        // 5. 팝업 표시 (Issue118: 활성 윈도우로 표시)
        // ✅ 앱 활성화 및 윈도우 키 포커스 획득
        NSApp.activate(ignoringOtherApps: true)
        popupWindow.makeKeyAndOrderFront(nil)

        // ✅ Issue616: 팝업이 표시될 때 마우스 커서가 창을 가리면 밖으로 이동
        MouseUtils.ensureMouseOutside(of: popupWindow.frame)

        // 6. 윈도우 상태 재확인
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 포커스 강제 확인 로그
            if self.popupWindow.isKeyWindow {
                logV("👻 팝업 윈도우가 Key Window 상태입니다.")
            } else {
                logW("👻 ⚠️ 팝업 윈도우가 Key Window가 아닙니다. 포커스 문제 가능성.")
                self.popupWindow.makeKey()
            }
        }

        isVisible = true
    }

    /// 팝업을 숨깁니다
    func hide(hideApp: Bool = true) {
        guard isVisible else {
            return
        }

        // 1. 윈도우 숨김
        popupWindow.orderOut(nil)

        // 2. 앱 비활성화 (이전 앱으로 포커스 복귀) - Issue118
        // ✅ [Issue34] paid + show_in_app_switcher 모드에서만 NSApp.hide 사용
        // 그 외에는 PopupController.hidePopup()에서 현재 frontmost 앱으로 명시적 복귀 처리
        if hideApp {
            let isPaidRunning = PaidAppManager.shared.isRunning()
            let showInSwitcher = SettingsObservableObject.shared.showInAppSwitcher

            if isPaidRunning && showInSwitcher {
                NSApp.hide(nil)
                logV("👻 [SnippetWindow] NSApp.hide(nil) 실행 (paid + show_in_app_switcher 모드)")
            } else {
                logV("👻 [SnippetWindow] NSApp.hide 스킵 — paid 미설치 또는 switcher 꺼짐, PopupController에서 복귀 처리")
            }
        }

        // ✅ 숨김 직후 로깅
        let hideFrame = popupWindow.frame
        logV("👻 🫥 [숨김처리] width: \(hideFrame.width), height: \(hideFrame.height)")
        logV("👻 🫥 [숨김처리] left: \(hideFrame.origin.x), top: \(hideFrame.maxY)")

        // 3. 윈도우를 화면 밖으로 이동
        popupWindow.setFrameOrigin(NSPoint(x: -1000, y: -1000))

        // ✅ 화면밖 이동 후 로깅
        let offscreenFrame = popupWindow.frame
        logV("👻 [화면밖완료] width: \(offscreenFrame.width), height: \(offscreenFrame.height)")
        logV("👻 [화면밖완료] left: \(offscreenFrame.origin.x), top: \(offscreenFrame.maxY)")

        // 4. 상태 업데이트
        isVisible = false
        currentSelectionCallback = nil

    }

    /// 현재 표시 중인지 확인
    var isCurrentlyVisible: Bool {
        return isVisible
    }

    /// 팝업 내용 업데이트 (위치 완전 고정, 크기만 조정)
    func updateContent(with snippets: [SnippetEntry]) {
        guard isVisible else { return }

        // 뷰모델 업데이트 (먼저 내용 업데이트)
        viewModel.updateSnippets(snippets)

        // 행(Row) 기준 고정 높이 계산 (콘텐츠 개수와 무관)
        let settingsObj = SettingsObservableObject.shared
        let maxHeight = PopupUIConstants.calculateWindowHeight(rows: settingsObj.popupRows)
        let totalPopupWidth =
            settingsObj.effectivePopupWidth + settingsObj.effectivePopupPreviewWidth

        let calculatedHeight = maxHeight
        let newSize = NSSize(width: totalPopupWidth, height: calculatedHeight)

        popupWindow.maxSize = NSSize(width: 2000, height: maxHeight)  // ✅ 물리적 제한 강제

        // ✅ 위치 개선: 상단 고정 (Top-Left anchoring)
        let currentFrame = popupWindow.frame
        let currentMaxY = currentFrame.maxY  // 현재 상단 위치 저장

        // 새로운 Y 좌표 계산 (상단 위치 - 새 높이)
        let newY = currentMaxY - newSize.height
        let newOrigin = NSPoint(x: currentFrame.origin.x, y: newY)

        logV("👻 [updateContent] 위치 상단 고정 업데이트(행 기준):")
        logV("👻     - 상단 위치(MaxY): \(currentMaxY)")
        logV("👻     - 이전 높이: \(currentFrame.height) -> 새 높이: \(newSize.height)")
        logV("👻     - 새 Origin: (\(newOrigin.x), (\(newOrigin.y)))")

        // ✅ 크기와 위치 모두 조정
        let newFrame = NSRect(origin: newOrigin, size: newSize)
        popupWindow.setFrame(newFrame, display: true, animate: false)

        // 호스팅 컨트롤러도 동일하게 크기 조정
        hostingController.preferredContentSize = newSize  // ✅ Issue 246: 선호 크기 업데이트
        hostingController.view.setFrameSize(newSize)
        if let panel = popupWindow as? NSPanel {
            panel.setContentSize(newSize)
        }

        // ✅ 위치 검증 (상단이 유지되었는지)
        let verifyFrame = popupWindow.frame
        if abs(verifyFrame.maxY - currentMaxY) > 0.1 {
            logW("👻 ⚠️ [updateContent] 상단 위치가 변경됨(\(verifyFrame.maxY) != \(currentMaxY))! 재조정합니다.")
            let correctY = currentMaxY - verifyFrame.height
            popupWindow.setFrameOrigin(NSPoint(x: verifyFrame.origin.x, y: correctY))
        }

        let finalFrame = popupWindow.frame
        logV(
            "👻 [updateContent 완료] 최종 위치: (\(finalFrame.origin.x), \(finalFrame.origin.y)) - 크기: (\(finalFrame.width), \(finalFrame.height))"
        )
    }

    /// 화살표 키 처리
    func handleArrowKey(_ keyCode: UInt16) {
        guard isVisible else {
            return
        }

        // 빈 로그 제거됨

        // 메인 스레드에서 안전하게 실행
        DispatchQueue.main.async {
            switch keyCode {
            case 126:  // Up Arrow
                self.viewModel.moveSelectionUp()
            case 125:  // Down Arrow
                self.viewModel.moveSelectionDown()
            default:
                logW("👻 ")
                return
            }

            // 빈 로그 제거됨
        }
    }

    /// 현재 선택된 항목 확정
    func selectCurrentItem() {
        guard isVisible else {
            logW("👻 ⚠️ SnippetNonActivatingWindow.selectCurrentItem 호출되었지만 보이지 않음")
            return
        }
        logV("👻 SnippetNonActivatingWindow.selectCurrentItem 호출 - viewModel.confirmSelection 실행")
        viewModel.confirmSelection()
    }

    /// 선택을 첫 번째 항목으로 리셋
    func resetSelection() {
        guard isVisible else { return }
        viewModel.updateSelectedIndex(0)
    }

    // MARK: - Private Methods

    /// ViewModel 콜백 설정
    private func setupViewModelCallbacks() {
        viewModel.onSelection = { [weak self] snippet in
            // 빈 로그 제거됨
            self?.handleSelection(snippet)
        }

        viewModel.onCancel = { [weak self] in
            self?.hide()
        }
    }

    /// 선택 처리
    private func handleSelection(_ snippet: SnippetEntry) {
        logI("👻 SnippetNonActivatingWindow.handleSelection 호출: '\(snippet.abbreviation)'")

        // 콜백 임시 저장 (hide()가 nil로 만들기 전에)
        let callback = currentSelectionCallback

        // 콜백 실행 (먼저 실행하여 PopupController가 현재 프레임(보이는 상태)을 캡처할 수 있게 함)
        logI("👻 currentSelectionCallback 호출 (hide 전)")
        callback?(snippet)

        // 팝업 숨김 (콜백 후)
        hide()
    }

    /// 앱 종료 시 정리
    func cleanup() {
        NotificationCenter.default.removeObserver(self)
        if isVisible {
            hide()
        }

        popupWindow.close()

        // ViewModel 콜백 제거
        viewModel.onSelection = nil
        viewModel.onCancel = nil
    }

    // MARK: - Notification Handlers

    @objc private func handlePopupRowsChange(_ notification: Notification) {
        let newRows = notification.object as? Int ?? SettingsObservableObject.shared.popupRows
        logI("👻 [Window] popupRowsDidChange 수신: \(newRows)행 (현재 표시중: \(isVisible))")

        if isVisible {
            logI("👻 [SnippetNonActivatingWindow] 팝업 행 수 실시간 업데이트 트리거")
            // 현재 스니펫 목록을 유지하면서 크기만 재계산 및 리사이징
            updateContent(with: viewModel.snippets)
        }
    }

    // ✅ Issue355: 너비 변경 처리
    @objc private func handlePopupWidthChange(_ notification: Notification) {
        let newWidth =
            notification.object as? CGFloat ?? SettingsObservableObject.shared.effectivePopupWidth
        logI("👻 [Window] popupWidthDidChange 수신: \(newWidth)px (현재 표시중: \(isVisible))")

        if isVisible {
            logI("👻 [SnippetNonActivatingWindow] 팝업 너비 실시간 업데이트 트리거")
            updateContent(with: viewModel.snippets)
        }
    }

    // ✅ Issue 595: 미리보기 너비 변경 처리
    @objc private func handlePopupPreviewWidthChange(_ notification: Notification) {
        let newWidth =
            notification.object as? CGFloat
            ?? SettingsObservableObject.shared.effectivePopupPreviewWidth
        logI("👻 [Window] popupPreviewWidthDidChange 수신: \(newWidth)px (현재 표시중: \(isVisible))")

        if isVisible {
            logI("👻 [SnippetNonActivatingWindow] 팝업 미리보기 너비 실시간 업데이트 트리거")
            updateContent(with: viewModel.snippets)
        }
    }

    // MARK: - NSWindowDelegate (Issue 260)

    func windowDidMove(_ notification: Notification) {
        guard isVisible else { return }
        // 통합 윈도우이므로 프리뷰가 자동으로 따라옴 (동선 낭비 제거)
    }

    // ✅ Issue392 + Issue719: 윈도우 포커스 소실 시 자동 닫기
    func windowDidResignKey(_ notification: Notification) {
        guard isVisible else { return }
        // Issue719: 편집 창으로 포커스 이동 시 팝업 유지 (레이어 스택 보존)
        if SnippetEditorWindowManager.shared.isEditorWindow(NSApp.keyWindow) {
            logI("👻 [SnippetNonActivatingWindow] windowDidResignKey 감지 -> 편집 창으로 전환, 팝업 유지")
            return
        }
        logI("👻 [SnippetNonActivatingWindow] windowDidResignKey 감지 -> 팝업 닫기")
        // hideApp: false로 하여 앱 자체를 숨기지는 않음 (이미 포커스를 잃었으므로)
        hide(hideApp: false)
    }

    deinit {
        cleanup()
    }
}
