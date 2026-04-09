import Cocoa
import Foundation

/// Coordinator for Snippet Expansion logic.
/// Handles the complexity of finding snippets, calculating delete lengths, and performing replacements.
class SnippetExpansionCoordinator: TextReplacementCoordinatorDelegate {

  // MARK: - Properties

  private let abbreviationMatcher: AbbreviationMatcher
  private let replacementCoordinator: TextReplacementCoordinator
  private let bufferController: BufferController

  // Callbacks to KeyEventMonitor
  var onReplacementStatusChanged: ((Bool) -> Void)?
  var onEventTapSuspensionRequested: (() -> Void)?
  var onEventTapResumptionRequested: (() -> Void)?
  var onExpansionSuccess: (() -> Void)?  // To clear buffer
  var onExpansionFailure: (() -> Void)?  // To clear buffer logic
  var onPopupHideRequested: (() -> Void)?

  // MARK: - Initialization

  init(bufferController: BufferController) {
    self.bufferController = bufferController
    self.abbreviationMatcher = AbbreviationMatcher()
    self.replacementCoordinator = TextReplacementCoordinator()

    self.replacementCoordinator.delegate = self
  }

  // MARK: - Public API

  func performSnippetExpansion(
    snippet: SnippetEntry,
    fromPopup: Bool,
    deleteLength: Int,
    referenceFrame: NSRect? = nil,
    triggerMethod: String = "unknown"
  ) {
    logD(
      "🔹 [ExpansionCoordinator] Performing Expansion: '\(snippet.abbreviation)' (Del: \(deleteLength))"
    )

    // Validation: Directory Check
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: snippet.filePath.path, isDirectory: &isDirectory) {
      if isDirectory.boolValue {
        logW(
          "🔹 ⚠️ [ExpansionCoordinator] Snippet path is a directory: \(snippet.filePath.lastPathComponent)"
        )
        return
      }
    } else {
      logW("🗿 🔹 ⚠️ [ExpansionCoordinator] Snippet file does not exist: \(snippet.filePath.path)")
      // Proceeding might be dangerous if content is needed, but replacementCoordinator handles it?
      // replacementCoordinator checks existence usually.
    }

    // Log content preview
    if let content = try? String(contentsOf: snippet.filePath, encoding: .utf8) {
      let truncated = content.count > 100 ? String(content.prefix(100)) + "..." : content
      logD("🗿 🔹    Content Preview: '\(truncated)'")
    }

    // Execute Replacement
    replacementCoordinator.performReplacement(
      snippet: snippet,
      fromPopup: fromPopup,
      deleteLength: deleteLength,
      referenceFrame: referenceFrame
    ) { [weak self] success, error in
      guard let self = self else { return }

      if success {
        logV("🗿 🔹 [ExpansionCoordinator] Replacement Success: '\(snippet.abbreviation)'")
        if !fromPopup {
          SnippetUsageManager.shared.logUsage(snippet: snippet, triggerMethod: triggerMethod)
        }

        self.onExpansionSuccess?()
      } else {
        logE("🗿 🔹 ❌ [ExpansionCoordinator] Replacement Failed: \(error ?? "Unknown Error")")
        self.onExpansionFailure?()
      }

      // Allow Popup to hide
      if fromPopup {
        self.onPopupHideRequested?()
      }
      // Even if not from popup, if popup was open, maybe close it?
      // Usually KeyMonitor handles popup closing via callback.
    }
  }

  /// Handles suffix-based expansion logic (delegates search to matcher)
  func handleSuffixExpansion(buffer: String, rule: RuleManager.CollectionRule) -> Bool {
    logV("🗿 🔹 [ExpansionCoordinator] Checking Suffix Expansion: Rule='\(rule.name)'")

    if let match = abbreviationMatcher.findBestMatch(in: buffer, rule: rule) {
      let matchedSnippet = match.snippet
      let matchLength = match.matchedLength

      logV("🗿 🔹    Match Found: '\(matchedSnippet.abbreviation)'")

      // Calculate Delete Length
      let settings = SettingsManager.shared.load()
      let baseBias = rule.triggerBias ?? settings.triggerBias
      let auxBias = AppSettingManager.shared.tuning.triggerBiasAux

      let calcResult = DeleteLengthManager.shared.calculate(
        snippet: matchedSnippet,
        matchedLength: matchLength,
        triggeredByKey: false,
        rule: rule,
        effectiveSuffix: "",
        triggerBias: baseBias,
        auxBias: auxBias
      )

      logV(
        "🗿 🔹    Delete Length Strategy: \(calcResult.strategy) (Len: \(calcResult.deleteLength))")

      performSnippetExpansion(
        snippet: matchedSnippet,
        fromPopup: false,
        deleteLength: calcResult.deleteLength,
        triggerMethod: "suffix"
      )
      return true
    } else {
      // Fallback: Trigger Bias Cleanup
      if rule.triggerBias != nil && rule.suffix != "`" && rule.suffix != " " {
        let deleteLength = buffer.count + rule.triggerBias!
        logV("🗿 🔹    No Match, but performing Rule Bias Cleanup (\(deleteLength) chars)")

        let manualEmptySnippet = SnippetEntry(
          id: UUID().uuidString,
          abbreviation: "",
          filePath: URL(fileURLWithPath: ""),
          folderName: "",
          fileName: "",
          description: nil,
          snippetDescription: "",
          content: "",
          tags: [],
          fileSize: 0,
          modificationDate: Date(),
          isActive: true
        )

        performSnippetExpansion(
          snippet: manualEmptySnippet,
          fromPopup: false,
          deleteLength: max(0, deleteLength),
          triggerMethod: "suffix_cleanup"
        )
        return true
      }
    }

    return false
  }

  // MARK: - Validation Delegates

  // Provide access to Matcher for other classes if needed
  func getAbbreviationMatcher() -> AbbreviationMatcher {
    return abbreviationMatcher
  }

  // MARK: - TextReplacementCoordinatorDelegate

  func replacementStatusDidChange(isReplacing: Bool) {
    onReplacementStatusChanged?(isReplacing)
  }

  func requestEventMonitoringSuspension() {
    onEventTapSuspensionRequested?()
  }

  func requestEventMonitoringResumption() {
    onEventTapResumptionRequested?()
  }
}
