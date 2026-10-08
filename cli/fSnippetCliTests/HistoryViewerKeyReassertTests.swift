//
//  HistoryViewerKeyReassertTests.swift
//  fSnippetCliTests
//
//  Issue991: 플레이스홀더 콜백 모드에서 show() 직후의 resign key 는 히스토리 창을 숨기지 않는다
//

import XCTest
@testable import fSnippetCli

final class HistoryViewerKeyReassertTests: XCTestCase {

    func testReassertsInCallbackModeRightAfterShow() {
        XCTAssertTrue(HistoryViewerManager.shouldReassertKey(
            callbackMode: true, elapsedSinceShow: 0.2, alreadyReasserted: false))
    }

    func testNoReassertOutsideCallbackMode() {
        XCTAssertFalse(HistoryViewerManager.shouldReassertKey(
            callbackMode: false, elapsedSinceShow: 0.2, alreadyReasserted: false))
    }

    func testNoReassertAfterGraceInterval() {
        XCTAssertFalse(HistoryViewerManager.shouldReassertKey(
            callbackMode: true,
            elapsedSinceShow: HistoryViewerManager.activationGraceInterval + 0.1,
            alreadyReasserted: false))
    }

    func testReassertOnlyOncePerShow() {
        XCTAssertFalse(HistoryViewerManager.shouldReassertKey(
            callbackMode: true, elapsedSinceShow: 0.3, alreadyReasserted: true))
    }
}
