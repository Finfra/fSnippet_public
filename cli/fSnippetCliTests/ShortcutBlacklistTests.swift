//
//  ShortcutBlacklistTests.swift
//  fSnippetCliTests
//
//  Issue90: macOS 시스템 표준 단축키 블랙리스트 검증
//

import XCTest
@testable import fSnippetCli

final class ShortcutBlacklistTests: XCTestCase {

    // MARK: - Reserved (시스템 예약)

    func testReservedCmdS() {
        XCTAssertTrue(ShortcutBlacklist.isReserved("⌘S"), "⌘S (Save) 는 시스템 예약")
    }

    func testReservedCmdC() {
        XCTAssertTrue(ShortcutBlacklist.isReserved("⌘C"), "⌘C (Copy) 는 시스템 예약")
    }

    func testReservedAllStandard() {
        // 명세 14건 + Redo 1건
        let reserved = ["⌘S", "⌘C", "⌘V", "⌘X", "⌘A", "⌘Z",
                        "⌘N", "⌘O", "⌘P", "⌘F",
                        "⌘Q", "⌘W", "⌘T", "⌘R", "⌘⇧Z"]
        for token in reserved {
            XCTAssertTrue(ShortcutBlacklist.isReserved(token), "\(token) 는 예약이어야 함")
        }
    }

    func testReservedWithBraces() {
        // _config.yml 에 중괄호 래핑 형태로 저장된 경우
        XCTAssertTrue(ShortcutBlacklist.isReserved("{⌘S}"), "{⌘S} 도 정규화 후 예약")
    }

    func testReservedLowerCase() {
        // 사용자가 ⌘s 형태로 적은 경우 (정규화로 ⌘S 와 동일 취급)
        XCTAssertTrue(ShortcutBlacklist.isReserved("⌘s"), "⌘s 도 정규화 후 예약")
    }

    // MARK: - Not Reserved (사용자 임의 OK)

    func testNotReservedTripleModifier() {
        // 기존 사용자 단축키 — control+shift+cmd+; 같은 3-modifier 조합은 충돌 없음
        XCTAssertFalse(ShortcutBlacklist.isReserved("^⇧⌘;"))
        XCTAssertFalse(ShortcutBlacklist.isReserved("⌃⇧⌘;"))
    }

    func testNotReservedCtrlShiftSpace() {
        // ⌃⇧Space (snippet popup 기본)
        XCTAssertFalse(ShortcutBlacklist.isReserved("⌃⇧Space"))
    }

    func testNotReservedCmdSemicolon() {
        // ⌘; 는 일부 앱에서 쓰지만 macOS 표준 명세 14건에는 미포함 → 허용
        XCTAssertFalse(ShortcutBlacklist.isReserved("{⌘;}"))
    }

    func testNotReservedEmpty() {
        // 빈 토큰은 등록 자체가 skip 되므로 false
        XCTAssertFalse(ShortcutBlacklist.isReserved(""))
    }

    func testNotReservedCmdShiftS() {
        // ⌘⇧S (Save As 등) 는 명세 외 — 차단하지 않음 (사용자 자유)
        XCTAssertFalse(ShortcutBlacklist.isReserved("⌘⇧S"))
    }

    // MARK: - Reason

    func testReasonForReserved() {
        XCTAssertEqual(ShortcutBlacklist.reason(for: "⌘S"), "Save (저장)")
        XCTAssertEqual(ShortcutBlacklist.reason(for: "{⌘V}"), "Paste (붙여넣기)")
    }

    func testReasonForNotReserved() {
        XCTAssertNil(ShortcutBlacklist.reason(for: "^⇧⌘;"))
        XCTAssertNil(ShortcutBlacklist.reason(for: ""))
    }

    // MARK: - Normalize

    func testNormalizeRemovesBraces() {
        XCTAssertEqual(ShortcutBlacklist.normalize("{⌘S}"), "⌘S")
    }

    func testNormalizeUppercasesLetterKey() {
        XCTAssertEqual(ShortcutBlacklist.normalize("⌘s"), "⌘S")
    }

    func testNormalizeConvertsCarbonControlSymbol() {
        // ⌃ → ^ 정규화 (modifier 영역에서만)
        XCTAssertEqual(ShortcutBlacklist.normalize("⌃S"), "^S")
    }

    // MARK: - Count Sanity

    func testBlacklistCount() {
        // 14개 명세 + Redo 1개 = 15개
        XCTAssertEqual(ShortcutBlacklist.count, 15, "블랙리스트는 15개 (명세 14 + Redo)")
    }
}
