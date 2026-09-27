//
//  RuntimeIsolationTests.swift
//  fSnippetCliTests
//
//  prj5#Issue99 (tdd #0 precondition): the XCTest host boots the full cliApp. Before this
//  guard existed it resolved the *user's* appRootPath (~/Documents/finfra/fSnippetData),
//  started a second CGEventTap, bound REST 3015 and launched the paidApp — i.e. running
//  the unit tests on a machine in use touched the user's live install and data.
//

import XCTest
@testable import fSnippetCli

final class RuntimeIsolationTests: XCTestCase {

    private var realUserDataRoot: String {
        "/Users/\(NSUserName())/Documents/finfra/fSnippetData"
    }

    func testXCTestHostIsDetected() {
        XCTAssertTrue(RuntimeIsolation.isHostedByXCTest)
    }

    func testAppRootPathIsNotUserDataWhenHostedByXCTest() {
        // An explicit ENV override (fSnippetCli_config) still wins; otherwise a temp root.
        guard ProcessInfo.processInfo.environment["fSnippetCli_config"] == nil else { return }
        let resolved = PreferencesManager.resolveAppRootPath()
        XCTAssertNotEqual(resolved, realUserDataRoot)
        XCTAssertFalse(resolved.hasPrefix(realUserDataRoot))
        XCTAssertTrue(resolved.hasPrefix(NSTemporaryDirectory()), "expected temp root, got \(resolved)")
    }

    func testResolvingInTestHostDoesNotPersistAppRootPath() {
        let before = UserDefaults.standard.string(forKey: "appRootPath")
        _ = PreferencesManager.resolveAppRootPath()
        XCTAssertEqual(UserDefaults.standard.string(forKey: "appRootPath"), before)
    }

    func testTestHostDoesNotStartRESTServer() {
        XCTAssertFalse(APIServer.shared.isRunning, "test host must not bind the REST port")
    }

    func testTestHostSkipsLiveSideEffects() {
        XCTAssertFalse(RuntimeIsolation.allowsLiveSideEffects)
    }

    func testIsolatedInstanceFlagIsOptIn() {
        XCTAssertFalse(RuntimeIsolation.isIsolatedInstance(environment: [:]))
        XCTAssertTrue(RuntimeIsolation.isIsolatedInstance(environment: ["fSnippetCli_isolated": "1"]))
        XCTAssertFalse(RuntimeIsolation.isIsolatedInstance(environment: ["fSnippetCli_isolated": "0"]))
    }
}
