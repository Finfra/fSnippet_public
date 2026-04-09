import SwiftUI

struct HistoryRowView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isListActive: Bool // ✅ CL045_9: Focus State
    let shortcut: String? // ✅ CL027_2: Visual Shortcut Indicator
    var onDelete: (() -> Void)? = nil
    
    @State private var isHovered: Bool = false
    @State private var isPopoverPresented: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon / Preview
            iconView
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(kindLabel)
                        .font(.caption2).bold()
                        .foregroundColor(.secondary)
                    Spacer()
                    
                    Text(timeString)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    // ✅ Shortcut Indicator
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
                    
                    if isHovered || isSelected {
                        Button(action: { onDelete?() }) {
                            Image(systemName: "trash")
                                .font(.caption2)
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .transition(.opacity)
                    }
                }
                
                contentPreview
                    .font(.system(size: 13))
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        // ✅ CL045_9: Blue when active list, Gray when preview focus
        .background(isSelected ? (isListActive ? PopupUIConstants.clipboardSelectionColor : Color.gray.opacity(0.2)) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
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
    
    private var kindLabel: String {
        switch item.kind {
        case "plain_text": return "TEXT"
        case "image": return "IMAGE"
        case "file_list": return "FILES"
        default: return item.kind.uppercased()
        }
    }
    
    private var timeString: String {
        let date = Date(timeIntervalSince1970: TimeInterval(item.createdAt))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    @ViewBuilder
    private var contentPreview: some View {
        switch item.kind {
        case "plain_text":
            if let text = item.text, text.count > 300 {
                HStack(alignment: .top, spacing: 4) {
                    Text(text.prefix(100) + "...")
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Button(action: {
                        isPopoverPresented = true
                    }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .popover(isPresented: $isPopoverPresented) {
                        ScrollView {
                            Text(text)
                                .padding()
                                .frame(width: 400, height: 300, alignment: .topLeading) // Fixed size popover
                        }
                    }
                }
            } else {
                Text(item.text ?? "")
            }
        case "image":
            Text("Image (\(formatSize(item.sizeBytes ?? 0)))")
                .italic()
        case "file_list":
            if let json = item.filelistJson, let paths = try? JSONDecoder().decode([String].self, from: Data(json.utf8)) {
                if paths.count == 1 {
                    Text(paths[0])
                } else {
                    Text("\(paths[0]) and \(paths.count - 1) more...")
                }
            } else {
                Text("File List")
            }
        default:
            Text("Unknown Content")
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
