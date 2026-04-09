import Cocoa
import Combine
import SwiftUI

/// 클립보드 히스토리 프리뷰의 상태 및 동작을 관리하는 매니저 (Issue 543)
/// 레거시 별도 윈도우 로직이 제거되고, UnifiedHistoryViewer와의 연동을 위한 상태 관리 역할만 수행함.
class HistoryPreviewManager: NSObject, ObservableObject {
    static let shared = HistoryPreviewManager()

    // 구성
    @Published var isEnabled: Bool = true  // 사용자 설정 마스터 스위치
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()

        // 설정 동기화
        let settings = SettingsObservableObject.shared
        self.isEnabled = settings.historyShowPreview
        logD("️‍🗨️ [HistoryPreviewManager] Init. isEnabled: \(isEnabled)")

        // 설정 변경 관찰자
        settings.$historyShowPreview
            .sink { [weak self] newValue in
                self?.isEnabled = newValue
                logD("️‍🗨️ [HistoryPreviewManager] Settings changed. isEnabled: \(newValue)")
                // 통합 뷰 너기 갱신을 위해 매니저에 알림 (필요 시)
            }
            .store(in: &cancellables)
    }

    func isPreviewWindow(_ window: NSWindow?) -> Bool {
        // 더 이상 별도 프리뷰 윈도우가 없으므로 항상 false
        return false
    }

    func show(item: ClipboardItem) {
        // 별도 윈도우 표시 로직 제거. 상태 업데이트는 뷰에서 직접 수행하거나 StateManager 사용.
        logD(
            "️‍🗨️ [HistoryPreviewManager] show requested for item \(item.id ?? -1). (Unified UI Handles this via State)"
        )
        HistoryPreviewState.shared.currentItem = item
        HistoryPreviewState.shared.currentText = item.text ?? ""
    }

    func togglePreview() {
        let settings = SettingsObservableObject.shared
        settings.historyShowPreview.toggle()
        settings.saveUISettings()
    }

    func togglePreview(with currentItem: ClipboardItem?) {
        let settings = SettingsObservableObject.shared
        if settings.historyShowPreview {
            settings.historyShowPreview = false
            settings.saveUISettings()
            ToastManager.shared.showToast(message: LocalizedStringManager.shared.string("toast.preview_off"), iconName: "eye.slash.fill")
        } else {
            settings.historyShowPreview = true
            settings.saveUISettings()
            ToastManager.shared.showToast(message: LocalizedStringManager.shared.string("toast.preview_on"), iconName: "eye.fill")
            if let item = currentItem {
                show(item: item)
            }
        }
    }

    func startEditing(item: ClipboardItem, cursorIndex: Int? = nil) {
        HistoryPreviewState.shared.startEditing(item: item)
        HistoryPreviewState.shared.initialCursorIndex = cursorIndex ?? 0
        
        startEditing()
    }

    func startEditing() {
        logD("️‍🗨️ [HistoryPreviewManager] startEditing called")
        guard HistoryPreviewState.shared.currentItem != nil else { return }

        // 상태 설정
        ClipboardManager.shared.chvMode = .previewEdit

        // 통합 윈도우 내에서 포커스 전환이 필요할 수 있음 (HistoryViewer -> PreviewTextView)
        // 이는 SwiftUI FocusState 또는 NSWindow.makeFirstResponder로 처리
    }

    func startInteracting(item: ClipboardItem) {
        logD("️‍🗨️ [HistoryPreviewManager] startInteracting with item called")
        HistoryPreviewState.shared.startInteracting(item: item)
    }

    func startInteracting() {
        logD("️‍🗨️ [HistoryPreviewManager] startInteracting called")
        guard isEnabled else { return }
        ClipboardManager.shared.chvMode = .previewView

        // Ensure state is properly initialized if there's a current item
        if let item = HistoryPreviewState.shared.currentItem {
            HistoryPreviewState.shared.startInteracting(item: item)
        }
    }

    func ensureInteractiveMode() {
        guard isEnabled else { return }
        if ClipboardManager.shared.chvMode != .previewView {
            ClipboardManager.shared.chvMode = .previewView
        }
    }

    func transitionToInteracting(preservingLine: Int? = nil) {
        logD("️‍🗨️ [HistoryPreviewManager] transitionToInteracting called (line: \(preservingLine ?? 0))")
        HistoryPreviewState.shared.switchToInteractiveMode(preservingLine: preservingLine)
    }

    func stopEditing(shouldRestoreFocus: Bool = true) {
        logD("️‍🗨️ [HistoryPreviewManager] stopEditing called")
        HistoryPreviewState.shared.stopEditing()

        DispatchQueue.main.async {
            ClipboardManager.shared.chvMode = .list
        }
    }

    func hide() {
        logD("️‍🗨️ [HistoryPreviewManager] hide called")
        stopEditing(shouldRestoreFocus: false)
    }

    func updatePosition() {
        // 별도 윈도우가 없으므로 위치 동기화 불필요
    }
}
