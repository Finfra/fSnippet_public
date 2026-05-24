import SwiftUI

struct HistoryRowView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isListActive: Bool // ✅ CL045_9: Focus State
    let shortcut: String? // ✅ CL027_2: Visual Shortcut Indicator
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            // Icon
            iconView
                .frame(width: 24, height: 24)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(3)

            // Single-line content with overflow indicator
            HStack(spacing: 4) {
                Text(firstLineText)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if extraLineCount > 0 {
                    Text("+\(extraLineCount)L")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize()
                }

                Spacer(minLength: 0)
            }

            // Shortcut indicator
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
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        // ✅ CL045_9: Blue when active list, Gray when preview focus
        .background(isSelected ? (isListActive ? PopupUIConstants.clipboardSelectionColor : Color.gray.opacity(0.2)) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }

    private var firstLineText: String {
        switch item.kind {
        case "plain_text":
            let text = item.text ?? ""
            return text.components(separatedBy: "\n").first ?? text
        case "image":
            return "Image (\(formatSize(item.sizeBytes ?? 0)))"
        case "file_list":
            if let json = item.filelistJson,
               let paths = try? JSONDecoder().decode([String].self, from: Data(json.utf8)),
               let first = paths.first {
                return first
            }
            return "File List"
        default:
            return item.text ?? "Unknown"
        }
    }

    private var extraLineCount: Int {
        switch item.kind {
        case "plain_text":
            let text = item.text ?? ""
            let lines = text.components(separatedBy: "\n")
            return max(0, lines.count - 1)
        case "file_list":
            if let json = item.filelistJson,
               let paths = try? JSONDecoder().decode([String].self, from: Data(json.utf8)) {
                return max(0, paths.count - 1)
            }
            return 0
        default:
            return 0
        }
    }

    @ViewBuilder
    private var iconView: some View {
        // ✅ CL077: Prioritize Image Thumbnail for image items
        if item.kind == "image" {
            HistoryThumbnailView(item: item)
        } else if let bundleId = item.appBundle,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // Fallback to Kind Icon (appBundle is nil)
            switch item.kind {
            case "plain_text":
                Image(systemName: "doc.text")
                    .foregroundColor(.blue)
            case "file_list":
                Image(systemName: "folder")
                    .foregroundColor(.orange)
            default:
                Image(systemName: "questionmark.square")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct HistoryThumbnailView: View {
    let item: ClipboardItem
    @State private var thumbnail: NSImage? = nil

    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .onTapGesture {
                        ImageDetailManager.shared.showImageDetail(item: item)
                    }
            } else {
                Image(systemName: "photo")
                    .foregroundColor(.green.opacity(0.5))
                    .onAppear {
                        loadThumbnail()
                    }
            }
        }
    }

    private func loadThumbnail() {
        guard item.kind == "image", let blobPath = item.blobPath, let blobsDir = ClipboardDB.shared.getBlobsDir() else { return }
        let fileURL = URL(fileURLWithPath: blobsDir).appendingPathComponent(blobPath)

        DispatchQueue.global(qos: .userInteractive).async {
            // ✅ Issue715: Handle missing image files
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                logW("🖼️ [HistoryThumbnailView] Image file missing, removing item \(item.id ?? 0)")
                if let id = item.id {
                    ClipboardDB.shared.deleteItem(id: id)
                }
                return
            }
            if let image = NSImage(contentsOf: fileURL) {
                DispatchQueue.main.async {
                    self.thumbnail = image
                }
            }
        }
    }
}
