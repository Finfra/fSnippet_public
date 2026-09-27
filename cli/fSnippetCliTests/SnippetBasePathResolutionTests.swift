//
//  SnippetBasePathResolutionTests.swift
//  fSnippetCliTests
//
//  prj5#Issue99 (found by tdd #10 on jma): `POST /api/v2/settings/advanced/alfred-import/run`
//  passed the raw `snippet_base_path` to the importer. The bundled default is the relative
//  "./snippets", so the importer tried to create "/snippets" (relative to the process cwd "/")
//  and every import on a default config failed with folder_creation_failed.
//  Relative/tilde resolution lives in one place and every consumer must go through it.
//

import XCTest
@testable import fSnippetCli

final class SnippetBasePathResolutionTests: XCTestCase {

    private let root = "/tmp/fsc-root/fSnippetData"

    func testDotSlashIsRelativeToAppRoot() {
        XCTAssertEqual(
            SettingsManager.resolveBasePath("./snippets", appRootPath: root),
            "/tmp/fsc-root/fSnippetData/snippets")
    }

    func testBareRelativeIsRelativeToAppRoot() {
        XCTAssertEqual(
            SettingsManager.resolveBasePath("snippets/sub", appRootPath: root),
            "/tmp/fsc-root/fSnippetData/snippets/sub")
    }

    func testAbsolutePassesThrough() {
        XCTAssertEqual(SettingsManager.resolveBasePath("/data/snips", appRootPath: root), "/data/snips")
    }

    func testTildeExpandsToRealHome() {
        XCTAssertEqual(
            SettingsManager.resolveBasePath("~/snips", appRootPath: root),
            "/Users/\(NSUserName())/snips")
    }

    func testAlfredImportDestinationIsNeverRelative() {
        let prefs = PreferencesManager.shared
        let before: String? = prefs.get("snippet_base_path")
        prefs.set("./snippets", forKey: "snippet_base_path")
        prefs.flush()
        defer {
            prefs.set(before, forKey: "snippet_base_path")
            prefs.flush()
        }

        let dest = APIRouter.alfredImportDestination()
        XCTAssertTrue(dest.hasPrefix("/"), "importer destination must be absolute, got \(dest)")
        XCTAssertEqual(
            dest,
            (PreferencesManager.resolveAppRootPath() as NSString).appendingPathComponent("snippets"))
    }
}
