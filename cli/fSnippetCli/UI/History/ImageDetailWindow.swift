import Cocoa
import SwiftUI

struct ImageDetailView: View {
    let imagePath: String

    var body: some View {
        ZStack {
            Group {
                if let image = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                } else {
                    Text("Image load failed")
                        .foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 400, minHeight: 300)
            .background(Material.ultraThin)

            // ✅ CL100: CMD+S 누를 때 파일 저장창 호출
            Button("") {
                DispatchQueue.main.async {
                    let savePanel = NSSavePanel()
                    savePanel.title = "Save Image"
                    savePanel.nameFieldStringValue =
                        URL(fileURLWithPath: imagePath).lastPathComponent
                    savePanel.canCreateDirectories = true
                    savePanel.allowedContentTypes = [.png, .jpeg]

                    if savePanel.runModal() == .OK, let url = savePanel.url {
                        do {
                            if FileManager.default.fileExists(atPath: imagePath) {
                                let data = try Data(contentsOf: URL(fileURLWithPath: imagePath))
                                try data.write(to: url)
                                print("👓 [ImageDetailView] Image Saved Successfully.")
                            }
                        } catch {
                            print(
                                "👓 [ImageDetailView] Image save failed: \(error.localizedDescription)"
                            )
                        }
                    }
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .opacity(0)
        }
    }
}

class ImageDetailWindow: NSWindow {
    let imageID: String  // Unique ID for management

    init(imagePath: String, imageID: String, isFloating: Bool) {
        self.imageID = imageID
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.title = "Image Detail"
        self.setAccessibilityIdentifier("ImageDetailWindow")  // XCUITest 식별자
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.level = isFloating ? .floating : .normal
        self.isReleasedWhenClosed = false
        self.center()

        let contentView = ImageDetailView(imagePath: imagePath)
        self.contentView = NSHostingView(rootView: contentView)
    }
}
