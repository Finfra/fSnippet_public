//
//  OfficialBuildTests.swift
//  fSnippetCliTests
//
//  tdd #17 official-build-marker (Issue238): DISTRIBUTION-TERMS.md v1.2 §1(b) applies only to
//  Official Builds. Without a marker that exists in the official package and nowhere else,
//  nobody can tell an Official Build from a source build, so the terms have no target.
//  The marker lives in cli/resources/official/ and is bundled only when
//  FSNIPPET_OFFICIAL_BUILD=YES (see _tool/fsc-official-components.sh).
//  tdd #18 official-app-icon (Issue242): the app icon lives there too — source builds show the
//  macOS default icon.
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

    /// CFBundleIconFile of every build; only an Official Build ships Resources/AppIcon.icns.
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

    // MARK: - Official app icon (Issue242)
    //
    // The app icon is a brand asset (NOTICE: Official Build Components). While it sat in the
    // Apache-licensed asset catalog, every source build showed it too.

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

    /// The XCTest host is a plain source build — it must fall back to the macOS default icon.
    func testSourceBuildHostCarriesNoAppIcon() {
        XCTAssertNil(Bundle.main.url(forResource: appIconName, withExtension: "icns"))
        XCTAssertNil(Bundle.main.image(forResource: appIconName))
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "CFBundleIconName"))
    }

    /// Both builds share one Info.plist, so the icon an Official Build installs is picked up
    /// without the build phase editing Info.plist.
    func testInfoPlistNamesTheOfficialIconFile() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String, appIconName)
    }
}
