//
//  HistorySettingsPersistTests.swift
//  fSnippetCliTests
//
//  tdd #7 history-settings-persist (Issue205): a history.* value written through the REST
//  path (PreferencesManager.batchUpdate) must survive a later UI-mirror save. Before the fix,
//  a PATCH carrying showStatusBar/showPreview/imageDetail.isFloating fired didSet ->
//  saveUISettings(), which dumped the launch-time snapshot of every history field back over
//  _config.yml (retentionDays.plainText 45 -> 90).
//
//  Runs against the XCTest host's temp data root (RuntimeIsolation), never the user's data.
//

import XCTest
@testable import fSnippetCli

final class HistorySettingsPersistTests: XCTestCase {

    private let prefs = PreferencesManager.shared

    override func setUp() {
        super.setUp()
        XCTAssertTrue(RuntimeIsolation.isHostedByXCTest)
        XCTAssertFalse(
            PreferencesManager.resolveAppRootPath().hasPrefix("/Users/\(NSUserName())/Documents/finfra/fSnippetData"),
            "must not run against the user's data root")
    }

    /// REST write path, identical to APIRouter.handleV2PatchHistory.
    private func restPatch(_ values: [String: Any]) {
        prefs.batchUpdate { config in
            for (k, v) in values { config[k] = v }
        }
        prefs.flush()
    }

    private func assertSurvivesMirrorSave<T: Equatable>(
        key: String, value: T, file: StaticString = #filePath, line: UInt = #line
    ) {
        restPatch([key: value])
        // A PATCH carrying one of the three mirrored fields ends in saveUISettings().
        SettingsObservableObject.shared.saveUISettings()
        prefs.flush()
        let stored: T? = prefs.get(key)
        XCTAssertEqual(stored, value, "\(key) reverted by the UI-mirror save", file: file, line: line)
    }

    func testRetentionDaysPlainTextSurvives() {
        let current: Int = prefs.get("history.retentionDays.plainText") ?? 90
        assertSurvivesMirrorSave(key: "history.retentionDays.plainText", value: current == 45 ? 46 : 45)
    }

    func testRetentionDaysImagesSurvives() {
        let current: Int = prefs.get("history.retentionDays.images") ?? 7
        assertSurvivesMirrorSave(key: "history.retentionDays.images", value: current == 11 ? 12 : 11)
    }

    func testForceInputSourceSurvives() {
        let current: String = prefs.get("history.forceInputSource") ?? ""
        assertSurvivesMirrorSave(key: "history.forceInputSource", value: current == "US" ? "ABC" : "US")
    }

    func testMoveDuplicatesToTopSurvives() {
        let current: Bool = prefs.get("history.moveDuplicatesToTop") ?? false
        assertSurvivesMirrorSave(key: "history.moveDuplicatesToTop", value: !current)
    }

    func testMirroredFieldPatchKeepsEarlierRESTValue() {
        // Exact Issue205 reproduction: change retention via REST, then PATCH showStatusBar
        // (which the router also assigns to the @Published mirror).
        let current: Int = prefs.get("history.retentionDays.plainText") ?? 90
        let target = current == 45 ? 46 : 45
        restPatch(["history.retentionDays.plainText": target])

        let obs = SettingsObservableObject.shared
        let newStatusBar = !obs.historyShowStatusBar
        restPatch(["history.showStatusBar": newStatusBar])
        obs.historyShowStatusBar = newStatusBar
        obs.saveUISettings()
        prefs.flush()

        XCTAssertEqual(prefs.get("history.retentionDays.plainText") as Int?, target)
        XCTAssertEqual(prefs.get("history.showStatusBar") as Bool?, newStatusBar)
    }
}
