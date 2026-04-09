import Foundation

/// Snippet 인덱스 구축 전용 클래스
class SnippetIndexBuilder {
    private let fileManager = FileManager.default

    /// 이미 로그를 출력한 읽기 실패 파일 경로 추적 (중복 로그 방지)
    private static var loggedReadFailures: Set<String> = []

    /// 지정된 경로에서 스니펫을 스캔하여 엔트리 목록 생성
    func buildEntries(from basePath: String) -> [SnippetEntry] {
        let expandedBase = (basePath as NSString).expandingTildeInPath
        let baseURL = URL(fileURLWithPath: expandedBase)

        guard fileManager.fileExists(atPath: expandedBase) else {
            logW("📑 스니펫 기본 경로가 존재하지 않음: \(expandedBase)")
            return []
        }

        var entries: [SnippetEntry] = []
        scanDirectory(baseURL, entries: &entries)

        logV("📑 인덱스 구축 완료: \(entries.count)개 스니펫")
        return entries
    }

    // MARK: - Private Methods

    private func scanDirectory(_ baseURL: URL, entries: inout [SnippetEntry]) {
        do {
            let folderContents = try fileManager.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for folderURL in folderContents {
                guard try folderURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
                else {
                    continue
                }

                scanSnippetFolder(folderURL, entries: &entries)
            }
        } catch {
            logW("📑 디렉토리 스캔 실패: \(baseURL.path) - \(error.localizedDescription)")
        }
    }

