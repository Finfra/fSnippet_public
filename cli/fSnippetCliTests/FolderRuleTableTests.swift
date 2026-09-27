//
//  FolderRuleTableTests.swift
//  fSnippetCliTests
//
//  Port of the paidApp (prj15) FolderTest program into XCTest:
//    - Tests/FolderTest/FolderTestRunner.swift
//    - Tests/FolderTest/testTable_org.md (all 35 rows embedded below as data)
//  prj15 playlist #4.
//
//  For every row a sandbox folder with a prefix/suffix rule is created together with
//  both key files (`t<N>.txt`, `test.txt`). Each file must
//    1. get the abbreviation given in the table (`test` replaced by the key),
//    2. resolve back to itself through the exact abbreviation lookup,
//    3. resolve back to itself when its abbreviation is typed into the buffer (findBestMatch).
//

import XCTest

@testable import fSnippetCli

final class FolderRuleTableTests: XCTestCase {

    // MARK: - Data (testTable_org.md)

    private struct Row {
        let id: Int
        let folder: String
        let prefix: String
        let keys: [String]
        let suffix: String
        /// Expected abbreviation of the `test` key.
        let abbreviation: String

        func expectedAbbreviation(for key: String) -> String {
            abbreviation.replacingOccurrences(of: "test", with: key)
        }
    }

