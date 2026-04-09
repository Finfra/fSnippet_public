import Cocoa
import Foundation

/// Fully integrated Key Event Monitor - Composition Root
/// Refactored to delegate responsibilities to sub-components (Issue 583_7)
class KeyEventMonitor: PopupControllerDelegate, CollisionManagerDelegate, TriggerProcessorDelegate {

    // MARK: - Properties

    // Components
    private let bufferController: BufferController
    private let snippetExpansionCoordinator: SnippetExpansionCoordinator
    private let keyEventHandler: KeyEventHandler

    // Legacy/Shared
    var popupController: PopupController  // Internal for access?
    private let keyProcessor: KeyEventProcessor

    // State
    private var isCleanedUp = false

    // Callbacks
    private let callback: (String) -> Void  // onPotentialAbbreviation

    // MARK: - Initialization

    init(onPotentialAbbreviation: @escaping (String) -> Void) {
        self.callback = onPotentialAbbreviation

        // 1. Initialize Managers & Controllers
        // Buffer
        self.bufferController = BufferController()

        // Popup
        self.popupController = PopupController()

        // Expansion
        self.snippetExpansionCoordinator = SnippetExpansionCoordinator(
            bufferController: bufferController)

        // Key Handler
        self.keyEventHandler = KeyEventHandler(
            bufferController: bufferController,
            popupController: popupController,
            expansionCoordinator: snippetExpansionCoordinator
        )

        // Key Processor (Low Level)
        self.keyProcessor = KeyEventProcessor()

        // 2. Wire Dependencies
        keyEventHandler.setKeyEventProcessor(keyProcessor)
        keyProcessor.setDelegate(keyEventHandler)  // KeyEventHandler is the delegate now!

        self.popupController.delegate = self  // Monitor stays delegate for global state sync

        // Wire Expansion Coordinator Callbacks
        snippetExpansionCoordinator.onReplacementStatusChanged = { [weak self] isReplacing in
            self?.keyProcessor.updateReplacementState(isReplacing: isReplacing)
            logV("🔹 [Monitor] Replacement State Sync: \(isReplacing)")
        }

        snippetExpansionCoordinator.onEventTapSuspensionRequested = { [weak self] in
            self?.keyProcessor.suspendEventTap()
        }

        snippetExpansionCoordinator.onEventTapResumptionRequested = { [weak self] in
            self?.keyProcessor.resumeEventTap()
        }

        snippetExpansionCoordinator.onExpansionSuccess = { [weak self] in
            self?.bufferController.clear(reason: "Expansion Success")
            self?.popupController.hidePopup()  // Ensure popup is closed
        }

        snippetExpansionCoordinator.onExpansionFailure = { [weak self] in
            self?.bufferController.clear(reason: "Expansion Failure")
        }

        snippetExpansionCoordinator.onPopupHideRequested = { [weak self] in
            self?.popupController.hidePopup()
        }

        // Note: We need to wire callback (onPotentialAbbreviation) to expansion coordinator?
        // Actually, callback was called in `handleSuffixBasedExpansion`.
        // Since `SnippetExpansionCoordinator` handles suffix logic now, it might invoke this?
        // But wait, `TriggerProcessor` calls `Monitor.performTextReplacement` which calls `Coordinator`.
        // If `TriggerProcessor` determines it was a suffix expansion, it passes "suffix" to method.
        // We can check method in Coordinator or Monitor.
        // But the callback(abbrev) needs to happen on success.

        // Wire Buffer Controller Callbacks
        bufferController.onBufferClear = { [weak self] reason in
            self?.keyProcessor.resetState()

            // ✅ Issue Fix: Prevent infinite recursion (Buffer Clear -> Hide Popup -> Buffer Clear)
            // Only hide popup if it's visible AND the clear wasn't triggered by the popup hiding itself.
            if reason != "Popup Hidden" && self?.popupController.isVisible == true {
                self?.popupController.hidePopup()
            }
        }

        // Global Delegates
        TriggerProcessor.shared.delegate = self
        CollisionManager.shared.delegate = self

        // Observers
        setupObservers()

        // RuleManager & Settings
        RuleManager.shared.invalidateEffectiveRulesCache()
        TriggerKeyManager.shared.reloadSettings()

        // Initial State
        _ = KeyRenderingManager.shared
        logV("🔹 KeyEventMonitor Refactored Initialized")
    }

