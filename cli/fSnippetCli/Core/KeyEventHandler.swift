import Cocoa
import Foundation

/// Handler for Key Events.
/// Decides how to process a key event based on the current mode (Normal vs Popup).
/// Routes events to Buffer or Popup Controller.
class KeyEventHandler: KeyEventProcessorDelegate {

  // MARK: - Properties

  private let bufferController: BufferController
  private let popupController: PopupController
  private let expansionCoordinator: SnippetExpansionCoordinator
  private weak var keyEventProcessor: KeyEventProcessor?  // Reference to control Tap

  // Issue720_4: CollisionManager 호출 throttle (60Hz, 연속 키 입력 시 CPU 부하 감소)
  private var lastCollisionCheckTime: TimeInterval = 0
  private let collisionCheckInterval: TimeInterval = 1.0 / 60.0  // ~16ms

  private func shouldRunCollisionCheck() -> Bool {
    let now = CACurrentMediaTime()
    guard (now - lastCollisionCheckTime) >= collisionCheckInterval else { return false }
    lastCollisionCheckTime = now
    return true
  }

  // MARK: - Initialization

  init(
    bufferController: BufferController,
    popupController: PopupController,
    expansionCoordinator: SnippetExpansionCoordinator
  ) {
    self.bufferController = bufferController
    self.popupController = popupController
    self.expansionCoordinator = expansionCoordinator
  }

  // Method to set processor after initialization (circular dependency resolution)
  func setKeyEventProcessor(_ processor: KeyEventProcessor) {
    self.keyEventProcessor = processor
  }

  // MARK: - KeyEventProcessorDelegate

  func didDetectTriggerKey(_ buffer: String) {
    // Delegate to TriggerProcessor
    if let defaultKey = TriggerKeyManager.shared.defaultTriggerKey {
      _ = TriggerProcessor.shared.processTriggerKey(defaultKey, buffer: buffer)
    } else {
      // Fallback
      let settings = SettingsManager.shared.load()
      let defaultSymbol = settings.defaultSymbol
      let fallbackKey = EnhancedTriggerKey(
        id: "default_fallback",
        displayCharacter: defaultSymbol,
        keyCode: "0",
        usage: "0 (0x0000)",
        usagePage: "0 (0x0000)",
        modifiers: "",
        displayName: "Default Trigger (Fallback)",
        keySequence: defaultSymbol
      )
      _ = TriggerProcessor.shared.processTriggerKey(fallbackKey, buffer: buffer)
    }
  }

  func didDetectPopupKey() {
    handlePopupKeyDetected()
  }

  func handleKeyEventAndReturnSuccess(_ keyInfo: KeyEventInfo) -> Bool {
    // Duplicate check logic (handled by Processor usually, but double check?)

    // Mode switch
    if popupController.isVisible || popupController.actualVisibility {
      if !popupController.isVisible {
        logW("🔹 ⚠️ [KeyEventHandler] Popup Visibility Mismatch detected! Enforcing Popup Mode.")
      }
      handleKeyInPopupMode(keyInfo)
      return false  // Popup mode doesn't return "snippet expansion success" in this context usually
    } else {
      return handleKeyInNormalMode(keyInfo)
    }
  }

  func didTypeKey(_ keyInfo: KeyEventInfo) {
    _ = handleKeyEventAndReturnSuccess(keyInfo)
  }

  // ... (Previous methods)

