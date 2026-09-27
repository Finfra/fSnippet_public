//
//  AbbreviationCalculatorTests.swift
//  fSnippetCliTests
//
//  Issue235: a trailing `_` in the comment part of `keyword===comment_.txt`
//  must not drop the folder prefix.
//

import XCTest
@testable import fSnippetCli

final class AbbreviationCalculatorTests: XCTestCase {

    // Mock folder names (not expected in any user _rule.yml)
    // "Markdownzq" -> auto prefix "m", "ANsiblezq" -> auto prefix "an"
    private let folder = "Markdownzq"
    private let initcapFolder = "ANsiblezq"

    private let calc = AbbreviationCalculator.shared

    /// Trigger symbol appended by the default (non-rule) path for a folder.
    private func symbol(for folderName: String) -> String {
        let settings = SettingsManager.shared.load()
        var raw = settings.folderSymbols[folderName.lowercased()] ?? ""
        if raw.isEmpty && !folderName.hasPrefix("_") { raw = settings.defaultSymbol }
        var sym = (raw == "NumKey,") ? "" : raw
        if sym.count > 1 && !sym.hasPrefix("{") && !sym.hasSuffix("}") { sym = "{\(sym)}" }
        return sym
    }

    private func abbr(_ folderName: String, _ base: String) -> String {
        calc.calcAbbreviation(folderName: folderName, baseFileName: base)
    }

    override func setUp() {
        super.setUp()
        XCTAssertNil(RuleManager.shared.getRule(for: folder), "mock folder must not have a rule")
        XCTAssertNil(RuleManager.shared.getRule(for: initcapFolder), "mock folder must not have a rule")
    }

    // MARK: - Issue235 comparison table

    func testKeywordWithCommentEndingUnderscoreKeepsFolderPrefix() {
        XCTAssertEqual(abbr(folder, "Example===mExample_"), "mExample" + symbol(for: folder))
    }

    func testKeywordWithCommentUnderscoreCopy() {
        XCTAssertEqual(abbr(folder, "e===mExample_ copy"), "me" + symbol(for: folder))
    }

    func testUppercaseSingleKeyword() {
        XCTAssertEqual(abbr(folder, "E===mExample"), "mE" + symbol(for: folder))
    }

    func testLowercaseKeyword() {
        XCTAssertEqual(abbr(folder, "example===mExample"), "mexample" + symbol(for: folder))
    }

    func testLongerKeyword() {
        XCTAssertEqual(abbr(folder, "Examplee===mExample"), "mExamplee" + symbol(for: folder))
    }

    // MARK: - Regression guards

    /// Keyless Initcap file (`===An_.txt`) keeps its dedicated behavior.
    func testKeylessInitcapUnchanged() {
        XCTAssertEqual(abbr(initcapFolder, "===An_"), "An" + symbol(for: initcapFolder))
    }

    /// Keyless lowercase file (`===an.txt`) uses the folder prefix only.
    func testKeylessLowercaseUnchanged() {
        XCTAssertEqual(abbr(initcapFolder, "===an"), "an" + symbol(for: initcapFolder))
    }

    /// A `_` belonging to the keyword itself (`Ab_===x.txt`) is kept as-is.
    func testKeywordOwnUnderscoreUnchanged() {
        XCTAssertEqual(abbr(folder, "Ab_===x"), "mAb_" + symbol(for: folder))
    }
}
