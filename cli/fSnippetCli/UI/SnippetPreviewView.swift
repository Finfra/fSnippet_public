import SwiftUI

/// 스니펫 미리보기를 위한 통합 뷰 (Issue543, Issue 219)
struct SnippetPreviewView: View {
    let snippet: SnippetEntry
    let fullContent: String
    weak var manager: SnippetPreviewManager?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 헤더
            HStack {
                Text(snippet.snippetDescription.isEmpty ? snippet.fileName : snippet.snippetDescription)
                    .font(.headline)
                    .foregroundColor(.primary) // 동적 색상
                Spacer()
                Text(snippet.folderName)
                    .font(.caption)
                    .padding(4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                    .foregroundColor(.secondary)
            }

            Divider().background(Color.secondary.opacity(0.3))

            // 콘텐츠
            ScrollView {
                Text(fullContent)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary) // 동적 색상
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