  private func handleKeyInNormalMode(_ keyInfo: KeyEventInfo) -> Bool {

    // 1. Pre-process / Buffer

    var character = keyInfo.character

    // Issue 513: Token Synthesis for Special Keys
    if let def = SingleShortcutMapper.shared.getDefinition(for: keyInfo.keyCode), !def.name.isEmpty
    {
      let isNumpad = def.name.hasPrefix("keypad_")
      let isModifier = def.visualCount == 0

      if (character?.isEmpty ?? true) || isNumpad || isModifier {
        character = "{\(def.name)}"
        // logD("🔹 [Issue513] Synthesized Token: Code \(keyInfo.keyCode) -> '\(character ?? "nil")'")
      }
    }

    if let validChar = character, !validChar.isEmpty {
      var characterToken = validChar

      // Issue79: Shift normalization
      if keyInfo.modifiers.contains(.shift) {
        if keyInfo.keyCode == 43 && characterToken == "," {
          characterToken = "<"
        } else if keyInfo.keyCode == 47 && characterToken == "." {
          characterToken = ">"
        }
      }

      // Pending Collision Check (Issue720_4: 60Hz throttle - 연속 입력 시 CPU 부하 감소)
      if let char = keyInfo.character, !char.isEmpty, shouldRunCollisionCheck() {
        CollisionManager.shared.validatePendingCollision(
          extensionChar: char, currentBuffer: bufferController.getCurrentText())
      }

      let sanitizedChar = KeyRenderingManager.shared.sanitizeInputCharacter(characterToken)

      // Visual Key Check
      let isVisualKey: Bool
      if sanitizedChar.hasPrefix("{") && sanitizedChar.hasSuffix("}") {
        let tokenName = SingleShortcutMapper.shared.unwrap(sanitizedChar)
        if tokenName.hasPrefix("right_") || tokenName.hasPrefix("keypad_")
          || isFunctionKey(tokenName)
        {
          isVisualKey = true
        } else {
          isVisualKey = SingleShortcutMapper.shared.getVisualCount(for: tokenName) > 0
        }
      } else {
        isVisualKey = true
      }

      // Append to Buffer
      if !sanitizedChar.isEmpty && isVisualKey {
        bufferController.append(sanitizedChar)
        _ = bufferController.extractSearchTerm()

        // Logging
        let ignoredLogKeys: Set<UInt16> = [55, 56, 59, 58]
        if !ignoredLogKeys.contains(keyInfo.keyCode) {
          logD(
            "🔹⌨️ [Typing] Key: \(sanitizedChar.replacingOccurrences(of: "\n", with: "\\n")) (Code: \(keyInfo.keyCode))"
          )
        }
      }

      let currentBuffer = bufferController.getCurrentText()  // Updated buffer

      // 2. Role Resolution (ShortcutMgr)
      var shouldClearBufferFallback = false
      var allowRoleFallthrough = false

      if let role = resolveKeyRole(keyInfo) {
        // logD("🔹🧹 [KeyEventHandler] Role: \(role.type) (ID: \(role.id))")

        switch role.type {
        case .folderSuffix:
          handleFolderSuffixRole(
            role, currentBuffer: currentBuffer, allowRoleFallthrough: &allowRoleFallthrough)

        case .folderPrefix:
          if handleFolderPrefixRole(
            role, currentBuffer: currentBuffer, allowRoleFallthrough: &allowRoleFallthrough)
          {
            return true  // Popup launched logic considered handled? Or success?
            // handleKeyEventAndReturnSuccess usually implies "snippet expanded".
            // But let's return true to indicate "Something significant happened".
          }

        case .appShortcut:
          handleAppShortcut(role)
          bufferController.removeLast()
          CollisionManager.shared.cancelPendingCollision()
          return true  // Consumed

        case .triggerKey:
          if let userInfo = role.userInfo,
            let triggerKey = userInfo["triggerKey"] as? EnhancedTriggerKey
          {

            if triggerKey.isNonVisualTrigger {
              bufferController.removeLast()
            }
            // Delegate to TriggerProcessor
            if TriggerProcessor.shared.processTriggerKey(
              triggerKey, buffer: bufferController.getCurrentText())
            {
              return true
            }
          }

        case .bufferClear:
          let keySpec = keyInfo.normalizedKeySpec()
          if RuleManager.shared.isPotentialSequence(
            currentBuffer: currentBuffer, nextKeySpec: keySpec)
          {
            shouldClearBufferFallback = false
            allowRoleFallthrough = true
          } else {
            shouldClearBufferFallback = true
            allowRoleFallthrough = true
          }

        case .popupNavigation:
          break
        }

        if !allowRoleFallthrough && role.type != .folderPrefix && role.type != .folderSuffix {
          return true  // Consumed
        }
      }

      // 3. Dynamic Suffix Rules (TriggerProcessor)
      // TriggerProcessor is responsible for calling performTextReplacement if loop matches
      let triggerAction = TriggerProcessor.shared.checkForSuffixMatches(
        buffer: bufferController.getCurrentText(), keyInfo: keyInfo)

      switch triggerAction {
      case .consumed:
        return true
      case .matchPassthrough:
        return true  // ? Monitor returned false, effectively
      case .none:
        break
      }

      if shouldClearBufferFallback {
        bufferController.clear(reason: "Suffix Fallback Clear")
      }

    } else {
      // Modifier Only Logic (Empty Char)
      let activeTriggerKeys = TriggerKeyManager.shared.activeTriggerKeys
      let matchingTrigger = activeTriggerKeys.first { triggerKey in
        triggerKey.hardwareKeyCode == keyInfo.keyCode
      }

      if let triggerKey = matchingTrigger {
        logD("🔹 [KeyEventHandler] Modifier Trigger: \(triggerKey.displayName)")
        if TriggerProcessor.shared.processTriggerKey(
          triggerKey, buffer: bufferController.getCurrentText())
        {
          return true
        }
      }
    }

    return false
  }

