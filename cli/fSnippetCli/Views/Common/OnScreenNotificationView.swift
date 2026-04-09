import SwiftUI

/// 화면 중앙에 나타나는 HUD 스타일 알림 뷰
struct OnScreenNotificationView: View {
    let message: String
    let iconName: String
    var fontSize: CGFloat?

    private var effectiveFontSize: CGFloat { fontSize ?? 18 }
    private var effectiveIconSize: CGFloat { fontSize != nil ? fontSize! * 2.4 : 44 }
    private var effectiveWidth: CGFloat { fontSize != nil ? max(220, fontSize! * 16) : 220 }
    private var effectiveHeight: CGFloat { fontSize != nil ? max(130, fontSize! * 8) : 130 }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: effectiveIconSize))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: effectiveFontSize, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
        }
        .frame(width: effectiveWidth, height: effectiveHeight)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.8))
                .shadow(radius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct OnScreenNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        OnScreenNotificationView(message: "Clipboard Paused", iconName: "pause.fill")
            .padding()
            .background(Color.gray)
    }
}
