//
//  BrewServiceLabelTests.swift
//  fSnippetCliTests
//
//  tdd #8 brew-service-label (Issue206/209/210): Homebrew moved the launchd label from
//  `homebrew.mxcl.*` to `sh.brew.*`. Recognising only one of them made the launchd-spawned
//  instance think it was a stray copy and exit, leaving an unprivileged instance alive.
//  Both conventions must be recognised everywhere the label is judged.
//

import XCTest
@testable import fSnippetCli

final class BrewServiceLabelTests: XCTestCase {

    func testBothNamespacesMatch() {
        XCTAssertTrue(BrewServiceLabel.matches("sh.brew.fsnippet-cli"))
        XCTAssertTrue(BrewServiceLabel.matches("homebrew.mxcl.fsnippet-cli"))
    }

    func testForeignOrMissingLabelDoesNotMatch() {
        XCTAssertFalse(BrewServiceLabel.matches(nil))
        XCTAssertFalse(BrewServiceLabel.matches(""))
        XCTAssertFalse(BrewServiceLabel.matches("sh.brew.fwarrange-cli"))
        XCTAssertFalse(BrewServiceLabel.matches("application.kr.finfra.fSnippetCli.12345"))
    }

    func testCurrentLabelIsTheNewNamespace() {
        XCTAssertEqual(BrewServiceLabel.current, "sh.brew.fsnippet-cli")
        XCTAssertEqual(BrewServiceLabel.all, ["sh.brew.fsnippet-cli", "homebrew.mxcl.fsnippet-cli"])
    }

    func testLoadedLabelFoundInEitherNamespace() {
        let newStyle = "PID\tStatus\tLabel\n812\t0\tsh.brew.fsnippet-cli\n"
        let oldStyle = "PID\tStatus\tLabel\n812\t0\thomebrew.mxcl.fsnippet-cli\n"
        XCTAssertEqual(BrewServiceLabel.loadedLabel(in: newStyle), "sh.brew.fsnippet-cli")
        XCTAssertEqual(BrewServiceLabel.loadedLabel(in: oldStyle), "homebrew.mxcl.fsnippet-cli")
    }

    func testNotLoadedWhenOnlyOtherServicesListed() {
        let output = "PID\tStatus\tLabel\n1\t0\tsh.brew.fwarrange-cli\n2\t0\tcom.apple.Finder\n"
        XCTAssertNil(BrewServiceLabel.loadedLabel(in: output))
    }

    func testLaunchAgentAndCellarPathsCoverBothLabels() {
        let agents = BrewServiceLabel.launchAgentPaths
        XCTAssertTrue(agents.contains { $0.hasSuffix("/Library/LaunchAgents/sh.brew.fsnippet-cli.plist") })
        XCTAssertTrue(agents.contains { $0.hasSuffix("/Library/LaunchAgents/homebrew.mxcl.fsnippet-cli.plist") })
        XCTAssertTrue(BrewServiceLabel.launchAgentDestPath.hasSuffix("sh.brew.fsnippet-cli.plist"))
        let cellar = BrewServiceLabel.plistSourcePaths
        XCTAssertTrue(cellar.contains("/opt/homebrew/opt/fsnippet-cli/homebrew.mxcl.fsnippet-cli.plist"))
        XCTAssertTrue(cellar.contains("/opt/homebrew/opt/fsnippet-cli/sh.brew.fsnippet-cli.plist"))
    }
}