  func didReceiveInterceptedArrowKey(_ keyCode: UInt16) {
    // Forward to Popup logic
    switch keyCode {
    case 126:  // Up
      popupController.moveSelectionUp()
    case 125:  // Down
      popupController.moveSelectionDown()
    default:
      break
    }
  }

  func didReceiveInterceptedEscapeKey() {
    popupController.hidePopup()
    bufferController.clear(reason: "Escape Key")
  }

  func didTriggerShortcut(_ shortcut: ShortcutItem) {
    // Handle App Shortcuts via Delegate or Direct Execution
    if shortcut.type == .appShortcut {
      handleAppShortcut(shortcut)
    }
  }

  // MARK: - Logic

  private func handleKeyInPopupMode(_ keyInfo: KeyEventInfo) {
    // Popup Mode Logic (No buffering, trust TextField)

    switch keyInfo.type {
    case .backspace:
      // Handled by TextField
      break

    case .regular, .special, .command, .control, .option, .navigation, .function, .modifier:
      // Lateral Navigation (Left/Right) -> Close Popup
      if [123, 124].contains(keyInfo.keyCode) {
        logI("🔹 [KeyEventHandler][Popup] Left/Right Arrow -> Close Popup")
        popupController.hidePopup()
        bufferController.clear(reason: "Popup Lateral Nav")
        return
      }

      if let character = keyInfo.character {
        // Enter Key -> Select
        if character == "\n" {
          logV("🔹 [PopupMode] Enter Key -> Select")
          popupController.selectCurrentItem()
          return
        }

        // Buffer Clear Keys (Close Popup?)
        let clearKeys = AppSettingManager.shared.bufferClearKeys
        guard !character.isEmpty else { return }

        // Tab -> Exception (Edit Trigger)
        if character == "\t" {
          return
        }

        let firstChar = String(character.prefix(1))
        if clearKeys.contains(Character(firstChar)) {
          // Suffix Guard
          let suffixes = PSKeyManager.shared.getSuffixes()
          let potentialSuffixMatch = suffixes.contains { suffix in
            !suffix.isEmpty && suffix.contains(firstChar)
          }

          if potentialSuffixMatch {
            logV("🔹 [Popup/SuffixGuard] Buffer Clear Key but Suffix part -> Keep Popup")
          } else {
            popupController.hidePopup()
            bufferController.clear(reason: "Popup Clear Key")
            return
          }
        }
      }
    }
  }

