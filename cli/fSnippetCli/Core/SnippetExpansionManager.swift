import Foundation
import Cocoa // for expandingTildeInPath which is NSString extension but good to have


/// 스니펫 및 파일 참조 확장 관리자 (Issue 539)
/// {{Folder/SnippetName}} 및 {{~/path/to/file}} 형태의 중첩 참조를 재귀적으로 처리
class SnippetExpansionManager {
    static let shared = SnippetExpansionManager()
    
    private let maxRecursionDepth = 10
    
    // MARK: - Public API
    
    /// 텍스트 내의 참조 태그를 재귀적으로 확장
    /// - Parameters:
    ///   - content: 확장할 내용
    ///   - basePath: 상대 경로 해결을 위한 기준 경로 (스니펫 파일의 전체 경로)
    func expand(_ content: String, basePath: String? = nil) -> String {
        return resolveReferences(content, stack: [], basePath: basePath)
    }
    
    // MARK: - Internal Logic
    
    private func resolveReferences(_ content: String, stack: [String], basePath: String? = nil) -> String {
        var result = content
        
        // 재귀 깊이 제한 확인
        if stack.count > maxRecursionDepth {
            logW("🔄 [Expansion] Max recursion depth exceeded (\(maxRecursionDepth))")
            return result + "\n[Error: Max depth exceeded]"
        }
        
        // 1. 파일 참조 확장: {{/path/to/file}}, {{~/path/to/file}}, {{./path/to.file}}
        // 정규식: {{([/~.]?.*?)}} (단, 중간에 줄바꿈이 없다고 가정)
        result = expandFileReferences(result, stack: stack, basePath: basePath)
        
        // 2. 스니펫 참조 확장: {{Folder/Snippet}}
        // 정규식: {{Folder/Snippet}} (Folder/Name)
        result = expandSnippetReferences(result, stack: stack, basePath: basePath)
        
        return result
    }
    
