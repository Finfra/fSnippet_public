//
//  OfficialBuildTests.swift
//  fSnippetCliTests
//
//  tdd #17 official-build-marker (Issue238): DISTRIBUTION-TERMS.md v1.2 §1(b) applies only to
//  Official Builds. Without a marker that exists in the official package and nowhere else,
//  nobody can tell an Official Build from a source build, so the terms have no target.
//  The marker lives in cli/resources/official/ and is bundled only when
//  FSNIPPET_OFFICIAL_BUILD=YES (see _tool/fsc-official-components.sh).
//

import XCTest
@testable import fSnippetCli

final class OfficialBuildTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OfficialBuildTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    /// cli/resources/official/ in the repository (the source the build phase copies from).
    private var repoOfficialDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // fSnippetCliTests/
            .deletingLastPathComponent()      // cli/
            .appendingPathComponent("resources/official")
    }

    func testNoBannerWithoutMarker() {
        XCTAssertNil(OfficialBuild.banner(officialDirectory: tempDir))
        XCTAssertNil(OfficialBuild.banner(officialDirectory: nil))
    }

    func testBannerIsFirstLineOfRepositoryMarker() throws {
        let marker = repoOfficialDir.appendingPathComponent(OfficialBuild.markerFileName)
        try FileManager.default.copyItem(
            at: marker, to: tempDir.appendingPathComponent(OfficialBuild.markerFileName))

        let banner = try XCTUnwrap(OfficialBuild.banner(officialDirectory: tempDir))
        XCTAssertTrue(banner.hasPrefix("Finfra Official Build"), banner)
        XCTAssertFalse(banner.contains("\n"))
    }

    func testBlankMarkerIsNotABanner() throws {
        try "\n  \n".write(
            to: tempDir.appendingPathComponent(OfficialBuild.markerFileName),
            atomically: true, encoding: .utf8)
        XCTAssertNil(OfficialBuild.banner(officialDirectory: tempDir))
    }

    /// The XCTest host is a plain source build — it must not carry the marker.
    func testSourceBuildHostCarriesNoMarker() {
        XCTAssertNil(OfficialBuild.current)
    }

    func testVersionShowsDistributionOnlyForOfficialBuild() {
        let data: [String: Any] = ["app": "fSnippetCli", "version": "1.1.1", "build": "42"]

        let official = VersionCommand.rows(from: data, officialBanner: "Finfra Official Build")
        XCTAssertEqual(official.last?.0, "Distribution")
        XCTAssertEqual(official.last?.1, "Finfra Official Build")

        let source = VersionCommand.rows(from: data, officialBanner: nil)
        XCTAssertFalse(source.contains { $0.0 == "Distribution" })
        XCTAssertEqual(source.first?.1, "fSnippetCli")
        XCTAssertEqual(source.map(\.0), ["App", "Version", "Build", "Swift", "macOS Target"])
    }
}