    // MARK: - Public Methods

    func startMonitoring() {
        bufferController.clear(reason: "Startup")
        keyProcessor.startMonitoring()
        WindowContextManager.shared.startMonitoring()
        logV("🔹 KeyEventMonitor Started")
    }

    func stopMonitoring() {
        keyProcessor.stopMonitoring()
        WindowContextManager.shared.stopMonitoring()
        logV("🔹 KeyEventMonitor Stopped")
    }

    /// 키 이벤트를 처리하고 성공 여부(스니펫 확장 등)를 반환 (Sync Trigger용)
    func handleKeyEventAndReturnSuccess(_ keyInfo: KeyEventInfo) -> Bool {
        return keyEventHandler.handleKeyEventAndReturnSuccess(keyInfo)
    }

    func cleanup() {
        guard !isCleanedUp else { return }
        isCleanedUp = true
        NotificationCenter.default.removeObserver(self)
        keyProcessor.cleanup()
        popupController.cleanup()
        bufferController.clear(reason: "Cleanup")
        logV("🔹 KeyEventMonitor Cleaned Up")
    }

    // MARK: - Observers

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleRulesChanged), name: .snippetFoldersDidChange,
            object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handlePlaceholderDidBecomeActive),
            name: NSNotification.Name("fSnippetPlaceholderWindowDidBecomeActive"), object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handlePlaceholderDidResignActive),
            name: NSNotification.Name("fSnippetPlaceholderWindowDidResignActive"), object: nil)

        WindowContextManager.shared.onContextChange = { [weak self] pid, winId in
            self?.bufferController.clear(reason: "Context Change")
        }
    }

    @objc private func handleRulesChanged() {
        RuleManager.shared.invalidateEffectiveRulesCache()
    }

    @objc private func handlePlaceholderDidBecomeActive() {
        keyProcessor.updateAppActiveState(isActive: true)
    }

    @objc private func handlePlaceholderDidResignActive() {
        // Only if popup is not visible
        if !popupController.isVisible {
            keyProcessor.updateAppActiveState(isActive: false)
        }
    }

    // MARK: - PopupControllerDelegate

    func popupVisibilityDidChange(isVisible: Bool) {
        keyProcessor.updatePopupState(isVisible: isVisible)
        keyProcessor.updateAppActiveState(isActive: isVisible)  // Sync App Active
        AppActivationMonitor.shared.setPopupVisible(isVisible)
    }

    // MARK: - CollisionManagerDelegate & TriggerProcessorDelegate

    func triggerCollisionMatch(_ candidate: AbbreviationMatcher.MatchCandidate) {
        performTextReplacement(
            snippet: candidate.snippet,
            deleteLength: candidate.deleteLength,
            triggerMethod: candidate.triggerMethod + "_delayed"
        )
        bufferController.clear(reason: "Collision Triggered")
    }

    func performTextReplacement(
        snippet: SnippetEntry, deleteLength: Int, triggerMethod: String
    ) {
        // Delegate to Coordinator
        snippetExpansionCoordinator.performSnippetExpansion(
            snippet: snippet,
            fromPopup: false,
            deleteLength: deleteLength,
            triggerMethod: triggerMethod
        )

        // Invoke Callback (Success assumed if started?)
        // Ideally should be in success callback of Coordinator.
        // But for backward compatibility with `onPotentialAbbreviation`:
        callback(snippet.abbreviation)
    }

    // MARK: - Compatibility / Helpers (exposed for Tests etc)

    func clearBuffer() {
        bufferController.clear(reason: "External Request")
    }

    func getCurrentBuffer() -> String {
        return bufferController.getCurrentText()
    }

    func handleAppDeactivated() {
        if popupController.isVisible {
            popupController.hidePopup()
        }
    }
}