    private static let rows: [Row] = [
        Row(
            id: 1, folder: "_case1", prefix: "", keys: ["t1", "test"], suffix: "-",
            abbreviation: "test-"),
        Row(
            id: 2, folder: "_case2", prefix: "-", keys: ["t2", "test"], suffix: "",
            abbreviation: "-test"),
        Row(
            id: 3, folder: "_case3", prefix: "!", keys: ["t3", "test"], suffix: "!",
            abbreviation: "!test!"),
        Row(
            id: 4, folder: "_case4", prefix: "", keys: ["t4", "test"], suffix: "==",
            abbreviation: "test=="),
        Row(
            id: 5, folder: "_case5", prefix: "==", keys: ["t5", "test"], suffix: "",
            abbreviation: "==test"),
        Row(
            id: 6, folder: "_case6", prefix: "@@", keys: ["t6", "test"], suffix: "@@",
            abbreviation: "@@test@@"),
        Row(
            id: 7, folder: "_case7", prefix: "", keys: ["t7", "test"], suffix: "ø",
            abbreviation: "testø"),
        Row(
            id: 8, folder: "_case8", prefix: "ø", keys: ["t8", "test"], suffix: "",
            abbreviation: "øtest"),
        Row(
            id: 9, folder: "_case9", prefix: "…", keys: ["t9", "test"], suffix: "…",
            abbreviation: "…test…"),
        Row(
            id: 10, folder: "_case10", prefix: "", keys: ["t10", "test"], suffix: "ππ",
            abbreviation: "testππ"),
        Row(
            id: 11, folder: "_case11", prefix: "ππ", keys: ["t11", "test"], suffix: "",
            abbreviation: "ππtest"),
        Row(
            id: 12, folder: "_case12", prefix: "¥¥", keys: ["t12", "test"], suffix: "¥¥",
            abbreviation: "¥¥test¥¥"),
        Row(
            id: 13, folder: "_case13", prefix: "", keys: ["t13", "test"], suffix: "{right_command}",
            abbreviation: "test{right_command}"),
        Row(
            id: 14, folder: "_case14", prefix: "{right_command}", keys: ["t14", "test"], suffix: "",
            abbreviation: "{right_command}test"),
        Row(
            id: 15, folder: "_case15", prefix: "¿", keys: ["t15", "test"], suffix: "¿",
            abbreviation: "¿test¿"),
        Row(
            id: 16, folder: "_case16", prefix: "", keys: ["t16", "test"], suffix: "{right_option}",
            abbreviation: "test{right_option}"),
        Row(
            id: 17, folder: "_case17", prefix: "", keys: ["t17", "test"], suffix: "{keypad_comma}",
            abbreviation: "test{keypad_comma}"),
        Row(
            id: 18, folder: "_case18", prefix: "{keypad_comma}", keys: ["t18", "test"], suffix: "",
            abbreviation: "{keypad_comma}test"),
        Row(
            id: 19, folder: "_case19", prefix: "", keys: ["t19", "test"], suffix: "{keypad_num_lock}",
            abbreviation: "test{keypad_num_lock}"),
        Row(
            id: 20, folder: "_case20", prefix: "{keypad_num_lock}", keys: ["t20", "test"], suffix: "{keypad_num_lock}",
            abbreviation: "{keypad_num_lock}test{keypad_num_lock}"),
        Row(
            id: 21, folder: "_case21", prefix: "", keys: ["t21", "test"], suffix: "{f1}",
            abbreviation: "test{f1}"),
        Row(
            id: 22, folder: "_case22", prefix: "{f1}", keys: ["t22", "test"], suffix: "",
            abbreviation: "{f1}test"),
        Row(
            id: 23, folder: "_case23", prefix: "{f2}", keys: ["t23", "test"], suffix: "{f2}",
            abbreviation: "{f2}test{f2}"),
        Row(
            id: 24, folder: "_case24", prefix: "{right_option}", keys: ["t24", "test"], suffix: "-",
            abbreviation: "{right_option}test-"),
        Row(
            id: 25, folder: "_case25", prefix: "{right_option}", keys: ["t25", "test"], suffix: "ø",
            abbreviation: "{right_option}testø"),
        Row(
            id: 26, folder: "_case26", prefix: "{right_option}", keys: ["t26", "test"], suffix: "¥¥",
            abbreviation: "{right_option}test¥¥"),
        Row(
            id: 27, folder: "_case27", prefix: "{right_option}", keys: ["t27", "test"], suffix: "{right_command}",
            abbreviation: "{right_option}test{right_command}"),
        Row(
            id: 28, folder: "_case28", prefix: "{right_option}", keys: ["t28", "test"], suffix: "¿¿",
            abbreviation: "{right_option}test¿¿"),
        Row(
            id: 29, folder: "_case29", prefix: "=", keys: ["t29", "test"], suffix: "{right_option}",
            abbreviation: "=test{right_option}"),
        Row(
            id: 30, folder: "_case30", prefix: "∆", keys: ["t30", "test"], suffix: "{right_option}",
            abbreviation: "∆test{right_option}"),
        Row(
            id: 31, folder: "_case31", prefix: "††", keys: ["t31", "test"], suffix: "{right_option}",
            abbreviation: "††test{right_option}"),
        Row(
            id: 32, folder: "_case32", prefix: "Œ", keys: ["t32", "test"], suffix: "{right_option}",
            abbreviation: "Œtest{right_option}"),
        Row(
            id: 33, folder: "_case33", prefix: "¿¿", keys: ["t33", "test"], suffix: "{right_option}",
            abbreviation: "¿¿test{right_option}"),
        Row(
            id: 34, folder: "_case34", prefix: "", keys: ["t34", "test"], suffix: "{right_control}",
            abbreviation: "test{right_control}"),
        Row(
            id: 35, folder: "_case35", prefix: "{right_control}", keys: ["t35", "test"], suffix: "",
            abbreviation: "{right_control}test"),
    ]

    // MARK: - Sandbox

