import Cocoa
import Foundation

/// 향상된 Snippet 파일 시스템 관리 클래스 (Facade)
/// - 실제 로직은 `SnippetRepository`와 `AbbreviationCalculator`로 분리되었습니다.
class SnippetFileManager {
    static let shared = SnippetFileManager()

    // Core Dependencies
    private let repository = SnippetRepository.shared
    private let calculator = AbbreviationCalculator.shared

    // MARK: - Properties (Forwarding)

    var rootFolderURL: URL {
        return repository.rootFolderURL
    }

    var snippetMap: [String: [String]] {
        return repository.snippetMap
    }

    var accessedURL: URL {
        return repository.accessedURL
    }

    // MARK: - Initialization

    private init() {
        // Repository is already initialized (singleton)
        // Ensure observers are set up in Repository
    }

    // MARK: - Public API (Forwarding)

    /// 전체 snippet 맵 로드
    func loadAllSnippets(reason: String = "App/Manual", force: Bool = true) {
        repository.loadAllSnippets(reason: reason, force: force)
    }

    /// 폴더 감시 시작
    func startFolderWatching() {
        repository.startFolderWatching { _ in
            // Callback if needed, currently Repository handles internal refresh
        }
    }

    /// 폴더 감시 중지
    func stopFolderWatching() {
        repository.stopFolderWatching()
    }

    /// 외부에서 모든 스니펫 지우기
    func clearAllSnippets() {
        repository.clearAllSnippets()
    }

    // MARK: - Query Methods

    func getSnippetFolders() -> [URL] {
        return repository.getSnippetFolders()
    }

    func getSnippetFiles(in folder: URL) -> [URL] {
        return repository.getSnippetFiles(in: folder)
    }

    func isAlfredFolder(_ folderPath: String = "") -> Bool {
        return repository.isAlfredFolder(folderPath)
    }

    func isSupportedFile(_ url: URL) -> Bool {
        return repository.isSupportedFile(url)
    }

    func isExcludedFile(_ file: URL, in folderName: String) -> Bool {
        return repository.isExcludedFile(file, in: folderName)
    }

    func lookup(key: String) -> String? {
        return repository.lookup(key: key)
    }

    func lookupAll(key: String) -> [String]? {
        return repository.lookupAll(key: key)
    }

    func checkDuplicate(abbreviation: String, currentSnippetPath: String? = nil) -> Bool {
        return repository.checkDuplicate(
            abbreviation: abbreviation, currentSnippetPath: currentSnippetPath)
    }

    func getConflictingSnippetPath(abbreviation: String, excludingPath: String? = nil) -> String? {
        return repository.getConflictingSnippetPath(
            abbreviation: abbreviation, excludingPath: excludingPath)
    }

    func findSnippetPath(in folderName: String, abbreviation: String) -> String? {
        return repository.findSnippetPath(in: folderName, abbreviation: abbreviation)
    }

    func findKeywordConflict(
        folder: String, keyword: String, name: String, excludingPath: String? = nil
    ) -> SnippetItem? {
        return repository.findKeywordConflict(
            folder: folder, keyword: keyword, name: name, excludingPath: excludingPath)
    }

    func getSnippetItem(at path: String) -> SnippetItem? {
        return repository.getSnippetItem(at: path)
    }

    /// 파일에서 abbreviation 키 추출
    func getAbbreviation(for file: URL) -> String {
        return calculator.getAbbreviation(for: file)
    }

    /// 핵심 약어 계산 로직 (Calculator 위임)
    func calcAbbreviation(folderName: String, baseFileName: String, file: URL? = nil) -> String {
        return calculator.calcAbbreviation(
            folderName: folderName, baseFileName: baseFileName, file: file)
    }

    /// 가상 새 스니펫에 대한 약어 계산 (UI 표시용)
    func calculateAbbreviation(folder: String, keyword: String, name: String) -> String {
        return calculator.calculateAbbreviation(folder: folder, keyword: keyword, name: name)
    }

    func calculateDetailFilePath(folder: String, name: String, keyword: String) -> String {
        return calculator.calculateDetailFilePath(
            rootFolderURL: rootFolderURL, folder: folder, name: name, keyword: keyword)
    }

    // MARK: - CRUD (Forwarding)

    func createSnippet(folder: String, name: String, keyword: String, content: String) -> Bool {
        return repository.createSnippet(
            folder: folder, name: name, keyword: keyword, content: content)
    }

    func createSnippetInFolder(folder: String, name: String, keyword: String, content: String)
        -> Bool
    {
        return repository.createSnippetInFolder(
            folder: folder, name: name, keyword: keyword, content: content)
    }

    func updateSnippet(
        originalItem: SnippetItem, newFolder: String? = nil, newName: String, newKeyword: String,
        newContent: String
    ) -> Bool {
        return repository.updateSnippet(
            originalItem: originalItem, newFolder: newFolder, newName: newName,
            newKeyword: newKeyword, newContent: newContent)
    }

    func deleteSnippet(folder: String, name: String) -> Bool {
        return repository.deleteSnippet(folder: folder, name: name)
    }

    func deleteFile(at path: String) {
        repository.deleteFile(at: path)
    }

    func createFolder(folderName: String) -> Bool {
        return repository.createFolder(folderName: folderName)
    }

    func renameFolder(oldName: String, newName: String) -> Bool {
        return repository.renameFolder(oldName: oldName, newName: newName)
    }

    func deleteFolder(folderName: String) -> Bool {
        return repository.deleteFolder(folderName: folderName)
    }

    func updateRootFolder(_ path: String) {
        repository.updateRootFolder(path)
    }

    // MARK: - Validation

    enum FolderValidationError: Error, LocalizedError {
        case noUppercase
        case duplicateShortName(conflictingFolder: String)

        var errorDescription: String? {
            switch self {
            case .noUppercase:
                return String(localized: "폴더명은 최소 하나 이상의 대문자가 포함되거나 _(언더바)로 시작해야 합니다.")
            case .duplicateShortName(let conflictingFolder):
                return String(localized: "폴더 약어(대문자 조합)가 기존 폴더 '\(conflictingFolder)'와 중복됩니다.")
            }
        }
    }

    func validateNewFolderName(_ name: String) -> Result<Void, FolderValidationError> {
        return repository.validateNewFolderName(name)
    }
}
