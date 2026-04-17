import SwiftUI

/// 스니펫 리스트와 프리뷰를 하나의 윈도우 내에서 보여주는 통합 뷰 (Issue 560 재설계)
struct UnifiedSnippetPopupView: View {
    @ObservedObject var viewModel: SnippetPopupViewModel
    @ObservedObject var previewManager = SnippetPreviewManager.shared
    @ObservedObject var settings = SettingsObservableObject.shared

    // UI 상태
    @State private var fullContent: String = ""

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // 좌측: 스니펫 리스트 (메인 좌표 기준점)
            SnippetPopupView(viewModel: viewModel)
                .frame(width: settings.effectivePopupWidth)

            // 구분선
            Divider()
                .background(Color.secondary.opacity(0.3))

            // 우측: 프리뷰 영역
            if let snippet = previewManager.currentSnippet {
                SnippetPreviewView(
                    snippet: snippet, fullContent: fullContent, manager: previewManager
                )
                .frame(width: settings.effectivePopupPreviewWidth)
                .id(snippet.id)  // 스니펫 변경 시 뷰 강제 갱신
            } else {
                // 선택된 스니펫이 없는 경우 빈 영역 처리 (너비 유지하여 레이아웃 고정)
                VStack {
                    Spacer()
                    Text(L10n("popup.preview.empty"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(width: settings.effectivePopupPreviewWidth)
                .background(Color.clear)
            }
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor))
                RoundedRectangle(cornerRadius: 12).fill(PopupUIConstants.snippetBackgroundColor)
            }
        )
        .accessibilityIdentifier("UnifiedSnippetPopupView")
        .onChange(of: previewManager.currentSnippet) { _, newValue in
            updateFullContent(for: newValue)
        }
        .onAppear {
            updateFullContent(for: previewManager.currentSnippet)
        }
    }

    private func updateFullContent(for snippet: SnippetEntry?) {
        guard let snippet = snippet else {
            fullContent = ""
            return
        }

        // 동기적으로 먼저 설정값 반영 시도 후 비동기 로딩
        if !snippet.content.isEmpty {
            self.fullContent = snippet.content
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let content: String
            do {
                content = try String(contentsOf: snippet.filePath, encoding: .utf8)
            } catch {
                content = snippet.content
            }

            DispatchQueue.main.async {
                self.fullContent = content
            }
        }
    }
}