    private func scanSnippetFolder(_ folderURL: URL, entries: inout [SnippetEntry]) {
        let folderName = folderURL.lastPathComponent
        var folderDescription: String?

        do {
            let fileContents = try fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [
                    .isDirectoryKey, .fileSizeKey, .contentModificationDateKey,
                ],
                options: [.skipsHiddenFiles]
            )

            // README.md 파일에서 설명 추출
            if let readmeURL = fileContents.first(where: {
                $0.lastPathComponent.lowercased() == "readme.md"
            }) {
                folderDescription = extractDescriptionFromReadme(readmeURL)
            }

            // 파일들 스캔
            for fileURL in fileContents {
                guard try fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == false
                else {
                    continue
                }

                // README.md, _README.md, z_old는 스킵
                let lowerFileName = fileURL.lastPathComponent.lowercased()
                if lowerFileName == "readme.md" || lowerFileName == "_readme.md"
                    || lowerFileName == "z_old"
                {
                    continue
                }

                // 이미지 파일 및 기타 비텍스트 파일 스킵 (Issue248: icon.png 등)
                let fileName = fileURL.lastPathComponent.lowercased()
                if fileName == "icon.png" || fileName.hasSuffix(".png")
                    || fileName.hasSuffix(".jpg") || fileName.hasSuffix(".jpeg")
                    || fileName.hasSuffix(".gif") || fileName.hasSuffix(".ico")
                {
                    continue
                }

                // Check for binary files (Issue: Avoid "Read Failed" logs for binary files)
                if FileUtilities.isBinaryFile(fileURL) {
                    logV("📑 [IndexBuilder] Binary file detected (Skipped): \(fileName)")
                    continue
                }

                if let entry = createSnippetEntry(
                    fileURL: fileURL,
                    folderName: folderName,
                    folderDescription: folderDescription
                ) {
                    entries.append(entry)
                }
            }
        } catch {
            logW("📑 폴더 스캔 실패: \(folderName) - \(error.localizedDescription)")
        }
    }

    func createSnippetEntry(
        fileURL: URL,
        folderName: String,
        folderDescription: String?
    ) -> SnippetEntry? {
        do {
            let fileName = fileURL.lastPathComponent

            // 설정에서 특수기호 및 제외 파일 확인
            let settings = SettingsManager.shared.load()
            let appSettings = AppSettingManager.shared.setting

            // 제외 파일 체크 (SettingsManager + AppSettingManager)
            if settings.excludedFiles.contains(fileName)
                || appSettings.excludedFiles.contains(fileName)
                || settings.folderExcludedFiles[folderName.lowercased()]?.contains(fileName) == true
            {
                return nil
            }

            // abbreviation 생성 - SnippetFileManager의 getAbbreviation 메서드 사용 (Issue31 === 파싱 포함)
            let abbreviation = SnippetFileManager.shared.getAbbreviation(for: fileURL)

            // 파일 속성 가져오기
            let resourceValues = try fileURL.resourceValues(forKeys: [
                .fileSizeKey, .contentModificationDateKey,
            ])
            let fileSize = resourceValues.fileSize ?? 0
            let modificationDate = resourceValues.contentModificationDate ?? Date()

            // 태그 추출 (폴더명과 파일 확장자 기반)
            var tags = [folderName.lowercased()]
            if !fileURL.pathExtension.isEmpty {
                tags.append(fileURL.pathExtension.lowercased())
            }

            // 파일 내용 읽기 (미리보기용 일부만 저장)
            var content = ""
            do {
                // 전체를 읽어서 앞부분만 저장 (메모리 최적화)
                // 대용량 파일 방지를 위해 prefix 제한
                let fullContent = try String(contentsOf: fileURL, encoding: .utf8)
                content = String(fullContent.prefix(1024))
            } catch {
                let filePath = fileURL.path
                if !SnippetIndexBuilder.loggedReadFailures.contains(filePath) {
                    logW("📑 파일 내용 읽기 실패 (Preview 불가): \(fileURL.lastPathComponent)")
                    SnippetIndexBuilder.loggedReadFailures.insert(filePath)
                }
            }

            // 스니펫 설명(snippetDescription) 파싱 (=== 오른쪽)
            var snippetDescription = ""
            let baseFileName = fileURL.deletingPathExtension().lastPathComponent

            if baseFileName.contains("===") {
                let parts = baseFileName.components(separatedBy: "===")
                if parts.count > 1 {
                    // parts[0]은 키워드, parts[1]은 설명
                    let rawName = parts[1]

                    // SnippetItem의 decodeKeyword 사용
                    snippetDescription = SnippetItem.decodeKeyword(rawName)

                    // _로 끝나는 경우 제거 (SnippetFileManager 로직 참조)
                    if snippetDescription.hasSuffix("_") {
                        snippetDescription = String(snippetDescription.dropLast())
                    }

                    logV(
                        "📑 [IndexBuilder] Parsed Description: '\(fileName)' -> '\(snippetDescription)'"
                    )
                } else {
                    logW("📑 ⚠️ [IndexBuilder] '===' found but split failed for: \(fileName)")
                }
            } else {
                // '==='이 없는 경우 파일명을 설명으로 사용 시도 (폴백)?
                // 아니오, 요구사항은 명확함. '==='이 없으면 설명은 비워둠 (뷰에서 파일명을 보여줌).
            }

            return SnippetEntry(
                id: "\(folderName)/\(fileName)",
                abbreviation: abbreviation,
                filePath: fileURL,
                folderName: folderName,
                fileName: fileName,
                description: folderDescription,
                snippetDescription: snippetDescription,
                content: content,
                tags: tags,
                fileSize: Int64(fileSize),
                modificationDate: modificationDate,
                isActive: true
            )

        } catch {
            logW("📑 스니펫 엔트리 생성 실패: \(fileURL.path) - \(error.localizedDescription)")
            return nil
        }
    }

    func extractDescriptionFromReadme(_ readmeURL: URL) -> String? {
        do {
            let content = try String(contentsOf: readmeURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            // 첫 번째 헤더 다음의 텍스트를 설명으로 사용
            for (index, line) in lines.enumerated() {
                if line.hasPrefix("#") && index + 1 < lines.count {
                    let nextLine = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !nextLine.isEmpty && !nextLine.hasPrefix("#") {
                        return nextLine
                    }
                }
            }

            // 첫 번째 비어있지 않은 줄을 설명으로 사용
            return lines.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        } catch {
            logW("📑 README.md 파싱 실패: \(readmeURL.path) - \(error.localizedDescription)")
            return nil
        }
    }
}
