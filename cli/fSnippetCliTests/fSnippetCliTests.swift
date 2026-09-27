//
//  fSnippetCliTests.swift
//  fSnippetCliTests
//
//  Created by nowage on 2026.04.18.
//

import XCTest
@testable import fSnippetCli

final class fSnippetCliTests: XCTestCase {

    func testExample() throws {
        // Write your test here and use APIs like `XCTAssert` to check expected conditions.
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest
    }

}

/// tdd #16 accessibility-boot-listing (Issue237): 미승인으로 부팅한 **새 프로세스**는
/// 시스템 권한 요청을 정확히 1회 보내 손쉬운 사용 목록에 스스로 올라가야 한다.
/// 승인 상태로 부팅했으면 아무것도 묻지 않는다(평상시 창 금지 — Issue224·227 유지).
final class AccessibilityBootListingTests: XCTestCase {

    func testUngrantedBootRequestsListingOnce() {
        var requests = 0
        let requested = AccessibilityBootListing.runIfNeeded(
            isGranted: { false },
            requestListing: { requests += 1 }
        )
        XCTAssertTrue(requested)
        XCTAssertEqual(requests, 1)
    }

    func testGrantedBootDoesNotAsk() {
        var requests = 0
        let requested = AccessibilityBootListing.runIfNeeded(
            isGranted: { true },
            requestListing: { requests += 1 }
        )
        XCTAssertFalse(requested)
        XCTAssertEqual(requests, 0)
    }
}