    private func expandFileReferences(_ content: String, stack: [String], basePath: String?) -> String {
        var result = content
        // {{/abs/path}}, {{~/user/path}}, {{./rel/path}}, {{../rel/path}} 패턴 매칭
        // 닫는 중괄호 전까지를 경로로 인식
        // Issue 549: Updated regex to include . as start char for relative paths
        let pattern = #"\{\{([/~.][^}]+)\}\}"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        
        // 뒤에서부터 교체하여 인덱스 안정성 확보
        for match in matches.reversed() {
            guard let pathRange = Range(match.range(at: 1), in: result),
                  let fullRange = Range(match.range(at: 0), in: result) else { continue }
            
            let rawPath = String(result[pathRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            var expandedPath = rawPath
            
            // 상대 경로 처리 (./ 또는 ../)
            if rawPath.hasPrefix("./") || rawPath.hasPrefix("../") {
                if let basePath = basePath {
                    let baseURL = URL(fileURLWithPath: basePath).deletingLastPathComponent()
                    let fullURL = baseURL.appendingPathComponent(rawPath).standardized
                    expandedPath = fullURL.path
                } else {
                    logW("🔄 [Expansion] Relative path detected but no basePath provided: \(rawPath)")
                    // 원본 유지 또는 에러 표시? 여기서는 에러 메시지로 대체하여 피드백 제공
                    result.replaceSubrange(fullRange, with: "[Error: Relative path requires saved snippet context]")
                    continue
                }
            } else {
                // 절대 경로 및 홈 디렉토리 확장
                expandedPath = (rawPath as NSString).expandingTildeInPath
            }
            
            // 순환 참조 방지 (파일 경로 기준)
            if stack.contains(where: { $0 == expandedPath }) {
                logW("🔄 [Expansion] Cycle detected for file: \(expandedPath)")
                continue
            }
            
            // 파일 읽기
            if let fileContent = readFileContent(at: expandedPath) {
                // 읽은 내용에 대해 재귀적 확장 수행 (새로운 파일 경로를 basePath로 전달)
                let resolvedContent = resolveReferences(fileContent, stack: stack + [expandedPath], basePath: expandedPath)
                result.replaceSubrange(fullRange, with: resolvedContent)
                logV("🔄 [Expansion] Included file: \(expandedPath)")
            } else {
                logW("🔄 [Expansion] Failed to read file: \(expandedPath)")
                result.replaceSubrange(fullRange, with: "[Error: File not found or binary: \(rawPath)]")
            }
        }
        
        return result
    }
    
    private func expandSnippetReferences(_ content: String, stack: [String], basePath: String?) -> String {
        var result = content
        
        // Regex: {{Folder/Snippet}} (assuming no / or ~ at start to distinguish from file paths if possible, 
        // but file paths captured above check for / or ~ start specifically inside {{}})
        // But what if a snippet folder starts with ~? unlikely.
        // Pattern: {{ (Not / or ~)? ([^/]+) / ([^}]+) }}
        // Simple pattern: {{([^/]+)/([^}]+)}}
        
        // Issue 549: Regex stays same, but we need to ensure we don't match relative paths ./ or ../ which might be caught if folder name is . or ..
        // Actually, folder name usually won't be . or .. alone in typical usage, but careful.
        // The previous regex was `\{\{([^/]+)/([^}]+)\}\}`
        // If we have `{{./file}}`, group 1 is `.` and group 2 is `file`.
        // We added a check `folder.hasPrefix(".")` in previous code to skip these.
        
        let pattern = #"\{\{([^/]+)/([^}]+)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        
        for match in matches.reversed() {
            guard let folderRange = Range(match.range(at: 1), in: result),
                  let nameRange = Range(match.range(at: 2), in: result),
                  let fullRange = Range(match.range(at: 0), in: result) else { continue }
            
            let folder = String(result[folderRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let name = String(result[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // ✅ Issue 539_4: 파일 참조 패턴(~/...) 충돌 방지
            // 파일 경로 식별자(~, /, .)로 시작하면 스니펫 확장을 수행하지 않고 Pass-through
            if folder.hasPrefix("~") || folder.hasPrefix("/") || folder.hasPrefix(".") {
                continue
            }
            
            let key = "\(folder)/\(name)"
            logV("🕵️ [Issue539] Checking snippet reference: \(key)")
            
            if stack.contains(where: { $0.caseInsensitiveCompare(key) == .orderedSame }) {
                logW("🔄 [Issue539] Cycle detected for snippet: \(key)")
                continue
            }
            
            // SnippetIndexManager를 통해 스니펫 검색
            if let entry = SnippetIndexManager.shared.findSnippet(folder: folder, name: name) {
                logV("✅ [Issue539] Found snippet entry: \(entry.filePath.lastPathComponent)")
                if let snippetContent = readFileContent(at: entry.filePath.path) {
                    // Issue 549: Pass the snippet's file path as basePath for its own expansion
                    // This allows the nested snippet to use relative paths like {{./image.png}}
                    let resolvedContent = resolveReferences(snippetContent, stack: stack + [key], basePath: entry.filePath.path)
                    result.replaceSubrange(fullRange, with: resolvedContent)
                    logV("✅ [Issue539] Expanded snippet: \(key)")
                } else {
                    logE("❌ [Issue539] Failed to read content for: \(key)")
                    result.replaceSubrange(fullRange, with: "[Error: Failed to read snippet]")
                }
            } else {
                logW("❌ [Issue539] Snippet not found: \(folder) / \(name)")
                // 디버깅: Exam 폴더의 스니펫 목록 출력
                if folder.lowercased() == "exam" {
                    let examSnippets = SnippetIndexManager.shared.entries.filter { $0.folderName.lowercased() == "exam" }
                    let names = examSnippets.map { "\($0.folderName)/\($0.abbreviation)" }
                    logD("🕵️ [Issue539] Available Exam snippets: \(names)")
                }
            }
        }
        
        return result
    }
    
    private func readFileContent(at path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        
        // 1. 존재 여부 및 디렉토리 확인
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return nil
        }
        
        // 2. 바이너리 확인 (FileUtilities 의존성 사용 여부는 context에 따름, 여기선 간단히 체크하거나 FileUtilities 있다면 사용)
        // Assuming FileUtilities is available as seen in SnippetFileManager.
        if FileUtilities.isBinaryFile(url) {
            logW("🔄 [Expansion] Binary file ignored: \(path)")
            return nil
        }
        
        // 3. 읽기
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
