import SwiftUI

/// 클립보드 히스토리 리스트와 프리뷰를 하나의 윈도우 내에서 보여주는 통합 뷰 (Issue 543)
struct UnifiedHistoryViewer: View {
    @ObservedObject var viewModel: HistoryViewModel
    @ObservedObject var settings = SettingsObservableObject.shared
    @ObservedObject var clipboardManager = ClipboardManager.shared
    @ObservedObject var previewState = HistoryPreviewState.shared

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // 좌측: 히스토리 리스트
            HistoryViewer(viewModel: viewModel)
                .frame(width: settings.historyViewerWidth)
            
            // 구분선 및 프리뷰 영역
            if settings.historyShowPreview {
                Divider()
                    .background(Color.secondary.opacity(0.3))
                
                if let item = previewState.currentItem {
                    HistoryPreviewView(item: item)
                        .frame(width: settings.historyPreviewWidth)
                        .id(item.id) // 항목 변경 시 뷰 갱신 유도
                } else {
                    // 선택된 항목이 없는 경우 빈 영역 처리
                    VStack {
                        Spacer()
                        Text("viewer.preview.empty")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(width: settings.historyPreviewWidth)
                    .background(Color.clear)
                }
            }
        }
        .padding(.top, 10)
        .background(
            ZStack {
                Color(NSColor.controlBackgroundColor)
                PopupUIConstants.clipboardBackgroundColor
            }
        )
        // 윈도우 전체에 대한 그림자 및 라운딩은 HistoryViewerManager의 NSWindow 설정에서 관리하거나 여기서 오버레이 가능
        // 통합 뷰에서는 개별 컴포넌트의 배경이 겹치지 않도록 주의
    }
}

struct UnifiedHistoryViewer_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedHistoryViewer(viewModel: HistoryViewModel())
    }
}