  private func handleKeyInNormalMode(_ keyInfo: KeyEventInfo) {

    // 1. Pre-process / Buffer

    var character = keyInfo.character

    // Issue 513: Token Synthesis for Special Keys
    if let def = SingleShortcutMapper.shared.getDefinition(for: keyInfo.keyCode), !def.name.isEmpty
    {
      let isNumpad = def.name.hasPrefix("keypad_")
      let isModifier = def.visualCount == 0

      if (character?.isEmpty ?? true) || isNumpad || isModifier {
        character = "{\(def.name)}"
        logD("🔹 [Issue513] Synthesized Token: Code \(keyInfo.keyCode) -> '\(character ?? "nil")'")
      }
    }

    if let validChar = character, !validChar.isEmpty {
      var characterToken = validChar

      // Issue79: Shift normalization
      if keyInfo.modifiers.contains(.shift) {
        if keyInfo.keyCode == 43 && characterToken == "," {
          characterToken = "<"
        } else if keyInfo.keyCode == 47 && characterToken == "." {
          characterToken = ">"
        }
      }

      // Pending Collision Check (Issue720_4: 60Hz throttle - 연속 입력 시 CPU 부하 감소)
      if let char = keyInfo.character, !char.isEmpty, shouldRunCollisionCheck() {
        CollisionManager.shared.validatePendingCollision(
          extensionChar: char, currentBuffer: bufferController.getCurrentText())
      }

      let sanitizedChar = KeyRenderingManager.shared.sanitizeInputCharacter(characterToken)

      // Visual Key Check
      let isVisualKey: Bool
      if sanitizedChar.hasPrefix("{") && sanitizedChar.hasSuffix("}") {
        let tokenName = SingleShortcutMapper.shared.unwrap(sanitizedChar)
        if tokenName.hasPrefix("right_") || tokenName.hasPrefix("keypad_")
          || isFunctionKey(tokenName)
        {
          isVisualKey = true
        } else {
          isVisualKey = SingleShortcutMapper.shared.getVisualCount(for: tokenName) > 0
        }
      } else {
        isVisualKey = true
      }

      // Append to Buffer
      if !sanitizedChar.isEmpty && isVisualKey {
        bufferController.append(sanitizedChar)
        _ = bufferController.extractSearchTerm()

        // Logging
        let ignoredLogKeys: Set<UInt16> = [55, 56, 59, 58]
        if !ignoredLogKeys.contains(keyInfo.keyCode) {
          logD("🔹⌨️ [Typing] Key: \(sanitizedChar) (Code: \(keyInfo.keyCode))")
        }
      }

      let currentBuffer = bufferController.getCurrentText()  // Updated buffer

      // 2. Role Resolution (ShortcutMgr)
      var shouldClearBufferFallback = false
      var allowRoleFallthrough = false

      if let role = resolveKeyRole(keyInfo) {
        // logD("🔹🧹 [KeyEventHandler] Role: \(role.type) (ID: \(role.id))")

        switch role.type {
        case .folderSuffix:
          handleFolderSuffixRole(
            role, currentBuffer: currentBuffer, allowRoleFallthrough: &allowRoleFallthrough)

        case .folderPrefix:
          if handleFolderPrefixRole(
            role, currentBuffer: currentBuffer, allowRoleFallthrough: &allowRoleFallthrough)
          {
            return  // Popup launched
          }

        case .appShortcut:
          handleAppShortcut(role)
          bufferController.removeLast()
          CollisionManager.shared.cancelPendingCollision()
          return  // Consumed

        case .triggerKey:
          if let userInfo = role.userInfo,
            let triggerKey = userInfo["triggerKey"] as? EnhancedTriggerKey
          {

            if triggerKey.isNonVisualTrigger {
              bufferController.removeLast()
            }
            // Delegate to TriggerProcessor
            if TriggerProcessor.shared.processTriggerKey(
              triggerKey, buffer: bufferController.getCurrentText())
            {
              return
            }
          }

        case .bufferClear:
          let keySpec = keyInfo.normalizedKeySpec()
          if RuleManager.shared.isPotentialSequence(
            currentBuffer: currentBuffer, nextKeySpec: keySpec)
          {
            shouldClearBufferFallback = false
            allowRoleFallthrough = true
          } else {
            shouldClearBufferFallback = true
            allowRoleFallthrough = true
          }

        case .popupNavigation:
          break
        }

        if !allowRoleFallthrough && role.type != .folderPrefix && role.type != .folderSuffix {
          return  // Consumed
        }
      }

      // 3. Dynamic Suffix Rules (TriggerProcessor)
      // TriggerProcessor is responsible for calling performTextReplacement if loop matches
      let triggerAction = TriggerProcessor.shared.checkForSuffixMatches(
        buffer: bufferController.getCurrentText(), keyInfo: keyInfo)

      switch triggerAction {
      case .consumed:
        return
      case .matchPassthrough:
        return  // ? Monitor returned false, effectively
      case .none:
        break
      }

      if shouldClearBufferFallback {
        bufferController.clear(reason: "Suffix Fallback Clear")
      }

    } else {
      // Modifier Only Logic (Empty Char)
      // Optimized search using TriggerKeyManager (Issue 583_10)
      if let triggerKey = TriggerKeyManager.shared.matchTriggerKey(
        keyCode: keyInfo.keyCode,
        modifiers: keyInfo.modifiers.rawValue,
        character: nil
      ) {
        logD("🔹 [KeyEventHandler] Modifier Trigger: \(triggerKey.displayName)")
        _ = TriggerProcessor.shared.processTriggerKey(
          triggerKey, buffer: bufferController.getCurrentText())
      }
    }
  }

