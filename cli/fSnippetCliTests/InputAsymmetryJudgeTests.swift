//
//  InputAsymmetryJudgeTests.swift
//  fSnippetCliTests
//
//  tdd #6 watchdog-same-key-repeat (Issue229/230/231): the input-path asymmetry watchdog
//  must not declare permission loss for
//    * the same key held/repeated (only 1 distinct keyCode on the tap side) — Issue231
//    * a single asymmetric window that does not repeat (burst artifact)      — Issue230
//    * typing into cliApp's own window (Local Monitor feeds the monitor count) — Issue229
//  and must still confirm a sustained asymmetry across consecutive windows.
//

import XCTest
@testable import fSnippetCli

final class InputAsymmetryJudgeTests: XCTestCase {

    func testSameKeyRepeatNeverConfirms() {
        var judge = InputAsymmetryJudge()
        for _ in 0..<10 {
            // Many keyDowns of one key while the global monitor is silent.
            XCTAssertEqual(judge.evaluate(tapDistinctKeys: 1, monitorKeys: 0), .normal)
        }
    }

    func testSingleAsymmetricWindowIsOnlySuspect() {
        var judge = InputAsymmetryJudge()
        XCTAssertEqual(judge.evaluate(tapDistinctKeys: 3, monitorKeys: 0), .suspect)
        XCTAssertEqual(judge.evaluate(tapDistinctKeys: 5, monitorKeys: 4), .normal)
        // The streak was broken — another single hit is again only a suspicion.
        XCTAssertEqual(judge.evaluate(tapDistinctKeys: 3, monitorKeys: 0), .suspect)
    }

    func testIdleWindowBreaksTheStreak() {
        var judge = InputAsymmetryJudge()
        XCTAssertEqual(judge.evaluate(tapDistinctKeys: 4, monitorKeys: 0), .suspect)
        XCTAssertEqual(judge.evaluate(tapDistinctKeys: 0, monitorKeys: 0), .normal)
        XCTAssertEqual(judge.evaluate(tapDistinctKeys: 4, monitorKeys: 0), .suspect)
    }

    func testOwnWindowTypingCountsAsMonitorAlive() {
        // Typing into cliApp's own window: the Global Monitor sees nothing, but the Local
        // Monitor reports into the same counter, so monitorKeys > 0.
        var judge = InputAsymmetryJudge()
        for _ in 0..<5 {
            XCTAssertEqual(judge.evaluate(tapDistinctKeys: 6, monitorKeys: 6), .normal)
        }
    }

    func testSustainedAsymmetryIsConfirmed() {
        var judge = InputAsymmetryJudge()
        XCTAssertEqual(judge.evaluate(tapDistinctKeys: 3, monitorKeys: 0), .suspect)
        XCTAssertEqual(judge.evaluate(tapDistinctKeys: 3, monitorKeys: 0), .confirmed)
        XCTAssertEqual(judge.consecutiveHits, 2)
    }

    func testThresholdsMatchTheWatchdog() {
        XCTAssertEqual(InputAsymmetryJudge.minTapDistinctKeys, 3)
        XCTAssertEqual(InputAsymmetryJudge.confirmThreshold, 2)
        XCTAssertEqual(CGEventTapManager.asymmetryMinTapKeysForTesting, InputAsymmetryJudge.minTapDistinctKeys)
    }
}
