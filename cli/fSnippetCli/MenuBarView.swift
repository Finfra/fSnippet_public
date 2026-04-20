import Combine
import SwiftUI

// MARK: - 메뉴바 뷰

/// fSnippetCli 메뉴바 메뉴 구현
/// - About (무조건 활성)
/// - 설정 (유료 버전 분기)
/// - 상태 정보 (활성 스니펫 수, 마지막 확장 시각)
/// - 일시 정지/재개 토글
/// - 로그 경로 열기
/// - 종료
struct MenuBarView: View {
    @State private var isPaused = false

    var body: some View {
        // Issue20: About (무조건 활성)
        Button {
            AboutWindowManager.shared.showAbout()
        } label: {
            Label("About fSnippet", systemImage: "info.circle")
        }

        Divider()

        // Issue20: 설정 (유료 버전 분기)
        // _setting.yml의 settings_hotkey 값으로 단축키 표시
        Button {
            SettingsWindowManager.shared.showSettings()
        } label: {
            Label("Settings...", systemImage: "gearshape")
        }
        .keyboardShortcut(",", modifiers: [.command])

        Divider()

        // 상태 정보 섹션
        Section {
            Label("활성 스니펫: \(SnippetIndexManager.shared.entries.count)개", systemImage: "doc.text")
                .disabled(true)
        }

        Divider()

        // 일시 정지/재개 토글
        Button {
            isPaused.toggle()
            toggleMonitoring()
        } label: {
            if isPaused {
                Label("모니터링 재개", systemImage: "play.fill")
            } else {
                Label("모니터링 일시 정지", systemImage: "pause.fill")
            }
        }

        Divider()

        // 로그 경로 열기
        Button {
            openLogDirectory()
        } label: {
            Label("로그 폴더 열기", systemImage: "folder")
        }

        Divider()

        // 종료
        Button {
            // Issue51 Phase2: 메뉴바 종료 시 brew services stop 선행 (매트릭스: app stop × brew=started)
            // 타임아웃 내 미완료 시 fallback terminate 로 진행하여 종료 흐름 지연 방지.
            BrewServiceSync.onAppStop(timeout: 2.0)
            NSApplication.shared.terminate(nil)
        } label: {
            Label("종료", systemImage: "power")
        }
        .keyboardShortcut("q")
    }

    // MARK: - Actions

    /// 모니터링 일시 정지/재개 토글
    private func toggleMonitoring() {
        // TODO: Phase 2에서 CGEventTapManager와 연동
        if isPaused {
            NSLog("모니터링 일시 정지")
        } else {
            NSLog("모니터링 재개")
        }
    }

    /// 로그 디렉토리를 Finder에서 열기
    private func openLogDirectory() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let logPath = homeDir
            .appendingPathComponent("Documents")
            .appendingPathComponent("finfra")
            .appendingPathComponent("fSnippetData")
            .appendingPathComponent("logs")

        if FileManager.default.fileExists(atPath: logPath.path) {
            NSWorkspace.shared.open(logPath)
        } else {
            NSLog("로그 디렉토리 없음: \(logPath.path)")
        }
    }
}