  private func handlePopupKeyDetected() {
    let searchTerm = bufferController.extractSearchTerm()
    let settings = SettingsManager.shared.load()
    let searchScope = settings.popupSearchScope

    let candidates: [SnippetEntry]

    let matcher = expansionCoordinator.getAbbreviationMatcher()

    switch searchScope {
    case .abbreviation:
      candidates = matcher.findSnippetCandidates(searchTerm: searchTerm)
    case .name, .content:
      if searchTerm.isEmpty {
        candidates = matcher.getAllSnippets()
      } else {
        candidates = SnippetIndexManager.shared.search(
          term: searchTerm, scope: searchScope, maxResults: 100)
      }
    }

    let cursorRect = CursorTracker.shared.getCursorRect()

    // ✅ Issue 714: Capture initialSearchTerm before popup opens
    let initialSearchTerm = searchTerm

    popupController.showPopup(
      with: candidates,
      searchTerm: searchTerm,
      cursorRect: cursorRect,
      onSelection: { [weak self] snippet, finalSearchTerm, popupFrame in
        // ✅ Issue 714: Use getVisualLength of the *initialSearchTerm* because
        // characters typed inside the popup don't exist in the active application's buffer.
        let visualLength = DeleteLengthManager.shared.getVisualLength(of: initialSearchTerm)

        // Perform Expansion
        self?.expansionCoordinator.performSnippetExpansion(
          snippet: snippet,
          fromPopup: true,
          deleteLength: visualLength,
          referenceFrame: popupFrame
        )
      }
    )
  }

  // MARK: - Helper Logic

  private func resolveKeyRole(_ keyInfo: KeyEventInfo) -> ShortcutItem? {
    if keyInfo.keyCode == 14 && keyInfo.modifiers.contains(.control)
      && keyInfo.modifiers.contains(.shift)
    {
      return nil
    }
    let keySpec = keyInfo.normalizedKeySpec()
    return ShortcutMgr.shared.resolve(keySpec: keySpec)
  }

  private func handleAppShortcut(_ item: ShortcutItem) {
    logI("🔹 [KeyEventHandler] App Shortcut: \(item.id)")
    DispatchQueue.main.async {
      if item.id == "history.viewer.hotkey" {
        HistoryViewerManager.shared.show()
      } else if item.id == "history.pause.hotkey" {
        // Toggle logic duplicated or access Monitor?
        // Ideally Access a Manager. But Toggle logic was in Monitor.
        // We can notify Monitor or just implement it here (it uses ParamsManager).
        // NotificationCenter.default.post?
        // Or implement toggle logic.
        let prefs = PreferencesManager.shared
        let current = prefs.bool(forKey: "history.isPaused", defaultValue: false)
        let newState = !current
        prefs.set(newState, forKey: "history.isPaused")
        NotificationCenter.default.post(
          name: NSNotification.Name("historyPauseStateChanged"), object: newState)
        let l10n = LocalizedStringManager.shared
        let message = newState ? l10n.string("toast.clipboard_paused") : l10n.string("toast.clipboard_resumed")
        let icon = newState ? "pause.fill" : "play.fill"
        ToastManager.shared.showToast(message: message, iconName: icon)
      } else if item.id == "snippet.popup.hotkey" {
        if self.popupController.isVisible {
          self.popupController.hidePopup()
        } else {
          self.handlePopupKeyDetected()
        }
      } else if item.id == "settings.hotkey" {
        // Issue8: 설정창은 유료 버전 전용 기능
        PaidAppManager.shared.handlePaidFeature()
      }
    }
  }

  private func isFunctionKey(_ tokenName: String) -> Bool {
    guard tokenName.hasPrefix("f"), tokenName.count >= 2 else { return false }
    return Int(tokenName.dropFirst()) != nil
  }

  // MARK: - Folder Logic (Condensed)

