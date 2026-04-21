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
        // Issue827 Phase B: URL Scheme 우선, rollback 플래그(fsc.disableUrlScheme) 시 REST fallback
        Button {
            PaidAppDetector.openSettings()
        } label: {
            Label("Settings...", systemImage: "gearshape")
        }
        .keyboardShortcut(",", modifiers: [.command])

        Divider()

        // 상태 정보 섹션
        Section {
            Label("Active snippets: \(SnippetIndexManager.shared.entries.count)", systemImage: "doc.text")
                .disabled(true)
        }

        Divider()

        // 일시 정지/재개 토글
        Button {
            isPaused.toggle()
            toggleMonitoring()
        } label: {
            if isPaused {
                Label("Resume Monitoring", systemImage: "play.fill")
            } else {
                Label("Pause Monitoring", systemImage: "pause.fill")
            }
        }

        Divider()

        // 로그 경로 열기
        Button {
            openLogDirectory()
        } label: {
            Label("Open Log Folder", systemImage: "folder")
        }

        // fSnippet (paidApp) 섹션 (Issue52 Phase3)
        if PaidAppDetector.installedURL() != nil {
            Divider()
            Text("fSnippet").font(.caption).foregroundStyle(.secondary)
            Button("Open fSnippet") {
                PaidAppDetector.launch()
            }
            Button("Open fSnippet Settings") {
                PaidAppDetector.openSettings()
            }
            if PaidAppDetector.isRunning() {
                Text("● Running").font(.caption2).foregroundStyle(.green)
            } else {
                Text("○ Stopped").font(.caption2).foregroundStyle(.secondary)
            }
        }

        Divider()

        // 종료
        Button {
            // Issue52 Phase0: applicationWillTerminate 가 단일 수렴점 — brew stop 은 delegate 전담.
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit", systemImage: "power")
        }
        .keyboardShortcut("q")
    }

    // MARK: - Actions

    private func toggleMonitoring() {
        // TODO: Phase 2에서 CGEventTapManager와 연동
        if isPaused {
            NSLog("Pause Monitoring")
        } else {
            NSLog("Resume Monitoring")
        }
    }

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
            NSLog("Log directory not found: \(logPath.path)")
        }
    }
}
