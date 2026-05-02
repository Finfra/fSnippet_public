//
//  ShortcutBlacklistTests.swift
//  fSnippetCliTests
//
//  Issue90 + Issue96_2: macOS 시스템 표준 단축키 블랙리스트 검증
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
        // Issue90: 명세 14건 + Redo 1건 / Issue96_2: ⌘⇧S, ⌘D, ⌘E, ⌘G 추가 = 19건
        let reserved = ["⌘S", "⌘C", "⌘V", "⌘X", "⌘A", "⌘Z",
                        "⌘N", "⌘O", "⌘P", "⌘F",
                        "⌘Q", "⌘W", "⌘T", "⌘R", "⌘⇧Z",
                        "⌘⇧S", "⌘D", "⌘E", "⌘G"]
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

    // MARK: - Issue96_2 Reserved (추가된 4건)

    func testReservedCmdShiftS() {
        // Issue96_2: ⌘⇧S (Save As) 는 시스템 예약으로 승격
        XCTAssertTrue(ShortcutBlacklist.isReserved("⌘⇧S"), "⌘⇧S (Save As) 는 시스템 예약")
        XCTAssertTrue(ShortcutBlacklist.isReserved("{⌘⇧S}"), "{⌘⇧S} 도 정규화 후 예약")
        XCTAssertTrue(ShortcutBlacklist.isReserved("⌘⇧s"), "⌘⇧s 도 정규화 후 예약")
    }

    func testReservedCmdD() {
        // Issue96_2: ⌘D (Duplicate / Don't Save)
        XCTAssertTrue(ShortcutBlacklist.isReserved("⌘D"), "⌘D 는 시스템 예약")
        XCTAssertTrue(ShortcutBlacklist.isReserved("⌘d"), "⌘d 도 정규화 후 예약")
    }

    func testReservedCmdE() {
        // Issue96_2: ⌘E (Use Selection for Find)
        XCTAssertTrue(ShortcutBlacklist.isReserved("⌘E"), "⌘E 는 시스템 예약")
    }

    func testReservedCmdG() {
        // Issue96_2: ⌘G (Find Next)
        XCTAssertTrue(ShortcutBlacklist.isReserved("⌘G"), "⌘G 는 시스템 예약")
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

    func testNotReservedOtherCmdLetters() {
        // 명세에 없는 ⌘+키 조합은 사용자 자유 (Issue96_2 추가분 제외)
        XCTAssertFalse(ShortcutBlacklist.isReserved("⌘B"), "⌘B 는 명세 외 — 허용")
        XCTAssertFalse(ShortcutBlacklist.isReserved("⌘H"), "⌘H 는 명세 외 — 허용")
    }

    // MARK: - Reason

    func testReasonForReserved() {
        XCTAssertEqual(ShortcutBlacklist.reason(for: "⌘S"), "Save (저장)")
        XCTAssertEqual(ShortcutBlacklist.reason(for: "{⌘V}"), "Paste (붙여넣기)")
    }

    func testReasonForIssue962Additions() {
        // Issue96_2: 4건 사유 매핑 검증
        XCTAssertEqual(ShortcutBlacklist.reason(for: "⌘⇧S"), "Save As (다른 이름으로 저장)")
        XCTAssertEqual(ShortcutBlacklist.reason(for: "⌘D"), "Duplicate (복제) / Don't Save (저장 안 함)")
        XCTAssertEqual(ShortcutBlacklist.reason(for: "⌘E"), "Use Selection for Find (찾기에 사용)")
        XCTAssertEqual(ShortcutBlacklist.reason(for: "⌘G"), "Find Next (다음 찾기)")
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
        // Issue90: 14 + Redo 1 = 15 / Issue96_2: +4 = 19
        XCTAssertEqual(ShortcutBlacklist.count, 19, "블랙리스트는 19개 (명세 14 + Redo + Issue96_2 4건)")
    }
}
