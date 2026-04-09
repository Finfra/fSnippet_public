import Foundation

/// 파일 관련 공통 유틸리티 클래스
/// 중복된 파일 처리 로직을 통합하여 코드 품질 향상
struct FileUtilities {
    
    // MARK: - 상수
    
    /// 지원하는 파일 확장자 목록
    static let supportedExtensions: Set<String> = [
        "txt", "text", "md", "markdown",
        "swift", "py", "js", "ts", "jsx", "tsx",
        "java", "kt", "go", "rs", "cpp", "c", "h",
        "php", "rb", "pl", "sh", "bash", "zsh",
        "html", "css", "scss", "sass", "less",
        "json", "xml", "yaml", "yml", "toml",
        "sql", "r", "m", "mm", "cs", "vb",
        "dart", "lua", "scala", "clj", "hs"
    ]
    
    /// 제외할 파일명 목록
    static let excludedFileNames: Set<String> = [
        "readme.md", "README.md", "README.MD", "README.txt",
        ".gitignore", ".gitattributes", ".gitmodules",
        ".DS_Store", "Thumbs.db", "desktop.ini",
        ".vscode", ".idea", ".vs", ".swiftpm",
        "package-lock.json", "yarn.lock", "Gemfile.lock"
    ]
    
    /// 제외할 디렉토리명 목록
    static let excludedDirectories: Set<String> = [
        ".git", ".svn", ".hg", ".bzr",
        "node_modules", "vendor", "target",
        ".build", ".vscode", ".idea", ".vs",
        "__pycache__", ".pytest_cache", ".mypy_cache",
        "dist", "build", "out", "bin", "obj"
    ]
    
    // MARK: - 파일 검증
    
    /// 파일이 지원되는 형식인지 확인
    /// - Parameter url: 확인할 파일 URL
    /// - Returns: 지원 여부
    static func isSupportedFile(_ url: URL) -> Bool {
        let fileName = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()
        
        // 확장자가 없는 파일도 허용 (일부 스크립트 파일)
        if ext.isEmpty {
            return !isExcludedFileName(fileName)
        }
        
        return supportedExtensions.contains(ext) && !isExcludedFileName(fileName)
    }
    
    /// 파일명이 제외 목록에 포함되는지 확인
    /// - Parameter fileName: 확인할 파일명
    /// - Returns: 제외 여부
    static func isExcludedFileName(_ fileName: String) -> Bool {
        let lowerFileName = fileName.lowercased()
        return excludedFileNames.contains { $0.lowercased() == lowerFileName }
    }
    
    /// 디렉토리가 제외 목록에 포함되는지 확인
    /// - Parameter directoryName: 확인할 디렉토리명
    /// - Returns: 제외 여부
    static func isExcludedDirectory(_ directoryName: String) -> Bool {
        let lowerDirName = directoryName.lowercased()
        return excludedDirectories.contains { $0.lowercased() == lowerDirName }
    }
    
    /// 폴더별 제외 파일 확인
    /// - Parameters:
    ///   - fileName: 파일명
    ///   - folderName: 폴더명
    /// - Returns: 제외 여부
    static func isExcluded(_ fileName: String, in folderName: String) -> Bool {
        let settings = SettingsManager.shared.load()
        
        // 전역 제외 파일 확인
        if settings.excludedFiles.contains(fileName.lowercased()) {
            return true
        }
        
        // 폴더별 제외 파일 확인
        if let folderExcluded = settings.folderExcludedFiles[folderName.lowercased()],
           folderExcluded.contains(fileName.lowercased()) {
            return true
        }
        
        return false
    }
    
    // MARK: - 파일 처리
    
