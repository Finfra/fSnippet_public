//
//  ConfigMigrationTests.swift
//  fSnippetCliTests
//
//  Issue89: _config.yml hotkey 자동 정리 마이그레이션 검증
//

import XCTest
@testable import fSnippetCli

final class ConfigMigrationTests: XCTestCase {

    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fSnippetCliTests-ConfigMigration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true, attributes: nil)
    }

    override func tearDownWithError() throws {
        if let dir = tempDir, FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    // MARK: - Helpers

    private func writeConfig(_ content: String) throws -> URL {
        let url = tempDir.appendingPathComponent("_config.yml")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func readConfig(_ url: URL) throws -> String {
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - parseHotkeyLine

    func testParseHotkeyLineQuoted() {
        let (k, v) = ConfigMigration.parseHotkeyLine(#"  history.viewer.hotkey: "{⌘;}""#)
        XCTAssertEqual(k, "history.viewer.hotkey")
        XCTAssertEqual(v, "{⌘;}")
    }

    func testParseHotkeyLineEmpty() {
        let (k, v) = ConfigMigration.parseHotkeyLine(#"  history.preview.hotkey: """#)
        XCTAssertEqual(k, "history.preview.hotkey")
        XCTAssertEqual(v, "")
    }

    func testParseNonHotkeyLine() {
        let (k, v) = ConfigMigration.parseHotkeyLine(#"  log_level: "info""#)
        XCTAssertNil(k)
        XCTAssertNil(v)
    }

    func testParseCommentLine() {
        let (k, v) = ConfigMigration.parseHotkeyLine("# settings.hotkey: \"⌘S\"")
        XCTAssertNil(k)
        XCTAssertNil(v)
    }

    // MARK: - migrate: idempotent

    func testMigrateNoChanges() throws {
        let content = """
        preferences:
          history.viewer.hotkey: "{⌘;}"
          history.pause.hotkey: "{^⌥⌘P}"
          settings.hotkey: "^⇧⌘;"
          snippet_popup_hotkey: "⌃⇧Space"
          log_level: "info"
        """
        let url = try writeConfig(content)
        let result = ConfigMigration.migrate(at: url)
        XCTAssertFalse(result.hasChanges, "정상 설정은 마이그레이션 무동작")
        XCTAssertEqual(result.blacklisted.count, 0)
        XCTAssertEqual(result.obsolete.count, 0)
        XCTAssertNil(result.backupPath, "변경 없으면 백업 생성 안 함")
    }

    func testMigrateRunTwiceIsIdempotent() throws {
        let content = """
        preferences:
          settings.hotkey: "⌘S"
          history.viewer.hotkey: "{⌘;}"
        """
        let url = try writeConfig(content)
        let r1 = ConfigMigration.migrate(at: url)
        XCTAssertTrue(r1.hasChanges, "1회차는 ⌘S 정리")
        XCTAssertEqual(r1.blacklisted, ["settings.hotkey"])

        let r2 = ConfigMigration.migrate(at: url)
        XCTAssertFalse(r2.hasChanges, "2회차는 무동작 (idempotent)")
    }

    // MARK: - migrate: blacklist

    func testMigrateBlacklistedHotkey() throws {
        let content = """
        preferences:
          history.registerSnippet.hotkey: "⌘S"
          history.viewer.hotkey: "{⌘;}"
          settings.hotkey: "^⇧⌘;"
        """
        let url = try writeConfig(content)
        let result = ConfigMigration.migrate(at: url)
        XCTAssertTrue(result.hasChanges)
        XCTAssertTrue(result.blacklisted.contains("history.registerSnippet.hotkey"))
        XCTAssertNotNil(result.backupPath)

        let after = try readConfig(url)
        XCTAssertTrue(after.contains(#"history.registerSnippet.hotkey: """#),
                      "예약 hotkey는 빈 값으로 정리")
        XCTAssertTrue(after.contains(#""{⌘;}""#), "정상 hotkey는 보존")
        XCTAssertTrue(after.contains(#""^⇧⌘;""#), "정상 hotkey는 보존")
    }

    func testMigrateBlacklistedWithBraces() throws {
        let content = """
        preferences:
          history.registerSnippet.hotkey: "{⌘C}"
        """
        let url = try writeConfig(content)
        let result = ConfigMigration.migrate(at: url)
        XCTAssertTrue(result.hasChanges)
        XCTAssertEqual(result.blacklisted, ["history.registerSnippet.hotkey"])
    }

    // MARK: - migrate: obsolete

    func testMigrateObsoleteKey() throws {
        let content = """
        preferences:
          history.viewer.hotkey: "{⌘;}"
          obsolete_action.hotkey: "⌥;"
          unused.feature.hotkey: "⇧⌘0"
        """
        let url = try writeConfig(content)
        let result = ConfigMigration.migrate(at: url)
        XCTAssertTrue(result.hasChanges)
        XCTAssertEqual(result.obsolete.count, 2)
        XCTAssertTrue(result.obsolete.contains("obsolete_action.hotkey"))
        XCTAssertTrue(result.obsolete.contains("unused.feature.hotkey"))

        let after = try readConfig(url)
        XCTAssertFalse(after.contains("obsolete_action.hotkey"))
        XCTAssertFalse(after.contains("unused.feature.hotkey"))
        XCTAssertTrue(after.contains(#""{⌘;}""#))
    }

    // MARK: - migrate: backup

    func testMigrateBackupPathFormat() throws {
        let content = """
        preferences:
          history.registerSnippet.hotkey: "⌘V"
        """
        let url = try writeConfig(content)
        let result = ConfigMigration.migrate(at: url)
        XCTAssertTrue(result.hasChanges)
        XCTAssertNotNil(result.backupPath)
        let backupName = (result.backupPath! as NSString).lastPathComponent
        XCTAssertTrue(backupName.hasPrefix("_config.yml.backup_"),
                      "백업 파일명은 '_config.yml.backup_YYYYMMDD-HHMMSS' 패턴")
    }

    // MARK: - migrate: missing file

    func testMigrateMissingFile() {
        let url = tempDir.appendingPathComponent("nonexistent.yml")
        let result = ConfigMigration.migrate(at: url)
        XCTAssertFalse(result.hasChanges)
        XCTAssertNil(result.backupPath)
    }

    // MARK: - knownHotkeyKeys sanity

    func testKnownHotkeyKeysContainsAll() {
        // 코드 화이트리스트 6건 확인
        XCTAssertEqual(ConfigMigration.knownHotkeyKeys.count, 6)
        XCTAssertTrue(ConfigMigration.knownHotkeyKeys.contains("history.viewer.hotkey"))
        XCTAssertTrue(ConfigMigration.knownHotkeyKeys.contains("history.pause.hotkey"))
        XCTAssertTrue(ConfigMigration.knownHotkeyKeys.contains("history.preview.hotkey"))
        XCTAssertTrue(ConfigMigration.knownHotkeyKeys.contains("history.registerSnippet.hotkey"))
        XCTAssertTrue(ConfigMigration.knownHotkeyKeys.contains("settings.hotkey"))
        XCTAssertTrue(ConfigMigration.knownHotkeyKeys.contains("snippet_popup_hotkey"))
    }
}
