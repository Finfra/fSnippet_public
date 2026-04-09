import AppKit
import Foundation
import SQLite3

/// 간단한 Alfred 스니펫 가져오기 (Sandbox 호환)
/// - `_rule_for_import.yml` 파일에 정의된 규칙 기반으로 스니펫 가져오기 수행
/// - 사용자에게 `snippets.alfdb`를 선택받아 보안 범위를 획득합니다.
/// - 기존 스니펫 폴더 백업 기능 포함
class AlfredImporter {
    static let shared = AlfredImporter()

    struct ImportedStats {
        let total: Int
        let collections: Int
    }

    /// Open Panel로 Alfred DB를 고르고 바로 가져오기 실행
    func pickAndImport(destination destRoot: String) -> Result<ImportedStats, Error> {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.title = NSLocalizedString("alfred.import.panel.title", comment: "Alfred import file picker title")
        panel.message = NSLocalizedString("alfred.import.panel.message", comment: "Alfred import file picker message")

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            return .failure(
                NSError(
                    domain: "AlfredImporter", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("alfred.import.error.cancelled", comment: "Import cancelled")]))
        }

        // 백업 수행
        if let backupError = backupSnippetsFolder(currentDestRoot: destRoot) {
            logE("🛡️ 스니펫 백업 실패: \(backupError.localizedDescription)")
            // 백업 실패를 치명적 오류로 처리할지 선택 (여기서는 계속 진행하도록 하지만 로깅 처리)
        }

        return importFromDB(dbURL: url, destination: destRoot)
    }

    /// 지정된 스니펫 디렉토리의 백업을 형제(sibling) 위치에 생성
    private func backupSnippetsFolder(currentDestRoot: String) -> Error? {
        let fileManager = FileManager.default
        let currentURL = URL(fileURLWithPath: (currentDestRoot as NSString).expandingTildeInPath)

        guard fileManager.fileExists(atPath: currentURL.path) else {
            return nil  // 백업할 폴더가 없음
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        let backupFolderName = "\(currentURL.lastPathComponent)_backup_\(timestamp)"
        let backupURL = currentURL.deletingLastPathComponent().appendingPathComponent(
            backupFolderName)

        do {
            try fileManager.copyItem(at: currentURL, to: backupURL)
            logI("🛡️ 백업 완료: \(backupURL.path)")
            return nil
        } catch {
            return error
        }
    }

    /// DB에서 스니펫을 읽어 destination으로 변환/저장
    func importFromDB(dbURL: URL, destination destRoot: String) -> Result<ImportedStats, Error> {
        // Issue689: 가져오기 중 파일 감시 중단 (Reload Storm 방지)
        SnippetRepository.shared.stopFolderWatching()
        defer {
            SnippetRepository.shared.startFolderWatching { _ in }
            SnippetRepository.shared.loadAllSnippets(reason: "Alfred Import 완료", force: true)
        }

        // 보안 스코프 활성화
        let needsBookmark = dbURL.startAccessingSecurityScopedResource()
        defer { if needsBookmark { dbURL.stopAccessingSecurityScopedResource() } }

        guard FileManager.default.fileExists(atPath: dbURL.path) else {
            return .failure(
                NSError(
                    domain: "AlfredImporter", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: String(format: NSLocalizedString("alfred.import.error.db_not_found", comment: "Database not found"), dbURL.path)]))
        }

        var db: OpaquePointer?
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            return .failure(
                NSError(
                    domain: "AlfredImporter", code: 3,
                    userInfo: [NSLocalizedDescriptionKey: String(format: NSLocalizedString("alfred.import.error.db_open_failed", comment: "Database open failed"), dbURL.path)]))
        }
        defer { sqlite3_close(db) }

        // import_snippets.swift 로직에 매칭되는 쿼리
        let query = """
                SELECT uid, name, keyword, snippet, IFNULL(collection,'uncategorized') AS collection
                FROM snippets
                WHERE autoexpand = 1
                  AND snippet IS NOT NULL AND snippet != ''
                  AND keyword  IS NOT NULL AND TRIM(keyword) != ''
            """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) != SQLITE_OK {
            return .failure(
                NSError(
                    domain: "AlfredImporter", code: 4,
                    userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("alfred.import.error.query_failed", comment: "Query preparation failed")]))
        }
        defer { sqlite3_finalize(stmt) }

        // 출력 루트 준비
        let destRootURL = URL(fileURLWithPath: (destRoot as NSString).expandingTildeInPath)
        do {
            if !FileManager.default.fileExists(atPath: destRootURL.path) {
                try FileManager.default.createDirectory(
                    at: destRootURL, withIntermediateDirectories: true)
            }
        } catch {
            return .failure(
                NSError(
                    domain: "AlfredImporter", code: 5,
                    userInfo: [
                        NSLocalizedDescriptionKey: String(format: NSLocalizedString("alfred.import.error.folder_creation_failed", comment: "Output folder creation failed"), error.localizedDescription)
                    ]))
        }

        // Issue689_4: _rule.yml 파싱 및 매핑 규칙 준비 (이제 _rule_for_import.yml 대신 직접 사용)
        // Issue689_1: _rule_for_import.yml 이 존재한다면 이를 우선 병합하여 반영해야 함.
        let mainRuleFileURL = destRootURL.appendingPathComponent("_rule.yml")
        let importRuleFileURL = SnippetFileManager.shared.rootFolderURL.appendingPathComponent(
            "_rule_for_import.yml")
        var importRulesDict: [String: String] = [:]  // Alfred Collection Name -> Dest Folder Name Mapping
        var mockImportConfig = ImportConfig()  // YAML 파서 없이 수동 구축하여 AlfredLogic에 임시 주입

        let logic = AlfredLogic.shared

        let ruleFilesToRead = [mainRuleFileURL, importRuleFileURL]

        for ruleFile in ruleFilesToRead {
            if FileManager.default.fileExists(atPath: ruleFile.path),
                let content = try? String(contentsOf: ruleFile, encoding: .utf8)
            {
                let parsedConfig = logic.parseImportConfig(content)
                for (k, v) in parsedConfig.triggerRemapping {
                    mockImportConfig.triggerRemapping[k] = v
                }

                let lines = content.components(separatedBy: .newlines)
                var currentCollectionName: String?
                var currentPrefix: String?
                var currentSuffix: String?
                var currentBias: Int?

                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("- name:") {
                        // 이전 컬렉션 저장
                        if let cName = currentCollectionName {
                            mockImportConfig.collections[cName] = ImportConfig.CollectionConfig(
                                name: cName, prefix: currentPrefix, suffix: currentSuffix,
                                triggerBias: currentBias, folder: nil, ignore: false)
                        }

                        let value = trimmed.replacingOccurrences(of: "- name:", with: "")
                            .trimmingCharacters(in: .whitespaces)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                        currentCollectionName = value
                        currentPrefix = nil
                        currentSuffix = nil
                        currentBias = nil
                    } else if trimmed.hasPrefix("prefix:") {
                        currentPrefix = trimmed.replacingOccurrences(of: "prefix:", with: "")
                            .trimmingCharacters(in: .whitespaces)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    } else if trimmed.hasPrefix("suffix:") {
                        currentSuffix = trimmed.replacingOccurrences(of: "suffix:", with: "")
                            .trimmingCharacters(in: .whitespaces)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    } else if trimmed.hasPrefix("trigger_bias:") {
                        if let biasVal = Int(
                            trimmed.replacingOccurrences(of: "trigger_bias:", with: "")
                                .trimmingCharacters(in: .whitespaces))
                        {
                            currentBias = biasVal
                        }
                    } else if trimmed.hasPrefix("description:") {
                        let descValue = trimmed.replacingOccurrences(of: "description:", with: "")
                            .trimmingCharacters(in: .whitespaces)
                            .components(separatedBy: "#")[0]  // 주석 제거
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))

                        if let collectionName = currentCollectionName, !descValue.isEmpty {
                            // description에 지정된 Alfred 컬렉션 이름 목록이 콤마로 구분되어 있다고 가정
                            let alfredNames = descValue.components(separatedBy: ",").map {
                                $0.trimmingCharacters(in: .whitespaces)
                            }
                            for aName in alfredNames {
                                importRulesDict[aName] = collectionName
                            }
                        }
                    }
                }
                // 마지막 컬렉션 저장
                if let cName = currentCollectionName {
                    mockImportConfig.collections[cName] = ImportConfig.CollectionConfig(
                        name: cName, prefix: currentPrefix, suffix: currentSuffix,
                        triggerBias: currentBias, folder: nil, ignore: false)
                }
            }
        }

        logI("🛡️ Loaded Import Rules Mappings: \\(importRulesDict.count) items")

        logic.importConfig = mockImportConfig  // 파싱한 규칙 주입

        var snippets: [AlfredSnippet] = []

        // 1. 모든 스니펫 수집
        while sqlite3_step(stmt) == SQLITE_ROW {
            let uid = String(cString: sqlite3_column_text(stmt, 0))  // uid
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let keyword = String(cString: sqlite3_column_text(stmt, 2))
            let snippetContent = String(cString: sqlite3_column_text(stmt, 3))

            // _rule_for_import.yml 매핑이 있으면 사용, 없으면 그대로 사용
            let rawCollection = String(cString: sqlite3_column_text(stmt, 4))
            let mappedCollection = importRulesDict[rawCollection] ?? rawCollection

            let model = AlfredSnippet(
                uid: uid,
                name: name,
                keyword: keyword,
                snippet: snippetContent,
                collection: mappedCollection,
                autoexpand: true,
                triggerKeyword: nil  // 로직에 엄격하게 사용되지 않음, 즉시 계산됨
            )
            snippets.append(model)
        }

        // Issue689_4: _rule.yml 생성 및 업데이트
        // Import 시작 시 읽었던 기존 규칙(혹은 폴백 규칠)에 바탕을 두고,
        // 이번에 Import되는 snippet들의 컬렉션을 머지하여 _rule.yml을 생성합니다.
        var collectionGroups: [String: [AlfredSnippet]] = [:]
        for snippet in snippets {
            let col = snippet.collection ?? "uncategorized"
            collectionGroups[col, default: []].append(snippet)
        }

        let yamlOutput = logic.createUnifiedRuleYAML(collectionGroups: collectionGroups)
        do {
            try yamlOutput.write(to: mainRuleFileURL, atomically: true, encoding: .utf8)
            logI("🛡️ _rule.yml 생성 및 업데이트 완료")

            // Issue689_1: 캐시 무효화 후 규칙 로드
            // RuleManager의 캐시를 먼저 명시적으로 초기화하여 파일 수정 날짜 비교에서
            // 이전 캐시 상태의 영향을 받지 않도록 함
            RuleManager.shared.clearCache()
            logI("🛡️ RuleManager 캐시 초기화")

            // 생성된 _rule.yml을 RuleManager에 로드
            let ruleLoadSuccess = RuleManager.shared.loadRules(from: mainRuleFileURL.path)
            logI("🛡️ RuleManager 규칙 로드: \(ruleLoadSuccess ? "성공" : "실패")")

            // 규칙 변경 알림 발송 (UI 업데이트 트리거)
            NotificationCenter.default.post(name: NSNotification.Name("RuleDidChange"), object: nil)
            logI("🛡️ 규칙 변경 알림 발송 완료")
        } catch {
            logE("🛡️ _rule.yml 쓰기 실패: \\(error)")
        }

        // Issue29/lib-apply: _rule_for_import.yml 복사 동기화
        let importRuleDestURL = destRootURL.appendingPathComponent("_rule_for_import.yml")
        if importRuleFileURL.path != importRuleDestURL.path
            && FileManager.default.fileExists(atPath: importRuleFileURL.path)
        {
            do {
                if FileManager.default.fileExists(atPath: importRuleDestURL.path) {
                    try FileManager.default.removeItem(at: importRuleDestURL)
                }
                try FileManager.default.copyItem(at: importRuleFileURL, to: importRuleDestURL)
                logI("🛡️ _rule_for_import.yml 복사 완료")
            } catch {
                logE("🛡️ _rule_for_import.yml 복사 실패: \\(error)")
            }
        }

        // 3. 로직을 사용하여 파일 쓰기
        var totalWritten = 0
        var collectionSet = Set<String>()

        for snippet in snippets {
            let collectionName = snippet.collection ?? "uncategorized"
            let collectionURL = destRootURL.appendingPathComponent(
                logic.sanitizeFilename(collectionName))

            // Issue701: rawCollection 저장을 위해 snippet 모델에 추가할 필요가 있음
            // 임시로 로깅해서 실제 컬렉션명 확인

            if !FileManager.default.fileExists(atPath: collectionURL.path) {
                try? FileManager.default.createDirectory(
                    at: collectionURL, withIntermediateDirectories: true)
            }

            // 다중 키워드 지원 (쉼표로 구분됨)
            let cleanKeyword = snippet.keyword.trimmingCharacters(
                in: CharacterSet.whitespacesAndNewlines)
            if cleanKeyword.isEmpty { continue }

            var keywords: [String] = []
            // Issue689_12, Issue701: 리터럴 콤마를 포함하는 특수 컬렉션의 경우 콤마로 무지성 split 하지 않음
            let normalizedName = collectionName.precomposedStringWithCanonicalMapping
            let isSpecialLiteralCollection =
                normalizedName == "_emoji" || normalizedName == "_Bullets"
                || normalizedName == "_한글속기".precomposedStringWithCanonicalMapping
                || normalizedName == "_한글 속기".precomposedStringWithCanonicalMapping

            if isSpecialLiteralCollection {
                keywords = [cleanKeyword]
            } else {
                keywords = cleanKeyword.components(separatedBy: ",").map {
                    $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                }
            }

            for key in keywords {
                if key.isEmpty || key == "_" { continue }

                // 로직을 사용하여 파일명 생성
                guard
                    let fileName = logic.generateOptimizedFileName(
                        name: snippet.name, keyword: key, collection: collectionName)
                else {
                    continue
                }

                let fileURL = collectionURL.appendingPathComponent(fileName)
                let finalContent = logic.convertDynamicPlaceholders(snippet.snippet)

                // 덮어쓰기 허용 로직
                do {
                    // 쓰기 전 파일이 존재한다면 덮어씌워짐 (write atomicaly)
                    try finalContent.write(
                        to: fileURL, atomically: true, encoding: String.Encoding.utf8)
                    totalWritten += 1
                    collectionSet.insert(collectionName)
                } catch {
                    logE("🛡️ Failed to write \(fileURL.path)")
                }
            }
        }

        // 4. 아이콘 가져오기 실행 (Issue12: 스니펫 파일 쓰기 완료 후 호출하여 대상 폴더 존재 보장)
        importIcons(dbURL: dbURL, importRulesDict: importRulesDict, destRootURL: destRootURL)

        return .success(ImportedStats(total: totalWritten, collections: collectionSet.count))
    }

    // MARK: - 아이콘 가져오기 로직 (Issue689_8)

    /// Alfred DB 폴더 주변에서 아이콘을 찾아 목적지 폴더에 복사
    /// Alfred의 snippets은 Dropbox의 Alfred3/Alfred.alfredpreferences/snippets/ 경로에 저장됨
    private func importIcons(dbURL: URL, importRulesDict: [String: String], destRootURL: URL) {
        let logic = AlfredLogic.shared
        let fileManager = FileManager.default

        // Alfred의 설정에서 동기화 폴더 경로를 읽음
        // 기본 경로: ~/Library/CloudStorage/Dropbox/Data/Alfred3/
        // snippets 위치: Alfred.alfredpreferences/snippets/

        let prefsPath = NSHomeDirectory() + "/Library/Application Support/Alfred/prefs.json"
        var alfredSnippetsURL: URL?

        // prefs.json에서 동기화 폴더 경로 읽기
        if let prefsData = try? Data(contentsOf: URL(fileURLWithPath: prefsPath)),
            let prefsDict = try? JSONSerialization.jsonObject(with: prefsData) as? [String: Any],
            let syncFolders = prefsDict["syncfolders"] as? [String: String],
            let syncFolder = syncFolders.values.first
        {
            let expandedPath = (syncFolder as NSString).expandingTildeInPath
            let snippetsPath = expandedPath + "/Alfred.alfredpreferences/snippets"
            alfredSnippetsURL = URL(fileURLWithPath: snippetsPath)
            logI("🛡️ importIcons: Alfred snippets 경로 = \(snippetsPath)")
        } else {
            // 폴백: Dropbox 경로 사용
            let fallbackPath =
                NSHomeDirectory()
                + "/Library/CloudStorage/Dropbox/Data/Alfred3/Alfred.alfredpreferences/snippets"
            alfredSnippetsURL = URL(fileURLWithPath: fallbackPath)
            logI("🛡️ importIcons: 폴백 경로 사용 = \(fallbackPath)")
        }

        guard let snippetsURL = alfredSnippetsURL else {
            logW("🛡️ importIcons: Alfred snippets 경로를 찾을 수 없음")
            return
        }

        guard
            let folderContents = try? fileManager.contentsOfDirectory(
                at: snippetsURL, includingPropertiesForKeys: nil)
        else {
            logW("🛡️ importIcons: \(snippetsURL.path)에서 폴더 목록을 읽을 수 없음")
            return
        }

        logI("🛡️ importIcons: \(folderContents.count)개 컬렉션 폴더 찾음")

        for folderURL in folderContents {
            // 폴더만 처리
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDir),
                isDir.boolValue
            else {
                continue
            }

            // 폴더 이름을 컬렉션 이름으로 사용 (Alfred 구조: snippets/[CollectionName]/icon.png)
            let collectionName = folderURL.lastPathComponent

            let iconURL = folderURL.appendingPathComponent("icon.png")

            // 아이콘이 존재하면 적용
            if fileManager.fileExists(atPath: iconURL.path) {
                let mappedCollection = importRulesDict[collectionName] ?? collectionName
                let destFolder = destRootURL.appendingPathComponent(
                    logic.sanitizeFilename(mappedCollection))

                // 대상 폴더가 아직 없을 수 있음
                try? fileManager.createDirectory(at: destFolder, withIntermediateDirectories: true)

                // Issue732: NSWorkspace.setIcon이 macOS 26에서 Finder 미인식 문제 →
                // icon.png를 대상 폴더에 직접 복사하는 방식으로 변경
                let destIconURL = destFolder.appendingPathComponent("icon.png")
                do {
                    if fileManager.fileExists(atPath: destIconURL.path) {
                        try fileManager.removeItem(at: destIconURL)
                    }
                    try fileManager.copyItem(at: iconURL, to: destIconURL)
                    logI("🛡️ 아이콘 복사 성공: \(mappedCollection) → \(destIconURL.path)")
                } catch {
                    logW("🛡️ 아이콘 복사 실패: \(mappedCollection) - \(error.localizedDescription)")
                }
            }
        }

        logI("🛡️ importIcons: 아이콘 임포트 완료")
        // 캐시 무효화: 새로 복사된 icon.png가 즉시 반영되도록
        SnippetIconProvider.shared.clearCache()
    }
}
