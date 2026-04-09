import Foundation

/// Snippet 인덱스 엔트리 구조체
struct SnippetEntry {
    let id: String
    let abbreviation: String
    let filePath: URL
    let folderName: String
    let fileName: String
    let description: String? // Folder description
    let snippetDescription: String // From filename (=== right side)
    let content: String // File content (or preview)
    let tags: [String]
    let fileSize: Int64
    let modificationDate: Date
    let isActive: Bool
    
    /// 검색 관련성 점수 계산
    func relevanceScore(for searchTerm: String) -> Double {
        let lowerSearchTerm = searchTerm.lowercased()
        let lowerAbbrev = abbreviation.lowercased()
        
        // 완전 일치
        if lowerAbbrev == lowerSearchTerm { return 100.0 }
        
        // 접두사 일치
        if lowerAbbrev.hasPrefix(lowerSearchTerm) {
            return 80.0 - Double(lowerAbbrev.count - lowerSearchTerm.count) * 2.0
        }
        
        // 포함 여부
        if lowerAbbrev.contains(lowerSearchTerm) {
            return 60.0 - Double(lowerAbbrev.count - lowerSearchTerm.count)
        }
        
        // 태그 일치
        for tag in tags {
            if tag.lowercased().contains(lowerSearchTerm) {
                return 40.0
            }
        }
        
        // 설명 일치 (Folder Description)
        if let desc = description, desc.lowercased().contains(lowerSearchTerm) {
            return 20.0
        }
        
        // 스니펫 설명 일치 (Snippet Description from filename)
        if snippetDescription.lowercased().contains(lowerSearchTerm) {
            return 30.0 // Higher priority than folder description
        }
        
        return 0.0
    }
}

// MARK: - SnippetEntry Hashable & Equatable

extension SnippetEntry: Hashable, Equatable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SnippetEntry, rhs: SnippetEntry) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Issue 178 & 243: Popup Search Scope
public enum PopupSearchScope: String, Codable, CaseIterable {
    case abbreviation = "abbreviation"
    case name = "name"
    case content = "content"
    
    var displayName: String {
        switch self {
        case .abbreviation: return "Keyword"
        case .name: return "Keyword+Name"
        case .content: return "Keyword+Name+Content"
        }
    }
}
