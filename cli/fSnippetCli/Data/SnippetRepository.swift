import Cocoa
import Foundation

/// 스니펫 파일 시스템 접근 및 데이터 관리(Repository Pattern)
class SnippetRepository {
  // MARK: - Properties

  // Legacy support for shared access if needed internally, though typically accessed via FragmentFileManager
  static let shared = SnippetRepository()

  private(set) var rootFolderURL: URL
  private(set) var snippetMap: [String: [String]] = [:]

  private let fileManager = FileManager.default
  private var folderWatcher: SnippetFolderWatcher?
  private var accessedFolderURL: URL?  // Security Scope 참조

  private var settingsObserver: NSObjectProtocol?

  // Issue 546: Reload Throttling states
  private var lastRebuildTime: Date?
  private var lastRebuildDuration: TimeInterval = 0.0

  // Dependencies
  private let calculator = AbbreviationCalculator.shared

  // MARK: - Initialization

  init(rootURL: URL? = nil) {
    if let url = rootURL {
      self.rootFolderURL = url
      self.folderWatcher = nil
      self.accessedFolderURL = nil
      logI("📂 [SnippetRepository] Initialized with custom rootURL: \(url.path)")
      return
    }

    let settings = SettingsManager.shared.load()
    let expandedPath = (settings.basePath as NSString).expandingTildeInPath

    var tempAccessedURL: URL? = nil

    if let bookmarkStr = settings.basePathBookmark,
      let bookmarkData = Data(base64Encoded: bookmarkStr)
    {
      var isStale = false
      do {
        let resolvedURL = try URL(
          resolvingBookmarkData: bookmarkData, options: .withSecurityScope,
          relativeTo: nil, bookmarkDataIsStale: &isStale)

        if resolvedURL.startAccessingSecurityScopedResource() {
          logV("📂 [SnippetRepository] Security Scoped 접근 성공: \(resolvedURL.path)")
          tempAccessedURL = resolvedURL
        }
      } catch {
        logE("📂 ❌ [SnippetRepository] Bookmark Resolve Error: \(error)")
      }
    }

    if !FileManager.default.fileExists(atPath: expandedPath) {
      logE("📂 ❌ [SnippetRepository] basePath가 존재하지 않음: \(expandedPath)")

      if let url = tempAccessedURL {
        url.stopAccessingSecurityScopedResource()
        tempAccessedURL = nil
      }

      // Fallback
      let defaultPath = (SnippetSettings.default.basePath as NSString).expandingTildeInPath
      self.rootFolderURL = URL(fileURLWithPath: defaultPath)

      // Fix Settings (This might ideally belong in a Settings Service, but kept here for now)
      // Note: In a pure repo, we might trigger an event, but let's keep logic close to original
    } else {
      self.rootFolderURL = URL(fileURLWithPath: expandedPath)
    }

    self.accessedFolderURL = tempAccessedURL

    setupObservers()
  }

