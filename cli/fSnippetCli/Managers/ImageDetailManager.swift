import Cocoa
import SwiftUI

class ImageDetailManager: NSObject, NSWindowDelegate {
    static let shared = ImageDetailManager()

    // 여러 윈도우 관리 (딕셔너리 Key: blobPath)
    private var windows: [String: ImageDetailWindow] = [:]

    private let kOpenWindowsKey = "history.imageDetail.openWindows"

    override init() {
        super.init()
    }

    func restoreOpenWindows() {
        guard let savedPaths = UserDefaults.standard.stringArray(forKey: kOpenWindowsKey) else {
            return
        }

        logI("🖼️️ [ImageDetail] Restoring \(savedPaths.count) windows...")
        for blobPath in savedPaths {
            showImageDetail(blobPath: blobPath)
        }

        // 유효하지 않은 경로는 windows에 추가되지 않았으므로,
        // 성공적으로 열린 윈도우 목록만 다시 저장하여 UserDefaults를 정리(Prune)합니다.
        // ✅ Issue715: Handle missing image files
        if windows.count != savedPaths.count {
            logI(
                "🖼️️ [ImageDetail] Pruned \(savedPaths.count - windows.count) missing windows from UserDefaults."
            )
            saveOpenWindows()
        }
    }

    private func saveOpenWindows() {
        let paths = Array(windows.keys)
        UserDefaults.standard.set(paths, forKey: kOpenWindowsKey)
        logD("🖼️️ [ImageDetail] Saved open windows state: \(paths.count) items")
    }

    func showImageDetail(item: ClipboardItem) {
        guard item.type == .image, let blobPath = item.blobPath else { return }
        showImageDetail(blobPath: blobPath)
    }

    func showImageDetail(blobPath: String) {
        // 1. Resolve Full Path
        guard let blobsDir = ClipboardDB.shared.getBlobsDir() else { return }
        let fullPath = URL(fileURLWithPath: blobsDir).appendingPathComponent(blobPath).path
        // 파일 존재 확인
        if !FileManager.default.fileExists(atPath: fullPath) {
            logW("🖼️ [ImageDetail] Cannot open window. File missing: \(fullPath)")
            // ✅ Issue715: Handle missing image files
            if let id = ClipboardDB.shared.findIdByHash(
                hash: blobPath.replacingOccurrences(of: ".png", with: ""))
            {
                ClipboardDB.shared.deleteItem(id: id)
                logW("🖼️ [ImageDetail] Removed DB item due to missing blob: \(blobPath)")
            }
            return
        }

        // 2. 윈도우가 이미 존재하는지 확인
        if let existingWindow = windows[blobPath] {
            logD("🖼️️ [ImageDetail] Activating existing window for: \(blobPath)")
            existingWindow.makeKeyAndOrderFront(nil)
            // 사용자 상호작용인 경우에만 앱 활성화 (백그라운드 복원 아님)
            // 하지만 복원은 보통 실행 시 발생하며, 이때 앱은 이미 활성 상태임.
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // 3. 윈도우 레벨 설정 확인
        let isFloating = PreferencesManager.shared.bool(
            forKey: "history.imageDetail.isFloating", defaultValue: false)

        // 4. 새 윈도우 생성
        let newWindow = ImageDetailWindow(
            imagePath: fullPath, imageID: blobPath, isFloating: isFloating)
        newWindow.delegate = self  // 닫기 처리를 위한 델리게이트 등록

        // 5. 저장 및 표시
        windows[blobPath] = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        logI("🖼️️ [ImageDetail] Opened new window for: \(blobPath). Total open: \(windows.count)")

        saveOpenWindows()
    }

    func closeAll() {
        for window in windows.values {
            window.close()
        }
        windows.removeAll()
        saveOpenWindows()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? ImageDetailWindow else { return }

        // ID를 사용하여 관리 목록에서 제거
        if windows.removeValue(forKey: window.imageID) != nil {
            logD(
                "🖼️️ [ImageDetail] Window closed and removed: \(window.imageID). Remaining: \(windows.count)"
            )
            saveOpenWindows()
        }
    }
}