    /// 안전한 파일 읽기
    /// - Parameter url: 읽을 파일 URL
    /// - Returns: 파일 내용 (실패 시 nil)
    static func safeReadFile(at url: URL) -> String? {
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            logE("🛠️ 파일 읽기 실패: \(url.path) - \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 파일 크기 계산
    /// - Parameter url: 파일 URL
    /// - Returns: 파일 크기 (바이트)
    static func getFileSize(at url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            logW("🛠️ ⚠️ 파일 크기 계산 실패: \(url.path)")
            return 0
        }
    }
    
    /// 파일 수정 날짜 가져오기
    /// - Parameter url: 파일 URL
    /// - Returns: 수정 날짜
    static func getModificationDate(at url: URL) -> Date {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.modificationDate] as? Date ?? Date()
        } catch {
            logV("🛠️ 파일 수정 날짜 가져오기 실패: \(url.path)")
            return Date()
        }
    }
    
    /// 디렉토리 생성 (필요한 경우)
    /// - Parameter url: 생성할 디렉토리 URL
    /// - Returns: 생성 성공 여부
    @discardableResult
    static func createDirectoryIfNeeded(at url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            return true
        } catch {
            logE("🛠️ 디렉토리 생성 실패: \(url.path) - \(error.localizedDescription)")
            return false
        }
    }

    /// 파일이 바이너리인지 확인 (Null Byte 기반)
    /// - Parameter url: 확인할 파일 URL
    /// - Returns: 바이너리 여부
    static func isBinaryFile(_ url: URL) -> Bool {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            
            // 처음 1024 바이트만 읽어서 확인
            let data = handle.readData(ofLength: 1024)
            
            // Null Byte(0x00)가 포함되어 있으면 바이너리로 간주
            // (UTF-16/32 텍스트 파일의 경우 오판 가능성 있으나, 현재 스니펫은 UTF-8 위주)
            if let _ = data.firstIndex(of: 0) {
                return true
            }
            
            return false
        } catch {
            logW("🛠️ 바이너리 확인 실패: \(url.path) - \(error.localizedDescription)")
            return false // 읽지 못하면 일단 텍스트로 가정하거나 에러 처리? 
                         // 안전하게 false 반환하고 읽기 시도 시 에러날 것임
        }
    }
    
    // MARK: - 폴더 심볼 처리
    
    /// 폴더명에서 대문자 추출
    /// - Parameter folderName: 폴더명
    /// - Returns: 추출된 대문자들을 소문자로 변환
    static func extractCapitalLetters(from folderName: String) -> String {
        // 폴더명의 대문자를 추출한 후 소문자로 변환해서 prefix로 사용
        // 예: Bash → B → b, MyFolder → MF → mf
        let capitals = String(folderName.compactMap { $0.isUppercase ? $0 : nil })
        return capitals.lowercased()
    }
    
    /// 폴더 심볼 생성 (사용자 설정 우선)
    /// - Parameter folderName: 폴더명
    /// - Returns: 폴더 심볼
    static func getFolderSymbol(for folderName: String) -> String {
        let settings = SettingsManager.shared.load()
        
        // 사용자 정의 심볼 확인
        if let customSymbol = settings.folderSymbols[folderName.lowercased()] {
            return customSymbol
        }
        
        // 기본 규칙: 대문자 추출
        let extracted = extractCapitalLetters(from: folderName)
        return extracted.isEmpty ? String(folderName.lowercased().prefix(1)) : extracted
    }
    
    // MARK: - 스니펫 ID 생성
    
    /// 고유한 스니펫 ID 생성
    /// - Parameters:
    ///   - folderName: 폴더명
    ///   - fileName: 파일명
    /// - Returns: 고유 ID
    static func generateSnippetID(folderName: String, fileName: String) -> String {
        let folderPart = folderName.lowercased().replacingOccurrences(of: " ", with: "_")
        let filePart = fileName.lowercased().replacingOccurrences(of: " ", with: "_")
        return "\(folderPart)_\(filePart)_\(Date().timeIntervalSince1970)"
    }
    
    /// Abbreviation 생성
    /// - Parameters:
    ///   - folderName: 폴더명
    ///   - fileName: 파일명 (확장자 제외)
    ///   - triggerKey: 트리거 키
    /// - Returns: Abbreviation
    static func generateAbbreviation(folderName: String, fileName: String, triggerKey: String) -> String {
        let folderSymbol = getFolderSymbol(for: folderName)
        let fileNameWithoutExtension = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        return "\(folderSymbol)\(fileNameWithoutExtension)\(triggerKey)"
    }
}

// MARK: - FileManager 확장

extension FileManager {
    
    /// 안전한 파일 열거
    /// - Parameter directory: 디렉토리 URL
    /// - Returns: 파일 URL 배열
    func safeContentsOfDirectory(at directory: URL) -> [URL] {
        do {
            return try contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { !FileUtilities.isExcludedDirectory($0.lastPathComponent) }
        } catch {
            logE("🛠️ 디렉토리 내용 읽기 실패: \(directory.path) - \(error.localizedDescription)")
            return []
        }
    }
}