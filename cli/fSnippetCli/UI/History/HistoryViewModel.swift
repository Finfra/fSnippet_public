import Combine
import SwiftUI

class HistoryViewModel: ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var searchText: String = ""
    @Published var selectedIds: Set<Int64> = []
    @Published var lastSelectedId: Int64?  // Shift-Click 등을 위한 마지막 선택 ID
    @Published var isLoading: Bool = false
    @Published var canLoadMore: Bool = true
    // @Published var toastMessage: String? = nil // Removed in Issue272 Refactor
    @Published var isPaused: Bool = false
    @Published var searchDuration: TimeInterval = 0  // CL098: Search Performance Tracking

    // CL078: Filter Options
    enum FilterOption: Equatable, Hashable {
        case all
        case images
        case app(String)

        var displayName: String {
            switch self {
            case .all: return NSLocalizedString("history.filter.all", comment: "")
            case .images: return NSLocalizedString("history.filter.images", comment: "")
            case .app(let bundleId):
                // Simple attempt to get app name, fallback to bundle suffix
                if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
                {
                    return appUrl.deletingPathExtension().lastPathComponent
                }
                return bundleId.components(separatedBy: ".").last?.capitalized ?? bundleId
            }
        }

        var iconName: String {
            switch self {
            case .all: return "line.3.horizontal.decrease.circle"
            case .images: return "photo"
            case .app: return "app.badge"
            }
        }

        // For UI: Helper to get NSImage for app bundle
        var appIcon: NSImage? {
            switch self {
            case .app(let bundleId):
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    return NSWorkspace.shared.icon(forFile: url.path)
                }
                // Fallback: Try to get icon by bundle id roughly? No valid API for that directly without URL usually.
                return nil
            default:
                return nil
            }
        }
    }

    @Published var selectedFilter: FilterOption = .all
    @Published var availableApps: [String] = []

    // 편의상 첫 번째 선택된 ID 반환 (단일 선택 호환성)
    var selectedId: Int64? {
        return lastSelectedId ?? selectedIds.first
    }

    private let PAGE_SIZE = 50
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.isPaused = PreferencesManager.shared.bool(
            forKey: "history.isPaused", defaultValue: false)

        // 검색 텍스트 변경 시 데이터 다시 로드 (디바운스 적용)
        $searchText
            .dropFirst()  // 초기값("") 방출 무시 - 창 열릴 때 불필요한 fetchHistory(reset:true) 방지
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.fetchHistory(reset: true)
            }
            .store(in: &cancellables)

        // 외부(설정 창, 단축키 등)에서의 상태 변화 감지
        NotificationCenter.default.publisher(for: NSNotification.Name("historyPauseStateChanged"))
            .sink { [weak self] notification in
                if let newState = notification.object as? Bool {
                    DispatchQueue.main.async {
                        self?.isPaused = newState
                    }
                }
            }
            .store(in: &cancellables)

        // CL078: 필터 변경 시 새로고침 (즉시 반영을 위해 값 전달)
        $selectedFilter
            .dropFirst()
            .sink { [weak self] newFilter in
                self?.fetchHistory(reset: true, filterBy: newFilter)
            }
            .store(in: &cancellables)

        // CL095: Throttle Preview Updates to prevent UI lag during rapid navigation
        $lastSelectedId
            .throttle(for: .milliseconds(200), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] id in
                guard let self = self, let id = id,
                    let item = self.items.first(where: { $0.id == id })
                else { return }
                HistoryPreviewManager.shared.show(item: item)
            }
            .store(in: &cancellables)

        // ✅ Issue626: 초기화 시점에 즉시(동기적으로) 첫 페이지 데이터 로드
        // 화면이 등장(onAppear)하고 나서 비동기로 데이터를 가져와 첫 번째 항목이 늦게 선택(덜컹거림)되는 현상 방지
        fetchInitialDataSync()
    }

    /// show() 시점에 호출하여 상태를 초기화하고 데이터를 다시 로드
    func refresh() {
        searchText = ""
        selectedFilter = .all
        selectedIds.removeAll()
        lastSelectedId = nil
        canLoadMore = true
        isLoading = false
        searchDuration = 0
        fetchInitialDataSync()
        fetchAvailableApps()
    }

    func fetchHistory(reset: Bool = false, filterBy: FilterOption? = nil) {
        if reset {
            items = []
            canLoadMore = true
            selectedIds.removeAll()
            lastSelectedId = nil
        }

        guard canLoadMore && !isLoading else { return }

        isLoading = true
        let currentOffset = items.count
        let query = searchText

        // 백그라운드에서 검색 수행
        // Use provided filter or current state (Fix caused by delayed state update in @Published sink)
        let filter = filterBy ?? self.selectedFilter

        DispatchQueue.global(qos: .userInitiated).async {
            var appBundle: String? = nil
            var kind: String? = nil

            switch filter {
            case .all: break
            case .images: kind = "image"
            case .app(let bundle): appBundle = bundle
            }

            let (results, duration) = ClipboardDB.shared.search(
                query: query, limit: self.PAGE_SIZE, offset: currentOffset, appBundle: appBundle,
                kind: kind)

            DispatchQueue.main.async {
                self.isLoading = false
                self.searchDuration = duration

                if results.count < self.PAGE_SIZE {
                    self.canLoadMore = false
                }

                if reset {
                    self.items = results
                } else {
                    self.items.append(contentsOf: results)
                }

                // 검색 결과가 있고 선택된 것이 없다면 첫 번째 항목 선택
                if reset && self.selectedIds.isEmpty, let firstId = self.items.first?.id {
                    self.selectedIds = [firstId]
                    if self.lastSelectedId != firstId {
                        self.lastSelectedId = firstId
                    }
                }

                logD(
                    "🧠 [chv:\(ClipboardManager.shared.chvMode)] : 📋 [HistoryViewModel] fetchHistory done. reset=\(reset), items=\(self.items.count), canLoadMore=\(self.canLoadMore), filter=\(filter)"
                )
            }
        }
    }

    // ✅ Issue626: 초기(인스턴스 생성 시점) 1회만 동기적으로 첫 페이지 데이터를 가져오는 메서드
    // Async 백그라운드 스레드 전환 비용을 없애서 View가 렌더링될 때 이미 데이터가 채워져 있도록 함.
    private func fetchInitialDataSync() {
        items = []
        selectedIds.removeAll()
        lastSelectedId = nil
        isLoading = true

        let query = searchText
        let filter = selectedFilter

        var appBundle: String? = nil
        var kind: String? = nil

        switch filter {
        case .all: break
        case .images: kind = "image"
        case .app(let bundle): appBundle = bundle
        }

        // 동기적으로 DB를 조회합니다. (첫 페이지 50개는 매우 빠름)
        let (results, duration) = ClipboardDB.shared.search(
            query: query, limit: PAGE_SIZE, offset: 0, appBundle: appBundle, kind: kind)

        self.items = results
        self.searchDuration = duration
        if results.count < PAGE_SIZE {
            self.canLoadMore = false
        }

        // 데이터가 있다면 곧바로 첫 번째 항목을 선택 처리
        if let firstId = results.first?.id {
            self.selectedIds = [firstId]
            self.lastSelectedId = firstId
        }

        self.isLoading = false
        logD(
            "🧠 [chv:\(ClipboardManager.shared.chvMode)] : 📋 [HistoryViewModel] fetchInitialDataSync done. items=\(self.items.count)"
        )
    }

    func fetchNextPage() {
        fetchHistory(reset: false)
    }

    // CL078: Fetch available apps for filter
    func fetchAvailableApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = ClipboardDB.shared.getDistinctAppBundles()
            DispatchQueue.main.async {
                self.availableApps = apps
            }
        }
    }

    func toggleSelection(id: Int64, isCommandPressed: Bool, isShiftPressed: Bool) {
        if isCommandPressed {
            if selectedIds.contains(id) {
                selectedIds.remove(id)
                if lastSelectedId == id { lastSelectedId = selectedIds.first }
            } else {
                selectedIds.insert(id)
                lastSelectedId = id
            }
        } else if isShiftPressed, let lastId = lastSelectedId {
            // Shift 선택: lastSelectedId와 현재 id 사이의 모든 항목 선택
            guard let lastIdx = items.firstIndex(where: { $0.id == lastId }),
                let currIdx = items.firstIndex(where: { $0.id == id })
            else { return }

            let range = lastIdx < currIdx ? lastIdx...currIdx : currIdx...lastIdx
            let idsInRange = items[range].compactMap { $0.id }
            selectedIds.formUnion(idsInRange)
            lastSelectedId = id
        } else {
            // 단일 선택
            selectedIds = [id]
            lastSelectedId = id
        }
    }

    func copyToClipboard(item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.kind {
        case "plain_text":
            // CL098: Fetch full text from DB (item.text is truncated)
            if let id = item.id, let text = ClipboardDB.shared.fetchFullText(id: id) {
                pasteboard.setString(text, forType: .string)
            } else if let text = item.text {
                // Fallback to item.text if DB fetch fails (low probability)
                pasteboard.setString(text, forType: .string)
            }
        case "image":
            if let blobPath = item.blobPath, let blobsDir = ClipboardDB.shared.getBlobsDir() {
                let fileURL = URL(fileURLWithPath: blobsDir).appendingPathComponent(blobPath)
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    // ✅ Issue715: Handle missing image files
                    logW("🧠 [HistoryViewModel] Image file missing during copy, removing item \(item.id ?? 0)")
                    if let id = item.id {
                        ClipboardDB.shared.deleteItem(id: id)
                    }
                    return
                }
                if let image = NSImage(contentsOf: fileURL) {
                    pasteboard.writeObjects([image])
                }
            }
        case "file_list":
            if let json = item.filelistJson,
                let paths = try? JSONDecoder().decode([String].self, from: Data(json.utf8))
            {
                let urls = paths.map { URL(fileURLWithPath: $0) }
                pasteboard.writeObjects(urls as [NSURL])
            }
        default:
            break
        }

        logI("🧠 [History] Copied to clipboard: \(item.kind) (ID: \(item.id ?? -1))")
    }

    func copySelectedItems() {
        // 1. 선택된 아이템들을 리스트 순서(Visual Order)대로 정렬하여 추출
        let sortedItems = items.filter { selectedIds.contains($0.id ?? -1) }

        if sortedItems.isEmpty { return }

        // 2. 단일 항목이면 기존 로직 사용 (이미지 등 처리 호환성)
        if sortedItems.count == 1, let first = sortedItems.first {
            copyToClipboard(item: first)
            return
        }

        // 3. 다중 항목: 텍스트 콘텐츠만 필터링하여 연결
        let texts = sortedItems.compactMap { item -> String? in
            if item.kind == "plain_text" {
                // CL098: Fetch Full Text
                if let id = item.id {
                    return ClipboardDB.shared.fetchFullText(id: id)
                }
                return item.text
            } else if item.kind == "file_list", let json = item.filelistJson {
                // 파일 리스트는 경로들을 텍스트로 변환하여 포함
                if let paths = try? JSONDecoder().decode([String].self, from: Data(json.utf8)) {
                    return paths.joined(separator: "\n")
                }
            }
            return nil
        }

        if texts.isEmpty { return }

        let combinedText = texts.joined(separator: "\n")

        // 4. 클립보드에 쓰기
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(combinedText, forType: .string)

        logI("🧠 [History] Copied \(texts.count) items as single combined text.")
    }

    func deleteItem(item: ClipboardItem) {
        deleteItems(ids: item.id.map { [$0] } ?? [])
    }

    func deleteSelectedItems() {
        let targets = Array(selectedIds)
        if targets.isEmpty { return }
        deleteItems(ids: targets)
    }

    private func deleteItems(ids: [Int64]) {
        if ids.isEmpty { return }

        // 다음에 선택할 항목 찾기 (마지막 선택 항목 기준)
        var nextToSelectId: Int64?
        if let lastId = lastSelectedId ?? ids.last,
            let lastIdx = items.firstIndex(where: { $0.id == lastId })
        {
            // 삭제되지 않을 항목 중 가장 가까운 아래쪽 또는 위쪽 항목 찾기
            let sortedIds = Set(ids)
            if let nextIdx = items.indices.first(where: {
                $0 > lastIdx && !sortedIds.contains(items[$0].id!)
            }) {
                nextToSelectId = items[nextIdx].id
            } else if let prevIdx = items.indices.last(where: {
                $0 < lastIdx && !sortedIds.contains(items[$0].id!)
            }) {
                nextToSelectId = items[prevIdx].id
            }
        }

        ClipboardDB.shared.deleteItems(ids: ids)

        // 목록에서 제거
        let idSet = Set(ids)
        items.removeAll { $0.id != nil && idSet.contains($0.id!) }

        // 선택 상태 갱신
        selectedIds.subtract(idSet)
        if let nextId = nextToSelectId {
            selectedIds.insert(nextId)
            lastSelectedId = nextId
        } else {
            lastSelectedId = selectedIds.first
        }
    }

    // MARK: - Filtered Delete (CL066)
    @Published var showingFilteredDeleteConfirmation = false
    @Published var filteredDeleteCount = 0

    func prepareFilteredDelete() {
        guard !searchText.isEmpty else { return }

        // 1. 매칭되는 ID 개수 확인
        DispatchQueue.global(qos: .userInitiated).async {
            let ids = ClipboardDB.shared.searchIds(query: self.searchText)

            DispatchQueue.main.async {
                if ids.isEmpty {
                    ToastManager.shared.showToast(
                        message: LocalizedStringManager.shared.string("toast.no_matching_items"), iconName: "xmark.circle",
                        relativeTo: HistoryViewerManager.shared.window?.frame)
                } else {
                    self.filteredDeleteCount = ids.count
                    self.showingFilteredDeleteConfirmation = true
                }
            }
        }
    }

    func confirmFilteredDelete() {
        guard !searchText.isEmpty else { return }

        let query = searchText
        DispatchQueue.global(qos: .userInitiated).async {
            // 2. 실제 삭제 수행
            ClipboardDB.shared.deleteItems(matching: query)

            DispatchQueue.main.async {
                ToastManager.shared.showToast(
                    message: LocalizedStringManager.shared.string("toast.deleted_matches"), iconName: "trash",
                    relativeTo: HistoryViewerManager.shared.window?.frame)
                // 3. 목록 새로고침
                self.fetchHistory(reset: true)
                self.showingFilteredDeleteConfirmation = false
            }
        }
    }

    func prepareSnippetData(item: ClipboardItem) -> (keyword: String, content: String) {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"

        // 1. 키워드 제안 및 본문 포맷팅
        var suggestion = ""
        var content = ""

        switch item.kind {
        case "plain_text":
            content = item.text ?? ""
            // 첫 두 단어 추출 (공백 기준)
            let words = content.components(separatedBy: CharacterSet.whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .prefix(2)
            suggestion = words.joined(separator: "").prefix(8).lowercased()
        case "image":
            content = "[IMAGE] \(item.blobPath ?? "unknown")"
            suggestion = "img"
        case "file_list":
            if let json = item.filelistJson,
                let paths = try? JSONDecoder().decode([String].self, from: Data(json.utf8))
            {
                content = paths.joined(separator: "\n")
                suggestion = "files"
            } else {
                content = item.filelistJson ?? ""
                suggestion = "files"
            }
        default:
            content = "Unknown Item"
            suggestion = "clip"
        }

        if suggestion.isEmpty { suggestion = "clip" }

        // 해시 추가 (4자리) - 중복 방지 및 구분용
        let itemHashable =
            item.text ?? item.blobPath ?? item.filelistJson ?? "\(date.timeIntervalSince1970)"
        let uniqueString = "\(itemHashable)_\(date.timeIntervalSince1970)"
        let hash = String(format: "%04x", abs(uniqueString.hashValue % 0xFFFF))
        let keyword = "\(suggestion)\(hash)"

        return (keyword, content)
    }

    /// 클립보드 수집 일시 중단 토글
    func togglePause() {
        isPaused.toggle()
        PreferencesManager.shared.set(isPaused, forKey: "history.isPaused")
        logI("🧠 [HistoryViewModel] Clipboard collection paused: \(isPaused)")

        // 상태 변화 전파
        NotificationCenter.default.post(name: .historyPauseStateChanged, object: isPaused)

        // HUD 알림 표시
        let l10n = LocalizedStringManager.shared
        let message = isPaused ? l10n.string("toast.clipboard_paused") : l10n.string("toast.clipboard_resumed")
        let icon = isPaused ? "pause.fill" : "play.fill"
        ToastManager.shared.showToast(
            message: message, iconName: icon, relativeTo: HistoryViewerManager.shared.window?.frame)
    }

    func registerAndEditAsSnippet(item: ClipboardItem) {
        let (keyword, content) = prepareSnippetData(item: item)

        DispatchQueue.main.async {
            // CL095: Open 'New Snippet' Editor (Draft Mode)
            // Instead of creating a file immediately, we open the editor with pre-filled data.
            // The file is created only when the user clicks 'Save'.
            SnippetEditorWindowManager.shared.showNewEditor(
                keyword: keyword, content: content,
                relativeTo: HistoryViewerManager.shared.window?.frame)

            // Log action
            logI("🧠 [HistoryViewModel] Opened New Snippet Editor for item: \(keyword)")
        }
    }

    /// 클립보드 아이템이 이미지인 경우 로컬 캐시 디렉토리에서 이미지 파일을 찾아 Save Panel을 띄웁니다.
    func saveImageLocally(item: ClipboardItem) {
        guard item.type == .image else { return }

        if let blobFilename = item.blobPath,
            let blobsDir = ClipboardDB.shared.getBlobsDir()
        {
            let fullPath = URL(fileURLWithPath: blobsDir)
                .appendingPathComponent(blobFilename).path

            // NSSavePanel은 Main Thread에서 띄워야 함
            DispatchQueue.main.async {
                let savePanel = NSSavePanel()
                savePanel.title = "Save Image"
                savePanel.nameFieldStringValue = "clipboard_image.png"
                savePanel.canCreateDirectories = true
                savePanel.allowedContentTypes = [.png, .jpeg]

                if savePanel.runModal() == .OK, let url = savePanel.url {
                    do {
                        if FileManager.default.fileExists(atPath: fullPath) {
                            let data = try Data(
                                contentsOf: URL(fileURLWithPath: fullPath))
                            try data.write(to: url)
                            ToastManager.shared.showToast(
                                message: LocalizedStringManager.shared.string("toast.image_saved"),
                                iconName: "checkmark.circle.fill",
                                relativeTo: HistoryViewerManager.shared.window?.frame)
                        } else {
                            // ✅ Issue715: Handle missing image files
                            logW("🧠 [HistoryViewModel] Image file not found during save, removing item \(item.id ?? 0)")
                            if let id = item.id {
                                DispatchQueue.global(qos: .background).async {
                                    ClipboardDB.shared.deleteItem(id: id)
                                }
                            }
                            ToastManager.shared.showToast(
                                message: LocalizedStringManager.shared.string("toast.image_not_found"),
                                iconName: "xmark.circle.fill",
                                relativeTo: HistoryViewerManager.shared.window?.frame)
                        }
                    } catch {
                        logE(
                            "🧠 [HistoryViewModel] Image save failed: \(error.localizedDescription)"
                        )
                        ToastManager.shared.showToast(
                            message: LocalizedStringManager.shared.string("toast.save_failed"),
                            iconName: "xmark.circle.fill",
                            relativeTo: HistoryViewerManager.shared.window?.frame)
                    }
                }
            }
        } else {
            ToastManager.shared.showToast(
                message: LocalizedStringManager.shared.string("toast.no_image_data"), iconName: "xmark.circle.fill",
                relativeTo: HistoryViewerManager.shared.window?.frame)
        }
    }

    func selectNext(extending: Bool = false) {
        guard let currentId = lastSelectedId,
            let currentIndex = items.firstIndex(where: { $0.id == currentId })
        else {
            if let firstId = items.first?.id {
                selectedIds = [firstId]
                lastSelectedId = firstId
            }
            return
        }

        if currentIndex + 1 < items.count {
            let nextId = items[currentIndex + 1].id!
            if extending {
                selectedIds.insert(nextId)
            } else {
                selectedIds = [nextId]
            }
            lastSelectedId = nextId
        } else if canLoadMore {
            fetchNextPage()
            // Loading more might take time, selection update will happen after load if we handle it there,
            // but for now simple page fetch is enough.
        }
    }

    func selectPrevious(extending: Bool = false) {
        guard let currentId = lastSelectedId,
            let currentIndex = items.firstIndex(where: { $0.id == currentId })
        else {
            if let firstId = items.first?.id {
                selectedIds = [firstId]
                lastSelectedId = firstId
            }
            return
        }

        if currentIndex > 0 {
            let prevId = items[currentIndex - 1].id!
            if extending {
                selectedIds.insert(prevId)
            } else {
                selectedIds = [prevId]
            }
            lastSelectedId = prevId
        }
    }
}