  deinit {
    stopFolderWatching()
    if let url = accessedFolderURL {
      url.stopAccessingSecurityScopedResource()
    }
    if let observer = settingsObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  private func setupObservers() {
    settingsObserver = NotificationCenter.default.addObserver(
      forName: .settingsDidChange, object: nil, queue: .main
    ) { [weak self] notification in
      self?.handleSettingsDidChange(notification)
    }
  }

  private func handleSettingsDidChange(_ notification: Notification) {
    if let settings = notification.object as? SnippetSettings {
      let newPath = (settings.basePath as NSString).expandingTildeInPath
      if newPath != self.rootFolderURL.path {
        updateRootFolder(newPath)
      }
    }
  }

  func updateRootFolder(_ path: String) {
    let expandedPath = (path as NSString).expandingTildeInPath
    self.rootFolderURL = URL(fileURLWithPath: expandedPath)

    // Resolve Bookmark again
    let settings = SettingsManager.shared.load()
    resolveBookmark(from: settings)

    // RuleManager update
    RuleManager.shared.ensureRuleFile(at: expandedPath)

    // Alfred check
    // Note: isAlfredFolder logic is moved to Repository or kept in Manager?
    // Let's keep file system check methods here.
    if isAlfredFolder(expandedPath) {
      _ = RuleManager.shared.loadRuleFile(at: expandedPath)
    } else {
      RuleManager.shared.clearRules()
    }

    restartFolderWatching()
    NotificationCenter.default.post(name: .snippetFoldersDidChange, object: nil)
  }

  private func resolveBookmark(from settings: SnippetSettings) {
    if let oldURL = accessedFolderURL {
      oldURL.stopAccessingSecurityScopedResource()
      accessedFolderURL = nil
    }
    guard let bookmarkStr = settings.basePathBookmark,
      let bookmarkData = Data(base64Encoded: bookmarkStr)
    else { return }

    var isStale = false
    do {
      let resolvedURL = try URL(
        resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil,
        bookmarkDataIsStale: &isStale)
      if resolvedURL.startAccessingSecurityScopedResource() {
        if resolvedURL.standardizedFileURL.path == self.rootFolderURL.standardizedFileURL.path {
          accessedFolderURL = resolvedURL
        } else {
          resolvedURL.stopAccessingSecurityScopedResource()
          logW(
            "📂 ❌ [SnippetRepository] Bookmark resolves to different path (\(resolvedURL.path)) than expected (\(self.rootFolderURL.path)). Discarding bookmark."
          )
        }
      }
    } catch {
      logE("📂 ❌ [SnippetRepository] Bookmark Resolve Error: \(error)")
    }
  }

  // MARK: - File System Queries

  var accessedURL: URL {
    return accessedFolderURL ?? rootFolderURL
  }

  func isAlfredFolder(_ folderPath: String = "") -> Bool {
    let targetPath = folderPath.isEmpty ? rootFolderURL.path : folderPath
    let mdPath = targetPath + "/_rule.md"
    if fileManager.fileExists(atPath: mdPath) { return true }
    let ymlPath = targetPath + "/_rule.yml"
    return fileManager.fileExists(atPath: ymlPath)
  }

  func getSnippetFolders() -> [URL] {
    guard fileManager.fileExists(atPath: rootFolderURL.path) else { return [] }
    do {
      let contents = try fileManager.contentsOfDirectory(
        at: rootFolderURL, includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles])
      return contents.filter { url in
        guard let resource = try? url.resourceValues(forKeys: [.isDirectoryKey]),
          let isDir = resource.isDirectory
        else { return false }
        let name = url.lastPathComponent
        return isDir && name != "_stats" && name != "z_old"
      }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    } catch {
      logW("📂 ❌ [SnippetRepository] Failed to list folders: \(error)")
      return []
    }
  }

