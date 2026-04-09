import SwiftUI

/// 커스텀 툴팁 모디파이어 (딜레이 없는 즉각적인 툴팁 표시)
struct InstantTooltipModifier<TooltipContent: View>: ViewModifier {
  let tooltipContent: TooltipContent
  @State private var isHovered = false
  var alignment: Alignment = .bottom

  init(alignment: Alignment = .bottom, @ViewBuilder content: () -> TooltipContent) {
    self.alignment = alignment
    self.tooltipContent = content()
  }

  func body(content: Content) -> some View {
    content
      .onHover { hovering in
        withAnimation(.easeInOut(duration: 0.05)) {
          isHovered = hovering
        }
      }
      .overlay(
        Group {
          if isHovered {
            tooltipContent
              .font(.caption)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(
                RoundedRectangle(cornerRadius: 4)
                  .fill(Color(NSColor.windowBackgroundColor).opacity(0.98))
                  .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
              )
              // macOS 시스템 툴팁과 유사한 테두리
              .overlay(
                RoundedRectangle(cornerRadius: 4)
                  .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
              )
              .foregroundColor(.primary)
              // 툴팁 위치 조정 (뷰의 기준점에서 아래로 띄움)
              .offset(y: 30)
              // 텍스트가 잘리지 않도록 크기 고정
              .fixedSize(horizontal: true, vertical: true)
              // 툴팁 자체가 호버 이벤트를 받지 않도록 함
              .allowsHitTesting(false)
              // 다른 뷰 위에 그려지도록 zIndex 설정
              .zIndex(100)
          }
        }, alignment: alignment
      )
  }
}

extension View {
  /// 기본 렌더링 딜레이 없이 마우스 오버 시 즉각 나타나는 커스텀 툴팁을 추가합니다.
  func instantTooltip<TooltipContent: View>(alignment: Alignment = .bottom, @ViewBuilder content: @escaping () -> TooltipContent)
    -> some View
  {
    self.modifier(InstantTooltipModifier(alignment: alignment, content: content))
  }

  /// 문자열 텍스트 툴팁을 즉각 나타내도록 추가합니다.
  func instantTooltip(_ text: String, alignment: Alignment = .bottom) -> some View {
    self.modifier(
      InstantTooltipModifier(alignment: alignment) {
        Text(text)
      })
  }

  /// 다국어 Text 툴팁을 즉각 나타내도록 추가합니다.
  func instantTooltip(_ text: Text, alignment: Alignment = .bottom) -> some View {
    self.modifier(
      InstantTooltipModifier(alignment: alignment) {
        text
      })
  }
}
