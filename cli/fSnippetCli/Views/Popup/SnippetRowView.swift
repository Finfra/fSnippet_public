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
        // ✅ Issue151: 1행 HStack 단순화 (Issue140 클립보드 패턴 차용)
        HStack(spacing: 8) {
            // 1. 폴더 아이콘 (좌측 끝)
            ZStack(alignment: .center) {
                SnippetIconProvider.createIcon(for: snippet, isSelected: isSelected)
            }
            .frame(width: 20, height: 20)

            // 2. abbreviation (monospaced)
            Text(KeyRenderingManager.shared.replaceKeyNamesWithSymbols(in: snippet.abbreviation))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            // 3. displayName (스니펫 설명, 1줄 truncate)
            let displayName = snippet.snippetDescription.isEmpty
                ? (snippet.fileName as NSString).deletingPathExtension
                : snippet.snippetDescription
            Text(displayName)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? Color.white.opacity(0.85) : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            // 4. 폴더 배지 (우측)
            Text(snippet.folderName)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? Color.white.opacity(0.85) : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                )
                .fixedSize(horizontal: true, vertical: false)

            // 5. 단축키 표시기
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

            // 6. 편집 버튼 (selected/hover 시에만)
            if isSelected || isHovered {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
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
