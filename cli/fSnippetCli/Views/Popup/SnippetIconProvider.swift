import AppKit
import SwiftUI

/// Snippet 폴더별 아이콘 및 색상 제공자
class SnippetIconProvider {

    static let shared = SnippetIconProvider()

    private let iconCache = NSCache<NSString, NSImage>()

    private init() {
        iconCache.countLimit = 100  // 캐시 제한
    }

    /// 폴더 아이콘 가져오기
    func getIcon(for folderPath: String) -> NSImage {
        if let cached = iconCache.object(forKey: folderPath as NSString) {
            return cached
        }

        // Issue732: macOS 26에서 NSWorkspace.icon(forFile:)가 커스텀 아이콘 미인식 문제 →
        // 폴더 내 icon.png 파일을 우선 사용 (Alfred Import 시 직접 복사됨)
        let iconFilePath = (folderPath as NSString).appendingPathComponent("icon.png")
        let icon: NSImage
        if let pngImage = NSImage(contentsOfFile: iconFilePath) {
            pngImage.size = NSSize(width: 64, height: 64)
            icon = pngImage
        } else {
            // 폴백: NSWorkspace 기본 아이콘
            let workspaceIcon = NSWorkspace.shared.icon(forFile: folderPath)
            workspaceIcon.size = NSSize(width: 64, height: 64)
            icon = workspaceIcon
        }

        iconCache.setObject(icon, forKey: folderPath as NSString)
        return icon
    }

    func clearCache() {
        iconCache.removeAllObjects()
    }

    // MARK: - 레거시 / 백업 로직

    static func iconName(for folderName: String) -> String {
        switch folderName.lowercased() {
        case "bash", "shell": return "terminal"
        case "java": return "cup.and.saucer"
        case "python": return "command"  // "snake.circle" 없음 -> 임시 대체
        case "javascript", "js": return "globe"
        case "swift": return "swift"
        case "docker": return "shippingbox"
        case "git": return "arrow.triangle.branch"
        case "terraform": return "building.2"
        case "ansible": return "server.rack"
        case "kubernetes", "k8s": return "cube.box"
        case "node", "nodejs": return "leaf"
        case "react": return "atom"
        case "vue": return "triangle"
        case "angular": return "a.circle"
        default: return "folder"
        }
    }

    static func iconColor(for folderName: String) -> Color {
        switch folderName.lowercased() {
        case "bash", "shell": return .green
        case "java": return .orange
        case "python": return .blue
        case "javascript", "js": return .yellow
        case "swift": return .orange
        case "docker": return .blue
        case "git": return .red
        case "terraform": return .purple
        case "ansible": return .red
        case "kubernetes", "k8s": return .blue
        case "node", "nodejs": return .green
        case "react": return .cyan
        case "vue": return .green
        case "angular": return .red
        default: return .secondary
        }
    }

    // MARK: - 뷰 빌더

    static func createIcon(for snippet: SnippetEntry, isSelected: Bool = false) -> some View {
        return IconView(snippet: snippet, isSelected: isSelected)
    }

    static func createFolderIcon(folderName: String) -> some View {
        return FolderIconView(folderName: folderName)
    }

    /// 폴더 아이콘 설정 (nil = 제거)
    func setIcon(_ image: NSImage?, forFolderName folderName: String) {
        logD("🎭 [setIcon] folderName: \(folderName), hasImage: \(image != nil)")
        // SnippetFileManager를 통해 경로 해결
        // SnippetFileManager를 사용할 수 있고 getSnippetFolders가 있다고 가정
        guard
            let folderURL = SnippetFileManager.shared.getSnippetFolders().first(where: {
                $0.lastPathComponent == folderName
            })
        else {
            logW("🎭 🎨 [setIcon] Could not find folder URL for: \(folderName)")
            return
        }

        let path = folderURL.path
        if let image = image {
            logD("🎭 [setIcon] Setting icon for path: \(path)")
            NSWorkspace.shared.setIcon(image, forFile: path, options: [])
            iconCache.setObject(image, forKey: path as NSString)
        } else {
            logD("🎭 [setIcon] Removing icon for path: \(path)")
            NSWorkspace.shared.setIcon(nil, forFile: path, options: [])
            iconCache.removeObject(forKey: path as NSString)
        }

        // 변경 알림
        logD("🎭 [setIcon] Posting .snippetFoldersDidChange notification")
        NotificationCenter.default.post(name: .snippetFoldersDidChange, object: nil)
    }

    /// 텍스트를 기반으로 아이콘 이미지 생성
    func generateTextIcon(text: String, color: Color = .blue) -> NSImage? {
        let size = NSSize(width: 512, height: 512)  // 소스용 고해상도
        let image = NSImage(size: size)

        image.lockFocus()

        // 배경
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: 80, yRadius: 80)
        NSColor(color).set()
        path.fill()

        // 텍스트
        let displayText = String(text.prefix(2)).uppercased()
        let fontSize: CGFloat = displayText.count > 1 ? 220 : 300
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: NSColor.white,
        ]

        let stringSize = displayText.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - stringSize.width) / 2,
            y: (size.height - stringSize.height) / 2 - (fontSize * 0.1),  // 기준선에 대한 약간의 조정
            width: stringSize.width,
            height: stringSize.height
        )

        displayText.draw(in: textRect, withAttributes: attributes)

        image.unlockFocus()
        return image
    }

    // MARK: - 컴포넌트

    struct IconView: View {
        let snippet: SnippetEntry
        let isSelected: Bool
        @State private var iconImage: NSImage?

        var body: some View {
            Group {
                if let nsImage = iconImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                } else {
                    // 폴백
                    Image(systemName: SnippetIconProvider.iconName(for: snippet.folderName))
                        .font(.system(size: 16))
                        .foregroundColor(
                            isSelected
                                ? .white : SnippetIconProvider.iconColor(for: snippet.folderName)
                        )
                        .frame(width: 16, height: 16)
                }
            }
            .onAppear {
                loadIcon()
            }
        }

        private func loadIcon() {
            let folderPath = (snippet.filePath.path as NSString).deletingLastPathComponent
            self.iconImage = SnippetIconProvider.shared.getIcon(for: folderPath)
        }
    }

    struct FolderIconView: View {
        let folderName: String
        @State private var iconImage: NSImage?

        var body: some View {
            Group {
                if let nsImage = iconImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    // 폴백
                    Image(systemName: SnippetIconProvider.iconName(for: folderName))
                        .font(.system(size: 24))
                        .foregroundColor(SnippetIconProvider.iconColor(for: folderName))
                }
            }
            .onAppear {
                loadIcon()
            }
            // 변경 감지
            .onReceive(NotificationCenter.default.publisher(for: .snippetFoldersDidChange)) { _ in
                loadIcon()
            }
        }

        private func loadIcon() {
            guard
                let folderURL = SnippetFileManager.shared.getSnippetFolders().first(where: {
                    $0.lastPathComponent == folderName
                })
            else {
                return
            }
            // 캐시 삭제 확인은 provider의 get 메서드에서 처리됨?
            // 알림 시 강제로 새로 고침하는 것이 더 나은가?
            // 사실 setter에 의해 provider 캐시가 삭제되어야 함.
            self.iconImage = SnippetIconProvider.shared.getIcon(for: folderURL.path)
        }
    }
}