  private func handleFolderSuffixRole(
    _ role: ShortcutItem, currentBuffer: String, allowRoleFallthrough: inout Bool
  ) {
    let suffixKey = role.keySpec
    let targetFolders = ShortcutMgr.shared.registeredShortcuts
      .filter { $0.type == .folderSuffix && $0.keySpec == suffixKey }
      .compactMap { $0.userInfo?["folderName"] as? String }

    let foldersToCheck =
      targetFolders.isEmpty
      ? (role.userInfo?["folderName"] as? String).map { [$0] } ?? [] : targetFolders

    if foldersToCheck.isEmpty { return }

    // Exact Match
    for folderName in foldersToCheck {
      if let rule = RuleManager.shared.getRule(for: folderName),
        expansionCoordinator.getAbbreviationMatcher().findBestMatch(in: currentBuffer, rule: rule)
          != nil
      {
        return  // Fallthrough to generic logic (TriggerProcessor)
      }
    }

    // Candidates
    var allCandidates: [SnippetEntry] = []
    let allSnippets = expansionCoordinator.getAbbreviationMatcher().getAllSnippets()

    for folderName in foldersToCheck {
      let folderSnippets = allSnippets.filter {
        $0.folderName.caseInsensitiveCompare(folderName) == .orderedSame
      }
      var searchBuffer = currentBuffer
      if let rule = RuleManager.shared.getRule(for: folderName) {
        let suffix = rule.suffix
        if !suffix.isEmpty && currentBuffer.hasSuffix(suffix) {
          searchBuffer = String(currentBuffer.dropLast(suffix.count))
        }
      }
      if !searchBuffer.isEmpty {
        let candidates = folderSnippets.filter {
          $0.abbreviation.lowercased().hasPrefix(searchBuffer.lowercased())
        }
        allCandidates.append(contentsOf: candidates)
      }
    }

    if allCandidates.isEmpty {
      let fallbackTriggerKey = EnhancedTriggerKey.from(keySpec: suffixKey)
      if TriggerProcessor.shared.processTriggerKey(fallbackTriggerKey, buffer: currentBuffer) {
        return
      }
      return  // Fallthrough
    }

    // Open Popup
    bufferController.removeLast()  // Remove trigger
    let cursorRect = CursorTracker.shared.getCursorRect()
    // ✅ Issue 604 Fix: Use fresh buffer (without trigger) for search term
    let freshBuffer = bufferController.getCurrentText()
    popupController.showPopup(
      with: allCandidates, searchTerm: freshBuffer, cursorRect: cursorRect
    ) { [weak self] (snippet: SnippetEntry, term: String, frame: NSRect?) in
      self?.expansionCoordinator.performSnippetExpansion(
        snippet: snippet, fromPopup: true, deleteLength: term.count, referenceFrame: frame)
    }
  }

  private func handleFolderPrefixRole(
    _ role: ShortcutItem, currentBuffer: String, allowRoleFallthrough: inout Bool
  ) -> Bool {
    guard let folderName = role.userInfo?["folderName"] as? String else { return false }

    let triggerKey = role.keySpec
    // Context Check (Start of word)
    let triggerLength = triggerKey.count
    let preTriggerContent =
      currentBuffer.hasSuffix(triggerKey)
      ? currentBuffer.dropLast(triggerLength) : currentBuffer.dropLast()
    let isStartOfWord = preTriggerContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

    if !isStartOfWord {
      allowRoleFallthrough = true
      return false
    }

    // Remove Trigger
    bufferController.removeLast()

    let allSnippets = expansionCoordinator.getAbbreviationMatcher().getAllSnippets()
    let folderSnippets = allSnippets.filter {
      $0.folderName.caseInsensitiveCompare(folderName) == .orderedSame
    }

    if folderSnippets.isEmpty { return true }

    let cursorRect = CursorTracker.shared.getCursorRect()
    popupController.showPopup(with: folderSnippets, searchTerm: "", cursorRect: cursorRect) {
      [weak self] (snippet: SnippetEntry, term: String, frame: NSRect?) in
      self?.expansionCoordinator.performSnippetExpansion(
        snippet: snippet, fromPopup: true, deleteLength: term.count, referenceFrame: frame)
    }
    return true
  }
}