    private var utils: FolderTestUtils!
    private var sandbox: URL!
    private var originalRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        utils = FolderTestUtils()
        sandbox = try utils.setupSandbox()
        originalRoot = SnippetRepository.shared.rootFolderURL
        SnippetRepository.shared.swapRootForTests(sandbox)
        try buildSandboxTree()
    }

    override func tearDownWithError() throws {
        if let original = originalRoot {
            SnippetRepository.shared.swapRootForTests(original)
            // Drop sandbox rules and restore whatever the original root declares.
            RuleManager.shared.clearRules()
            _ = RuleManager.shared.loadRuleFile(at: original.path)
        }
        utils?.tearDownSandbox()
        utils = nil
        sandbox = nil
        originalRoot = nil
        try super.tearDownWithError()
    }

    /// Same _rule.yml shape as FolderTestRunner (unquoted name, single-quoted values,
    /// empty prefix/suffix omitted), then one file per key.
    private func buildSandboxTree() throws {
        var yaml = "# Auto-generated from testTable_org.md\ncollections:\n"
        for row in Self.rows where !row.prefix.isEmpty || !row.suffix.isEmpty {
            yaml += "  - name: \(row.folder)\n"
            if !row.prefix.isEmpty { yaml += "    prefix: '\(row.prefix)'\n" }
            if !row.suffix.isEmpty { yaml += "    suffix: '\(row.suffix)'\n" }
            yaml += "\n"
        }
        try utils.createRuleFile(content: yaml)

        for row in Self.rows {
            for key in row.keys {
                try utils.createFile(path: "\(row.folder)/\(key).txt", content: "Snippet Content")
            }
        }

        XCTAssertTrue(RuleManager.shared.loadRuleFile(at: sandbox.path), "_rule.yml load failed")
        SnippetFileManager.shared.loadAllSnippets(reason: "FolderRuleTableTests", force: true)
    }

    private func fileURL(_ row: Row, _ key: String) -> URL {
        sandbox.appendingPathComponent("\(row.folder)/\(key).txt")
    }

    private func samePath(_ a: URL, _ b: URL) -> Bool {
        a.resolvingSymlinksInPath().path == b.resolvingSymlinksInPath().path
    }

    // MARK: - Tests

    func testTableHasAllRows() {
        XCTAssertEqual(Self.rows.count, 35)
        XCTAssertEqual(Set(Self.rows.map(\.folder)).count, 35, "folder names must be unique")
    }

    /// Column `abbreviation`: generated key per file.
    func testAbbreviationMatchesTable() {
        for row in Self.rows {
            for key in row.keys {
                let actual = SnippetFileManager.shared.getAbbreviation(for: fileURL(row, key))
                XCTAssertEqual(
                    actual, row.expectedAbbreviation(for: key),
                    "case \(row.id) \(row.folder)/\(key).txt")
            }
        }
    }

    /// FolderTestRunner "t# Test" / "'test' Test": each key resolves back to its own file.
    func testEveryKeyResolvesToItsFile() {
        let matcher = AbbreviationMatcher(snippetFileManager: .shared)
        for row in Self.rows {
            for key in row.keys {
                let url = fileURL(row, key)
                let abbr = SnippetFileManager.shared.getAbbreviation(for: url)
                    .precomposedStringWithCanonicalMapping
                let found = matcher.findSnippetsByAbbreviation(abbr)
                XCTAssertTrue(
                    found.contains { samePath($0.filePath, url) },
                    "case \(row.id) \(row.folder)/\(key).txt abbr='\(abbr)' found=\(found.map(\.filePath.lastPathComponent))")
            }
        }
    }

    /// Typing the abbreviation (tokens kept literal) resolves to the file via the folder rule.
    func testTypedAbbreviationFindsBestMatch() throws {
        let matcher = AbbreviationMatcher(snippetFileManager: .shared)
        for row in Self.rows {
            let rule = try XCTUnwrap(
                RuleManager.shared.getRule(for: row.folder), "case \(row.id): rule missing")
            for key in row.keys {
                let url = fileURL(row, key)
                let buffer = row.expectedAbbreviation(for: key)
                let match = matcher.findBestMatch(in: buffer, rule: rule)
                XCTAssertNotNil(match, "case \(row.id) buffer='\(buffer)': no match")
                if let match = match {
                    XCTAssertTrue(
                        samePath(match.snippet.filePath, url),
                        "case \(row.id) buffer='\(buffer)': matched \(match.snippet.filePath.lastPathComponent)")
                }
            }
        }
    }
}