  func getSnippetFiles(in folder: URL) -> [URL] {
    do {
      let contents = try fileManager.contentsOfDirectory(
        at: folder, includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles])
      return contents.filter { url in
        guard let resource = try? url.resourceValues(forKeys: [.isDirectoryKey]),
          let isDir = resource.isDirectory
        else { return false }
        if isDir { return false }
        if FileUtilities.isBinaryFile(url) { return false }
        return true
      }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    } catch {
      return []
    }
  }

  private let supportedExtensions: Set<String> = [
    "txt", "text", "md", "markdown",
    "swift", "py", "js", "ts", "html", "css",
    "json", "xml", "yml", "yaml",
    "sh", "bash", "zsh", "fish", "ps1", "bat", "cmd",
  ]

  func isSupportedFile(_ url: URL) -> Bool {
    let ext = url.pathExtension.lowercased()
    return supportedExtensions.contains(ext) || ext.isEmpty
  }

  func isExcludedFile(_ file: URL, in folderName: String, settings: SnippetSettings? = nil) -> Bool {
    let fileName = file.lastPathComponent
    // Issue720_3: settings 파라미터로 외부 캐시 주입 가능 (loadAllSnippets에서 1회만 로드)
    let s = settings ?? SettingsManager.shared.load()
    if s.excludedFiles.contains(fileName) { return true }
    for (key, files) in s.folderExcludedFiles {
      if key.caseInsensitiveCompare(folderName) == .orderedSame {
        if files.contains(fileName) { return true }
      }
    }
    return false
  }

  // MARK: - Data Management (Cache)

  func loadAllSnippets(reason: String = "App/Manual", force: Bool = false) {
    if !force {
      if let last = lastRebuildTime {
        let elapsed = Date().timeIntervalSince(last)
        let dynamicWait = lastRebuildDuration * 100.0
        let requiredWait = max(120.0, dynamicWait)
        if elapsed < requiredWait {
          let remains = Int(requiredWait - elapsed)
          logD("📂 ⚠️ [SnippetRepository] 리로드 스로틀링 중 (남은 시간: \(remains)초) - 사유: \(reason)")
          return
        }
      }
    }

    let startTime = CFAbsoluteTimeGetCurrent()
    logI("📂 [SnippetRepository] 스니펫 전체 로드 시작 (사유: \(reason)\(force ? ", 강제" : ""))")
    snippetMap.removeAll()
    _ = RuleManager.shared.loadRuleFile(at: rootFolderURL.path)

    // Issue720_3: Settings를 1회만 로드하여 폴더/파일 루프에서 재사용 (매번 로드 방지)
    let cachedSettings = SettingsManager.shared.load()

    let folders = getSnippetFolders()
    for folder in folders {
      let folderName = folder.lastPathComponent
      let files = getSnippetFiles(in: folder)

      for file in files {
        if isExcludedFile(file, in: folderName, settings: cachedSettings) { continue }

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: file.path, isDirectory: &isDirectory) {
          if isDirectory.boolValue { continue }
        }
        if file.lastPathComponent == "Data" { continue }

        // Use AbbreviationCalculator
        let abbreviation = calculator.getAbbreviation(for: file)
          .precomposedStringWithCanonicalMapping
        guard !abbreviation.isEmpty else { continue }

        let key = abbreviation
        let baseFileName = file.deletingPathExtension().lastPathComponent
        let hasEmptyKeyword = baseFileName.hasPrefix("===")

        if var existingPaths = snippetMap[key] {
          if let existingIndex = existingPaths.firstIndex(where: { path in
            let existingFolder = URL(fileURLWithPath: path).deletingLastPathComponent()
              .lastPathComponent
            return existingFolder == folderName
          }) {
            if !hasEmptyKeyword {
              // Log or handle duplicate in same folder
            }
            existingPaths[existingIndex] = file.path
            snippetMap[key] = existingPaths
          } else {
            snippetMap[key]?.append(file.path)
          }
        } else {
          snippetMap[key] = [file.path]
        }
      }
    }

    logI("📂 [SnippetRepository] Loaded \(snippetMap.count) snippets.")
    NotificationCenter.default.post(name: .snippetFoldersDidChange, object: nil)
    SnippetIndexManager.shared.rebuildIndex(basePath: rootFolderURL.path) { [weak self] _ in
      let endTime = CFAbsoluteTimeGetCurrent()
      self?.lastRebuildDuration = endTime - startTime
      self?.lastRebuildTime = Date()
    }
  }

  func clearAllSnippets() {
    snippetMap.removeAll()
  }

  // MARK: - CRUD Operations

  func createSnippetInFolder(folder: String, name: String, keyword: String, content: String) -> Bool
  {
    let folderPath = rootFolderURL.appendingPathComponent(folder).path
    if !fileManager.fileExists(atPath: folderPath) {
      _ = createFolder(folderName: folder)
    }
    return createSnippet(folder: folder, name: name, keyword: keyword, content: content)
  }

  func createSnippet(folder: String, name: String, keyword: String, content: String) -> Bool {
    let folderURL = accessedURL.appendingPathComponent(folder)
    let filePath = calculator.calculateDetailFilePath(
      rootFolderURL: accessedURL, folder: folder, name: name, keyword: keyword)
    let fileURL = URL(fileURLWithPath: filePath)

    do {
      if !fileManager.fileExists(atPath: folderURL.path) { return false }
      if fileManager.fileExists(atPath: fileURL.path) { return false }

      try content.write(to: fileURL, atomically: true, encoding: .utf8)
      updateIncremental(for: fileURL, isDelete: false)
      return true
    } catch {
      logE("📂 ❌ [SnippetRepository] Create failed: \(error)")
      return false
    }
  }

  func updateSnippet(
    originalItem: SnippetItem, newFolder: String?, newName: String, newKeyword: String,
    newContent: String
  ) -> Bool {
    let currentFolderURL = URL(fileURLWithPath: originalItem.filePath).deletingLastPathComponent()
    let targetFolderURL =
      newFolder != nil ? accessedURL.appendingPathComponent(newFolder!) : currentFolderURL

    let newFilePath = calculator.calculateDetailFilePath(
      rootFolderURL: accessedURL, folder: newFolder ?? currentFolderURL.lastPathComponent,
      name: newName, keyword: newKeyword)
    let newFileURL = URL(fileURLWithPath: newFilePath)
    let originalFileURL = URL(fileURLWithPath: originalItem.filePath)

    do {
      if newFolder != nil && !fileManager.fileExists(atPath: targetFolderURL.path) {
        try fileManager.createDirectory(
          at: targetFolderURL, withIntermediateDirectories: true, attributes: nil)
      }

      if newFileURL.path != originalFileURL.path && !originalItem.filePath.isEmpty {
        if fileManager.fileExists(atPath: newFileURL.path) {
          // Check logic from original - if simple case change, might pass, else fail
          let originalExists = fileManager.fileExists(atPath: originalFileURL.path)
          if !originalExists { return false }
          // If target exists and not same file (inode check hard here, rely on path), fail
          // But standard FileManager move fails if exists.
          // Let's assume fail for now unless exact match
        }

        if fileManager.fileExists(atPath: originalFileURL.path) {
          try fileManager.moveItem(at: originalFileURL, to: newFileURL)
        }
      }

      try newContent.write(to: newFileURL, atomically: true, encoding: .utf8)
      
      if newFileURL.path != originalFileURL.path && !originalItem.filePath.isEmpty {
          updateIncremental(for: originalFileURL, isDelete: true)
      }
      updateIncremental(for: newFileURL, isDelete: false)
      return true
    } catch {
      logE("📂 ❌ [SnippetRepository] Update failed: \(error)")
      return false
    }
  }

  func deleteSnippet(folder: String, name: String) -> Bool {
    let folderURL = accessedURL.appendingPathComponent(folder)
    let fileName = name.hasSuffix(".txt") ? name : "\(name).txt"
    let fileURL = folderURL.appendingPathComponent(fileName)

    do {
      if !fileManager.fileExists(atPath: fileURL.path) { return false }
      try fileManager.removeItem(at: fileURL)
      updateIncremental(for: fileURL, isDelete: true)
      return true
    } catch {
      return false
    }
  }

  func deleteFile(at path: String) {
    do {
      try fileManager.removeItem(atPath: path)
      updateIncremental(for: URL(fileURLWithPath: path), isDelete: true)
    } catch {
      logE("📂 ❌ [SnippetRepository] Delete file failed: \(error)")
    }
  }

  // MARK: - Folder Operations

  func createFolder(folderName: String) -> Bool {
    let folderURL = accessedURL.appendingPathComponent(folderName)
    do {
      if fileManager.fileExists(atPath: folderURL.path) { return true }
      try fileManager.createDirectory(
        at: folderURL, withIntermediateDirectories: true, attributes: nil)
      loadAllSnippets(reason: "createFolder", force: true)  // Issue 704: 즉시 리빌드
      return true
    } catch {
      return false
    }
  }

  func renameFolder(oldName: String, newName: String) -> Bool {
    let oldURL = accessedURL.appendingPathComponent(oldName)
    let newURL = accessedURL.appendingPathComponent(newName)
    do {
      if !fileManager.fileExists(atPath: oldURL.path) { return false }
      if fileManager.fileExists(atPath: newURL.path) { return false }
      try fileManager.moveItem(at: oldURL, to: newURL)
      loadAllSnippets(reason: "renameFolder", force: true)  // Issue 704: 즉시 리빌드
      return true
    } catch {
      return false
    }
  }

  func deleteFolder(folderName: String) -> Bool {
    let folderURL = accessedURL.appendingPathComponent(folderName)
    do {
      if !fileManager.fileExists(atPath: folderURL.path) { return false }
      try fileManager.removeItem(at: folderURL)
      loadAllSnippets(reason: "deleteFolder", force: true)  // 폴더 단위는 전체 리빌드 허용
      return true
    } catch {
      return false
    }
  }

  // MARK: - 증분 업데이트 전용

  private func updateIncremental(for fileURL: URL, isDelete: Bool) {
    let folderName = fileURL.deletingLastPathComponent().lastPathComponent
    if isDelete {
      SnippetIndexManager.shared.removeEntry(fileURL: fileURL)
      // 로컬 snippetMap 정리
      let pathStr = fileURL.path
      if let key = snippetMap.first(where: { $0.value.contains(pathStr) })?.key {
        snippetMap[key]?.removeAll { $0 == pathStr }
        if snippetMap[key]?.isEmpty == true {
          snippetMap.removeValue(forKey: key)
        }
      }
      logI("📂 [SnippetRepository] 부분(증분) 삭제 반영: \(fileURL.lastPathComponent)")
      NotificationCenter.default.post(name: .snippetFoldersDidChange, object: nil)
    } else {
      SnippetIndexManager.shared.addOrUpdateEntry(fileURL: fileURL, folderName: folderName)
      // 로컬 snippetMap 갱신
      let abbreviation = calculator.getAbbreviation(for: fileURL).precomposedStringWithCanonicalMapping
      if !abbreviation.isEmpty {
        let pathStr = fileURL.path
        // 기존 맵핑에서 해당 경로를 가진 다른 키가 있다면 오염 제거
        if let oldKey = snippetMap.first(where: { $0.value.contains(pathStr) })?.key, oldKey != abbreviation {
            snippetMap[oldKey]?.removeAll { $0 == pathStr }
            if snippetMap[oldKey]?.isEmpty == true { snippetMap.removeValue(forKey: oldKey) }
        }
        if var paths = snippetMap[abbreviation] {
          if !paths.contains(pathStr) {
            paths.append(pathStr)
            snippetMap[abbreviation] = paths
          }
        } else {
          snippetMap[abbreviation] = [pathStr]
        }
      }
      logI("📂 [SnippetRepository] 부분(증분) 갱신 반영: \(fileURL.lastPathComponent)")
      NotificationCenter.default.post(name: .snippetFoldersDidChange, object: nil)
    }
  }

  // MARK: - 폴더 단위 증분 로딩 (Issue720_3)

  /// FSEvents 변경 시 해당 폴더만 증분 재로딩 (전체 재로딩 대비 빠름)
  private func loadFolderSnippets(_ folderURL: URL) {
    let folderName = folderURL.lastPathComponent

    // 폴더가 삭제된 경우 - 해당 폴더 스니펫 제거 후 종료
    guard fileManager.fileExists(atPath: folderURL.path) else {
      removeFolderFromSnippetMap(folderURL)
      NotificationCenter.default.post(name: .snippetFoldersDidChange, object: nil)
      logI("📂 [SnippetRepository] 폴더 삭제 감지 - 스니펫 제거: \(folderName)")
      return
    }

    // 1. 해당 폴더의 기존 스니펫 제거
    removeFolderFromSnippetMap(folderURL)

    // 2. 해당 폴더만 재스캔
    let settings = SettingsManager.shared.load()
    let files = getSnippetFiles(in: folderURL)
    var addedCount = 0

    for file in files {
      if isExcludedFile(file, in: folderName, settings: settings) { continue }
      var isDirectory: ObjCBool = false
      if fileManager.fileExists(atPath: file.path, isDirectory: &isDirectory),
        isDirectory.boolValue { continue }
      if file.lastPathComponent == "Data" { continue }

      let abbreviation = calculator.getAbbreviation(for: file)
        .precomposedStringWithCanonicalMapping
      guard !abbreviation.isEmpty else { continue }

      let pathStr = file.path
      if var existing = snippetMap[abbreviation] {
        if !existing.contains(pathStr) {
          existing.append(pathStr)
          snippetMap[abbreviation] = existing
        }
      } else {
        snippetMap[abbreviation] = [pathStr]
      }

      SnippetIndexManager.shared.addOrUpdateEntry(fileURL: file, folderName: folderName)
      addedCount += 1
    }

    NotificationCenter.default.post(name: .snippetFoldersDidChange, object: nil)
    logI("📂 [SnippetRepository] 폴더 증분 로딩 완료: \(folderName) (\(addedCount)개 스니펫)")
  }

  /// 해당 폴더의 스니펫을 snippetMap에서 제거
  private func removeFolderFromSnippetMap(_ folderURL: URL) {
    let pathPrefix = folderURL.path + "/"
    var keysToRemove: [String] = []
    for (key, paths) in snippetMap {
      let filtered = paths.filter { !$0.hasPrefix(pathPrefix) }
      if filtered.isEmpty {
        keysToRemove.append(key)
      } else if filtered.count != paths.count {
        snippetMap[key] = filtered
      }
    }
    keysToRemove.forEach { snippetMap.removeValue(forKey: $0) }
  }

  // MARK: - Watcher

  func startFolderWatching(callback: @escaping (Set<String>) -> Void) {
    guard folderWatcher == nil else { return }

    self.folderWatcher = SnippetFolderWatcher(
      rootFolder: rootFolderURL,
      onFileEvent: { [weak self] event in
        self?.handleFileEvent(event)
      }
    ) {
      [weak self] changedPaths in
      guard let self = self else { return }

      // Issue720_6: FSEvents 변경 시 해당 폴더만 증분 로딩 시도 (다중 경로 처리)
      var folderURLsToReload: Set<URL> = []
      var needsFullReload = false
      var fallbackReason = ""

      for path in changedPaths {
        let changedURL = URL(fileURLWithPath: path)
        let folderURL = changedURL.hasDirectoryPath
          ? changedURL
          : changedURL.deletingLastPathComponent()
        let parentURL = folderURL.deletingLastPathComponent()

        // rootFolder 직속 하위 폴더(스니펫 폴더)의 변경이면 증분 로딩
        if parentURL.standardizedFileURL.path == self.rootFolderURL.standardizedFileURL.path {
          folderURLsToReload.insert(folderURL)
        } else {
          needsFullReload = true
          fallbackReason = folderURL.lastPathComponent
          break
        }
      }

      if needsFullReload {
        // 폴백: 루트 폴더 자체 변경 등 - 전체 재로딩
        self.loadAllSnippets(reason: "FSEvents 변경 (폴백: \(fallbackReason))")
      } else {
        for folderURL in folderURLsToReload {
          self.loadFolderSnippets(folderURL)
        }
      }
      callback(changedPaths)
    }
    self.folderWatcher?.startWatching()
  }

  private func restartFolderWatching() {
    stopFolderWatching()
    // If we were watching, we should restart. Since startFolderWatching takes a callback...
    // This is tricky. The Facade probably started it.
    // Repository should manage its own watching state?
    // Let's assume typical usage: Facade calls `startFolderWatching` on init.
    // If repo restarts it, it needs the callback.

    // Better: Store the callback or delegate.
    // For now, let's just create a simple internal method or rely on Facade re-init?
    // Actually, loadAllSnippets is the primary action.

    if self.folderWatcher != nil {
      self.folderWatcher = SnippetFolderWatcher(
        rootFolder: rootFolderURL,
        onFileEvent: { [weak self] event in
          self?.handleFileEvent(event)
        }
      ) {
        [weak self] changedPaths in
        let folderName =
          changedPaths.first.flatMap { URL(fileURLWithPath: $0).lastPathComponent } ?? "Unknown"
        self?.loadAllSnippets(reason: "FSEvents 변경 (\(folderName))")
      }
      self.folderWatcher?.startWatching()
    }
  }

  // MARK: - Issue25: 파일 레벨 FSEvents 즉시 처리

  /// FSEvents 파일 레벨 이벤트를 즉시 처리하여 캐시 무효화
  /// 디바운스 없이 호출되므로 삭제된 파일의 캐시가 즉시 제거됨
  private func handleFileEvent(_ event: FileChangeEvent) {
    let fileURL = URL(fileURLWithPath: event.path)
    let fileName = fileURL.lastPathComponent

    // 스니펫 관련 파일만 처리 (숨김 파일, 디렉토리 등 제외)
    guard !fileName.hasPrefix(".") else { return }

    if event.isRemoved && event.isFile {
      // 파일 삭제: snippetMap에서 즉시 제거
      let pathStr = fileURL.path
      if let key = snippetMap.first(where: { $0.value.contains(pathStr) })?.key {
        snippetMap[key]?.removeAll { $0 == pathStr }
        if snippetMap[key]?.isEmpty == true {
          snippetMap.removeValue(forKey: key)
        }
        SnippetIndexManager.shared.removeEntry(fileURL: fileURL)
        NotificationCenter.default.post(name: .snippetFoldersDidChange, object: nil)
        ChangeTracker.shared.record(type: "snippet.deleted", target: fileName)
        logI("📂 [SnippetRepository] 파일 삭제 즉시 캐시 무효화: \(fileName)")
      }
    } else if event.isFile && (event.isCreated || event.isModified) {
      // 파일 생성/수정: 즉시 캐시에 반영
      let folderName = fileURL.deletingLastPathComponent().lastPathComponent
      let abbreviation = calculator.getAbbreviation(for: fileURL)
        .precomposedStringWithCanonicalMapping
      guard !abbreviation.isEmpty else { return }

      let pathStr = fileURL.path
      // 기존 키에 동일 경로가 있으면 오염 제거
      if let oldKey = snippetMap.first(where: { $0.value.contains(pathStr) })?.key,
        oldKey != abbreviation
      {
        snippetMap[oldKey]?.removeAll { $0 == pathStr }
        if snippetMap[oldKey]?.isEmpty == true { snippetMap.removeValue(forKey: oldKey) }
      }
      if var paths = snippetMap[abbreviation] {
        if !paths.contains(pathStr) {
          paths.append(pathStr)
          snippetMap[abbreviation] = paths
        }
      } else {
        snippetMap[abbreviation] = [pathStr]
      }
      SnippetIndexManager.shared.addOrUpdateEntry(fileURL: fileURL, folderName: folderName)
      NotificationCenter.default.post(name: .snippetFoldersDidChange, object: nil)
      let changeType = event.isCreated ? "snippet.created" : "snippet.updated"
      ChangeTracker.shared.record(type: changeType, target: fileName)
      logI("📂 [SnippetRepository] 파일 변경 즉시 캐시 반영: \(fileName)")
    } else if event.isFile && event.isRenamed {
      // 파일 이름 변경: 기존 경로 제거 (새 이름은 생성 이벤트로 처리됨)
      let pathStr = fileURL.path
      if !FileManager.default.fileExists(atPath: pathStr) {
        // 이전 이름(파일이 더 이상 존재하지 않음) → 캐시에서 제거
        if let key = snippetMap.first(where: { $0.value.contains(pathStr) })?.key {
          snippetMap[key]?.removeAll { $0 == pathStr }
          if snippetMap[key]?.isEmpty == true {
            snippetMap.removeValue(forKey: key)
          }
          SnippetIndexManager.shared.removeEntry(fileURL: fileURL)
          NotificationCenter.default.post(name: .snippetFoldersDidChange, object: nil)
          logI("📂 [SnippetRepository] 파일 이름 변경(이전 이름) 캐시 무효화: \(fileName)")
        }
      }
    }
  }

  func stopFolderWatching() {
    folderWatcher?.stopWatching()
    folderWatcher = nil
  }

  // MARK: - Retrieval Helpers

  func getSnippetItem(at path: String) -> SnippetItem? {
    let fileURL = URL(fileURLWithPath: path)
    let fileName = fileURL.lastPathComponent
    let folderName = fileURL.deletingLastPathComponent().lastPathComponent

    let baseName = fileURL.deletingPathExtension().lastPathComponent
    var keyword = ""
    var name = ""

    if baseName.contains("===") {
      let parts = baseName.components(separatedBy: "===")
      if parts.count > 0 { keyword = parts[0] }
      if parts.count > 1 { name = parts[1] }
    } else {
      keyword = baseName
    }

    let content: String
    do {
      content = try String(contentsOf: fileURL, encoding: .utf8)
    } catch {
      logW("📂 [SnippetRepository] Failed to read content: \(error)")
      content = ""
    }

    return SnippetItem(
      fileName: fileName,
      name: name,
      folderPrefix: folderName,
      keyword: keyword,
      folderSuffix: "",
      content: content,
      filePath: path
    )
  }

  func lookup(key: String) -> String? {
    return snippetMap[key]?.first
  }

  func lookupAll(key: String) -> [String]? {
    return snippetMap[key]
  }

  func checkDuplicate(abbreviation: String, currentSnippetPath: String? = nil) -> Bool {
    guard !abbreviation.isEmpty else { return false }
    if let existingPaths = snippetMap[abbreviation] {
      if let current = currentSnippetPath {
        let otherPaths = existingPaths.filter { $0 != current }
        if otherPaths.isEmpty { return false }
      }
      return true
    }
    return false
  }

  func getConflictingSnippetPath(abbreviation: String, excludingPath: String? = nil) -> String? {
    guard !abbreviation.isEmpty else { return nil }
    if let existingPaths = snippetMap[abbreviation] {
      if let excluded = excludingPath {
        // 제외할 경로가 있다면, 그 경로를 제외하고 첫 번째 충돌 경로를 반환
        return existingPaths.first(where: { $0 != excluded })
      }
      return existingPaths.first
    }
    return nil
  }

  func findSnippetPath(in folderName: String, abbreviation: String) -> String? {
    let folderURL = accessedURL.appendingPathComponent(folderName)
    guard fileManager.fileExists(atPath: folderURL.path) else { return nil }

    let files = getSnippetFiles(in: folderURL)
    for file in files {
      if isExcludedFile(file, in: folderName) { continue }
      let fileAbbreviation = calculator.getAbbreviation(for: file)
      if fileAbbreviation == abbreviation {
        return file.path
      }
    }
    return nil
  }

  func findKeywordConflict(
    folder: String, keyword: String, name: String, excludingPath: String? = nil
  ) -> SnippetItem? {
    let folderURL = accessedURL.appendingPathComponent(folder)
    guard fileManager.fileExists(atPath: folderURL.path) else { return nil }

    let safeKeyword = SnippetItem.encodeKeyword(keyword)
    let safeName = SnippetItem.encodeKeyword(name)

    if !safeKeyword.isEmpty {
      let files = getSnippetFiles(in: folderURL)
      for file in files {
        if let exclude = excludingPath, file.path == exclude { continue }

        let baseName = file.deletingPathExtension().lastPathComponent

        if baseName.hasPrefix("\(safeKeyword)===") {
          return getSnippetItem(at: file.path)
        }
        if baseName == safeKeyword {
          return getSnippetItem(at: file.path)
        }
      }
    } else {
      let expectedFileName: String
      if safeName.isEmpty {
        expectedFileName = "\(safeKeyword).txt"
      } else {
        expectedFileName = "\(safeKeyword)===\(safeName).txt"
      }
      let expectedPath = folderURL.appendingPathComponent(expectedFileName).path

      if fileManager.fileExists(atPath: expectedPath) {
        if let exclude = excludingPath, expectedPath == exclude { return nil }
        return getSnippetItem(at: expectedPath)
      }
    }
    return nil
  }

  func validateNewFolderName(_ name: String) -> Result<
    Void, SnippetFileManager.FolderValidationError
  > {
    if name.hasPrefix("_") { return .success(()) }
    let capitalLetters = FileUtilities.extractCapitalLetters(from: name)
    if capitalLetters.isEmpty { return .failure(.noUppercase) }

    let existingFolders = getSnippetFolders().map { $0.lastPathComponent }
    for folder in existingFolders {
      guard !folder.hasPrefix("_") else { continue }
      let existingShortName = FileUtilities.extractCapitalLetters(from: folder)
      if existingShortName == capitalLetters {
        return .failure(.duplicateShortName(conflictingFolder: folder))
      }
    }
    return .success(())
  }
}
