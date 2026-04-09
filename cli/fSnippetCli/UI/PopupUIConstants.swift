import Foundation
import CoreGraphics
import SwiftUI

/// 팝업 UI 관련 상수 정의 (Issue 245)
/// - 목적: 윈도우 높이 계산과 SwiftUI 뷰 레이아웃 간의 수치 불일치 방지
struct PopupUIConstants {
    /// 헤더 높이 (검색창 영역)
    static let headerHeight: CGFloat = 36.0
    
    /// 행 높이 (스니펫 항목)
    static let rowHeight: CGFloat = 44.0
    
    /// 윈도우 내부 패딩 (상단/하단 여백 및 보정값)
    static let paddingHeight: CGFloat = 10.0
    
    /// 전체 윈도우 높이 계산
    /// - Parameter rows: 표시할 행 개수
    /// - Returns: 계산된 윈도우 높이
    static func calculateWindowHeight(rows: Int) -> CGFloat {
        return headerHeight + paddingHeight + (CGFloat(rows) * rowHeight)
    }
    
    /// - 검색창(+1) 공간 확보 + Compact Status Bar(26pt)
    static let statusBarHeight: CGFloat = 26.0
    
    static func calculateHistoryWindowHeight(rows: Int, showStatusBar: Bool) -> CGFloat {
        // 엄격한 높이 계산: 헤더(36) + 패딩(10) + 리스트(행 * 44)
        let baseHeight = calculateWindowHeight(rows: rows+2)
        
        if showStatusBar {
            // 컴팩트 상태 표시줄 높이 추가 (26)
            return baseHeight + statusBarHeight 
        } else {
            return baseHeight
        }
    }
    
    // MARK: - Colors (Issue 254)
    static let snippetBackgroundColor = Color.blue.opacity(0.05)
    static let clipboardBackgroundColor = Color.orange.opacity(0.05)
    
    // 선택 색상
    static let snippetSelectionColor = Color.blue.opacity(0.2)
    static let clipboardSelectionColor = Color.orange.opacity(0.15)
}

// MARK: - Shared Visual Effect View
/// 표준 macOS 반투명 효과(Glass/Vibrancy)를 위한 재사용 가능한 VisualEffectView
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    init(material: NSVisualEffectView.Material = .popover, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

