import CoreServices
import Foundation

/// FSEvents 파일 변경 이벤트 정보
struct FileChangeEvent {
    let path: String
    let flags: FSEventStreamEventFlags

    /// 파일 삭제 이벤트 여부
    var isRemoved: Bool {
        return flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0
    }

    /// 파일(폴더가 아닌) 이벤트 여부
    var isFile: Bool {
        return flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile) != 0
    }

    /// 파일 생성 이벤트 여부
    var isCreated: Bool {
        return flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0
    }

    /// 파일 수정 이벤트 여부
    var isModified: Bool {
        return flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified) != 0
    }

    /// 파일 이름 변경 이벤트 여부
    var isRenamed: Bool {
        return flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0
    }
}

/// Snippet 폴더 변경을 실시간으로 감지하는 클래스
class SnippetFolderWatcher {
    private var eventStream: FSEventStreamRef?
    private let rootFolderURL: URL
    private let callback: (Set<String>) -> Void
    /// 파일 레벨 삭제 이벤트 즉시 콜백 (디바운스 없이 호출)
    private let fileEventCallback: ((FileChangeEvent) -> Void)?

    init(rootFolder: URL, onFileEvent: ((FileChangeEvent) -> Void)? = nil, onChange: @escaping (Set<String>) -> Void) {
        self.rootFolderURL = rootFolder
        self.fileEventCallback = onFileEvent
        self.callback = onChange
    }

    /// 폴더 감시 시작
    func startWatching() {
        guard eventStream == nil else {
            return
        }

        let pathsToWatch = [rootFolderURL.path]
        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
                let watcher = Unmanaged<SnippetFolderWatcher>.fromOpaque(clientCallBackInfo!)
                    .takeUnretainedValue()
                watcher.handleFileSystemEvents(
                    numEvents: numEvents,
                    eventPaths: eventPaths,
                    eventFlags: eventFlags
                )
            },
            &context,
            pathsToWatch as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,  // 1초 지연
            FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )

        guard let eventStream = eventStream else {
            return
        }

        FSEventStreamSetDispatchQueue(eventStream, DispatchQueue.main)

        if FSEventStreamStart(eventStream) {
            // 빈 로그 제거됨
        } else {
            stopWatching()
        }
    }

    /// 폴더 감시 중지
    func stopWatching() {
        guard let eventStream = eventStream else { return }

        FSEventStreamStop(eventStream)
        FSEventStreamInvalidate(eventStream)
        FSEventStreamRelease(eventStream)
        self.eventStream = nil

    }

    private var debounceWorkItem: DispatchWorkItem?
    private var pendingPaths: Set<String> = []

    /// 파일 시스템 이벤트 처리
    private func handleFileSystemEvents(
        numEvents: Int, eventPaths: UnsafeMutableRawPointer,
        eventFlags: UnsafePointer<FSEventStreamEventFlags>
    ) {
        guard
            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String]
        else {
            // logE("⌚ failed to cast eventPaths to [String]") // Optional log
            return
        }

        var newPathsAdded = false

        for i in 0..<numEvents {
            let path = paths[i]
            let flags = eventFlags[i]

            // 관련 없는 이벤트 무시
            guard isRelevantEvent(path: path, flags: flags) else { continue }

            // Issue25: 파일 레벨 이벤트를 즉시 전달 (디바운스 없이)
            // 파일 삭제/생성/수정/이름변경 시 캐시 즉시 무효화를 위해 콜백 호출
            let isFileEvent = flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile) != 0
            if isFileEvent, let fileEventCallback = fileEventCallback {
                let event = FileChangeEvent(path: path, flags: flags)
                fileEventCallback(event)
            }

            pendingPaths.insert(path)
            newPathsAdded = true
        }

        if newPathsAdded {
            debounceWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                let pathsToProcess = self.pendingPaths
                self.pendingPaths.removeAll()
                if !pathsToProcess.isEmpty {
                    self.callback(pathsToProcess)
                }
            }

            debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }
    }

    /// 관련 이벤트인지 확인
    private func isRelevantEvent(path: String, flags: FSEventStreamEventFlags) -> Bool {
        // 루트 폴더 내부의 변경사항만 처리
        guard path.hasPrefix(rootFolderURL.path) else { return false }

        // [Issue Refactoring] 불필요한 재로드를 방지하기 위해 관련 없는 파일/폴더 무시
        // ✅ Issue: Trigger Loop Fix - stats.db (사용 로그) 무시
        let ignoredSubstrings = ["/.DS_Store", "/_stats", "/clipboard", "/.git", "/stats.db"]
        for ignored in ignoredSubstrings {
            if path.contains(ignored) {
                return false
            }
        }

        // 관련 플래그 확인
        let relevantEventFlags = [
            kFSEventStreamEventFlagItemCreated,  // 파일/폴더 생성
            kFSEventStreamEventFlagItemRemoved,  // 파일/폴더 삭제
            kFSEventStreamEventFlagItemRenamed,  // 파일/폴더 이름 변경
            kFSEventStreamEventFlagItemModified,  // 파일 수정
        ]

        // 관련 플래그 중 하나라도 포함되어 있으면 true
        for flag in relevantEventFlags {
            if flags & FSEventStreamEventFlags(flag) != 0 {
                return true
            }
        }

        return false
    }

    deinit {
        stopWatching()
    }
}
