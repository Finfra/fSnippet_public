//
//  TapAsymmetryCounterTests.swift
//  fSnippetCliTests
//
//  Issue233: the tap-side asymmetry counter must only count keyDowns that the tap
//  actually passed through. A swallowed event never reaches the NSEvent monitors,
//  so counting it makes `monN == 0` appear during normal operation.
//

import CoreGraphics
import XCTest
@testable import fSnippetCli

final class TapAsymmetryCounterTests: XCTestCase {

    func testPassedKeyDownIsCounted() {
        var counter = TapAsymmetryCounter()
        counter.record(type: .keyDown, keyCode: 0, passedThrough: true)
        let snap = counter.drain()
        XCTAssertEqual(snap.keyDowns, 1)
        XCTAssertEqual(snap.distinctKeyCodes, 1)
    }

    func testSwallowedKeyDownIsNotCounted() {
        var counter = TapAsymmetryCounter()
        counter.record(type: .keyDown, keyCode: 0, passedThrough: false)
        let snap = counter.drain()
        XCTAssertEqual(snap.keyDowns, 0)
        XCTAssertEqual(snap.distinctKeyCodes, 0)
    }

    func testFlagsChangedIsNeverCounted() {
        var counter = TapAsymmetryCounter()
        counter.record(type: .flagsChanged, keyCode: 54, passedThrough: true)
        XCTAssertEqual(counter.drain().keyDowns, 0)
    }

    /// Issue233 reproduction: three distinct registered shortcuts (or popup Down/Up/Esc)
    /// are all swallowed by the tap. Before the fix this produced distinct == 3 with
    /// monN == 0 — exactly `asymmetryMinTapKeys` — and triggered the false alarm.
    func testThreeDistinctSwallowedKeysDoNotReachAsymmetryThreshold() {
        var counter = TapAsymmetryCounter()
        for keyCode: UInt16 in [125, 126, 53, 125, 126, 53] {
            counter.record(type: .keyDown, keyCode: keyCode, passedThrough: false)
        }
        let snap = counter.drain()
        XCTAssertEqual(snap.distinctKeyCodes, 0)
        XCTAssertLessThan(snap.distinctKeyCodes, CGEventTapManager.asymmetryMinTapKeysForTesting)
    }

    func testMixedPassAndSwallowCountsOnlyPassed() {
        var counter = TapAsymmetryCounter()
        counter.record(type: .keyDown, keyCode: 1, passedThrough: true)
        counter.record(type: .keyDown, keyCode: 2, passedThrough: false)
        counter.record(type: .keyDown, keyCode: 1, passedThrough: true)
        let snap = counter.drain()
        XCTAssertEqual(snap.keyDowns, 2)
        XCTAssertEqual(snap.distinctKeyCodes, 1)
    }

    func testDrainResets() {
        var counter = TapAsymmetryCounter()
        counter.record(type: .keyDown, keyCode: 1, passedThrough: true)
        _ = counter.drain()
        let snap = counter.drain()
        XCTAssertEqual(snap.keyDowns, 0)
        XCTAssertEqual(snap.distinctKeyCodes, 0)
    }
}
