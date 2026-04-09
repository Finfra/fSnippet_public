import SwiftUI

/// Snippet 팝업의 개별 행 뷰
struct SnippetRowView: View {
    let snippet: SnippetEntry
    let isSelected: Bool
    let shortcut: String? // ✅ Issue 230: 빠른 선택 단축키 (예: "⌘1")
    let onTap: () -> Void
    let onEdit: () -> Void // 편집 액션
    let onHover: (Bool) -> Void // 호버 액션
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. 폴더 아이콘 (좌측 끝)
            // 정렬을 위한 고정 프레임 컨테이너
            ZStack(alignment: .center) {
                SnippetIconProvider.createIcon(for: snippet, isSelected: isSelected)
            }
            .frame(width: 20, height: 20)
            
            // 2. 스니펫 정보
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(KeyRenderingManager.shared.replaceKeyNamesWithSymbols(in: snippet.abbreviation))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Spacer()
                    
                    Text(snippet.folderName)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? Color.white.opacity(0.8) : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                        )
                }
                
                HStack(spacing: 6) {
                    // 스니펫 설명 (Issue 219_3)
                    let displayName = snippet.snippetDescription.isEmpty 
                        ? (snippet.fileName as NSString).deletingPathExtension 
                        : snippet.snippetDescription
                    
                    Text(displayName)
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? Color.white.opacity(0.9) : .primary)
                        .lineLimit(1)
                    
                    Spacer()
                }
            }
            
            Spacer() // 후행 컨텐츠 밀기
            
            // 3. 단축키 표시기 (우측)
            if let shortcut = shortcut {
                Text(shortcut)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? .white : .secondary.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
                    )
            }
            
            // 4. 편집 버튼 (우측 끝)
            if isSelected || isHovered {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4) // 44px에 맞추기 위해 패딩 축소
        // ✅ Issue 245 리팩토링: 중앙 집중식 상수 사용
        .frame(height: PopupUIConstants.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            self.isHovered = hovering
            self.onHover(hovering)
        }
        .animation(.none, value: isSelected) // 즉시 업데이트
    }
}

// MARK: - 미리보기

struct SnippetRowView_Previews: PreviewProvider {
    static var previews: some View {
        let snippet = SnippetEntry(
            id: "1",
            abbreviation: "bhead=",
            filePath: URL(fileURLWithPath: "/test/head.sh"),
            folderName: "Bash",
            fileName: "head.sh",
            description: "Display first lines of file",
            snippetDescription: "Head Command",
            content: "head -n 10 file.txt",
            tags: ["bash", "sh"],
            fileSize: 1024,
            modificationDate: Date(),
            isActive: true
        )
        
        VStack(spacing: 8) {
            SnippetRowView(snippet: snippet, isSelected: false, shortcut: "⌘1", onTap: {}, onEdit: {}, onHover: { _ in })
            SnippetRowView(snippet: snippet, isSelected: true, shortcut: "⌘2", onTap: {}, onEdit: {}, onHover: { _ in })
        }
        .frame(width: 350)
        .padding()
    }
}
