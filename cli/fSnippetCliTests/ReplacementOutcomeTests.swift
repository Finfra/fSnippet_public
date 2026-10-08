//
//  ReplacementOutcomeTests.swift
//  fSnippetCliTests
//
//  Issue249: completion (success, error) -> success / cancelled / failed is decided in one place
//

import XCTest
@testable import fSnippetCli

final class ReplacementOutcomeTests: XCTestCase {

    func testSuccess() {
        XCTAssertEqual(ReplacementOutcome.classify(success: true, error: nil), .success)
    }

    func testCancelledWhenNoError() {
        XCTAssertEqual(ReplacementOutcome.classify(success: false, error: nil), .cancelled)
    }

    func testFailedWhenErrorPresent() {
        XCTAssertEqual(ReplacementOutcome.classify(success: false, error: "boom"), .failed("boom"))
    }
}
