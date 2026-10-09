//
//  OfficialBuildTests.swift
//  fSnippetCliTests
//
//  tdd #17 official-build-marker (Issue238): DISTRIBUTION-TERMS.md v1.2 §1(b) applies only to
//  Official Builds. Without a marker that exists in the official package and nowhere else,
//  nobody can tell an Official Build from a source build, so the terms have no target.
//  The marker lives in cli/resources/official/ and is bundled only when
//  FSNIPPET_OFFICIAL_BUILD=YES (see _tool/fsc-official-components.sh).
//  tdd #18 official-app-icon (Issue242 → Issue254): the app icon lives there too. It stays a
//  brand asset outside the Apache license, but every build — source builds included — ships it.
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

    /// cli/ in the repository.
    private var repoCliDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // fSnippetCliTests/
            .deletingLastPathComponent()      // cli/
    }

    /// cli/resources/official/ in the repository (the source the build phase copies from).
    private var repoOfficialDir: URL {
        repoCliDir.appendingPathComponent("resources/official")
    }

    /// CFBundleIconFile of every build; every build ships Resources/AppIcon.icns (Issue254).
    private let appIconName = "AppIcon"

    /// The ten images `iconutil -c icns` expects in an .iconset (16–512 pt at 1x and 2x).
    private let iconsetFileNames = [16, 32, 128, 256, 512].flatMap {
        ["icon_\($0)x\($0).png", "icon_\($0)x\($0)@2x.png"]
    }.sorted()

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

    // MARK: - Official app icon (Issue242 → Issue254)
    //
    // The app icon is a brand asset (NOTICE: Official Build Components), so it lives in
    // cli/resources/official/ and not in the Apache-licensed asset catalog (Issue242). Source
    // builds showed the macOS default icon until Issue254 (user decision 2026-10-09): every
    // build now ships the same official icon, made from that iconset by the build phase.

    func testPublicAssetCatalogCarriesNoAppIcon() throws {
        let catalog = repoCliDir.appendingPathComponent("fSnippetCli/Assets.xcassets")
        let items = try FileManager.default.contentsOfDirectory(atPath: catalog.path)
        XCTAssertEqual(items.filter { $0.hasSuffix(".appiconset") }, [])
    }

    func testOfficialIconsetIsComplete() throws {
        let iconset = repoOfficialDir.appendingPathComponent("\(appIconName).iconset")
        let files = try FileManager.default.contentsOfDirectory(atPath: iconset.path)
            .filter { !$0.hasPrefix(".") }
            .sorted()
        XCTAssertEqual(files, iconsetFileNames)
    }

    /// The XCTest host is a plain source build — it must carry the official icon, byte for byte
    /// what `iconutil` makes from the repository iconset (Issue254).
    func testSourceBuildHostCarriesTheOfficialAppIcon() throws {
        let bundled = try XCTUnwrap(
            Bundle.main.url(forResource: appIconName, withExtension: "icns"),
            "source build has no \(appIconName).icns — it would show the macOS default icon")
        XCTAssertNotNil(Bundle.main.image(forResource: appIconName))
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "CFBundleIconName"))

        let expected = tempDir.appendingPathComponent("expected-\(appIconName).icns")
        let iconutil = Process()
        iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        iconutil.arguments = [
            "-c", "icns",
            repoOfficialDir.appendingPathComponent("\(appIconName).iconset").path,
            "-o", expected.path,
        ]
        try iconutil.run()
        iconutil.waitUntilExit()
        XCTAssertEqual(iconutil.terminationStatus, 0)
        XCTAssertEqual(try Data(contentsOf: bundled), try Data(contentsOf: expected))
    }

    /// Both builds share one Info.plist, so the icon the build phase installs is picked up
    /// without the build phase editing Info.plist.
    func testInfoPlistNamesTheOfficialIconFile() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String, appIconName)
    }
}
