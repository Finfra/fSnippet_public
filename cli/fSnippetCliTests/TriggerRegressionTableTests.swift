//
//  TriggerRegressionTableTests.swift
//  fSnippetCliTests
//
//  Port of the paidApp (prj15) standalone regression programs into XCTest:
//    - Tests/UnitTest/RegressionCases.swift + Test_RegressionTable.swift
//    - Tests/UnitTest/Test_UppercaseTrigger.swift
//    - Tests/UnitTest/Test_RightControlTrigger.swift
//    - Tests/UnitTest/Test_KeypadCommaPrefix.swift
//  prj15 playlist #2 (trigger-regression-table).
//
//  Every test builds its own snippet tree under NSTemporaryDirectory and swaps
//  SnippetRepository.shared onto it; the user's data root is never touched.
//

import XCTest

@testable import fSnippetCli

final class TriggerRegressionTableTests: XCTestCase {

    // MARK: - Data (RegressionCases.swift, kept 1:1)

    private struct RegressionCase {
        let id: Int
        let folder: String
        let prefix: String
        let suffix: String
        let keys: [String]
    }

    private static let regressionCases: [RegressionCase] = [
        // 1. Prefix trigger (visual)
        RegressionCase(id: 1, folder: "A_Prefix", prefix: "◊", suffix: "", keys: ["t1", "test"]),
        // 2. Suffix trigger (visual)
        RegressionCase(id: 2, folder: "B_Suffix", prefix: "", suffix: "=", keys: ["t2", "test"]),
        // 3. Prefix + suffix trigger (visual)
        RegressionCase(id: 3, folder: "C_Both", prefix: "◊", suffix: "=", keys: ["t3", "test"]),
        // 4. No prefix, no suffix (implicit)
        RegressionCase(id: 4, folder: "D_None", prefix: "", suffix: "", keys: ["t4", "test"]),
        // 5. Special prefix (non-visual)
        RegressionCase(
            id: 5, folder: "E_KeypadComma", prefix: "{keypad_comma}", suffix: "",
            keys: ["t5", "test"]),
        // 6. Right control prefix (non-visual)
        RegressionCase(
            id: 6, folder: "F_RightControl", prefix: "{right_control}", suffix: "",
            keys: ["t6", "test"]),
        // 7. Uppercase folder (Issue 530)
        RegressionCase(id: 7, folder: "Docker", prefix: "D", suffix: "", keys: ["t7", "test"]),
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

    // MARK: - Helpers

    private func samePath(_ a: URL, _ b: URL) -> Bool {
        a.resolvingSymlinksInPath().path == b.resolvingSymlinksInPath().path
    }

    /// Rebuild snippetMap from the sandbox (loadAllSnippets also reloads the sandbox _rule.yml).
    private func loadSandbox() {
        SnippetFileManager.shared.loadAllSnippets(reason: "TriggerRegressionTableTests", force: true)
    }

    // MARK: - Test_RegressionTable (table-driven)

    /// Every (folder rule, key) pair must produce a non-empty abbreviation that
    /// resolves back to its own file through the exact-abbreviation lookup.
    func testRegressionTable() throws {
        var yaml = "collections:\n"
        for c in Self.regressionCases {
            yaml += "  - name: \(c.folder)\n"
            yaml += "    prefix: '\(c.prefix)'\n"
            yaml += "    suffix: '\(c.suffix)'\n\n"
        }
        try utils.createRuleFile(content: yaml)

        for c in Self.regressionCases {
            for key in c.keys {
                try utils.createFile(
                    path: "\(c.folder)/\(key).txt", content: "Snippet Content for \(key)")
            }
        }

        XCTAssertTrue(RuleManager.shared.loadRuleFile(at: sandbox.path), "_rule.yml load failed")
        loadSandbox()

        let manager = SnippetFileManager.shared
        let matcher = AbbreviationMatcher(snippetFileManager: manager)

        for c in Self.regressionCases {
            for key in c.keys {
                let fileURL = sandbox.appendingPathComponent("\(c.folder)/\(key).txt")
                let abbr = manager.getAbbreviation(for: fileURL)
                let label = "case \(c.id) \(c.folder)/\(key).txt abbr='\(abbr)'"

                XCTAssertFalse(abbr.isEmpty, "\(label): abbreviation must not be empty")
                XCTAssertTrue(abbr.contains(key), "\(label): abbreviation must contain the key")

                let results = matcher.findSnippetsByAbbreviation(abbr)
                XCTAssertTrue(
                    results.contains { samePath($0.filePath, fileURL) },
                    "\(label): exact lookup failed. map[\(abbr)]=\(manager.snippetMap[abbr] ?? [])")
            }
        }
    }

    // MARK: - Test_UppercaseTrigger

    /// Uppercase folder `Docker` contributes auto prefix `d`; lowercase folder `docs` contributes none.
    func testUppercaseFolderGeneratesLowercasePrefix() throws {
        let dockerFile = try utils.createFile(path: "Docker/run.txt", content: "docker run")
        let docsFile = try utils.createFile(path: "docs/help.txt", content: "help me")
        try utils.createRuleFile(content: "")
        loadSandbox()

        let manager = SnippetFileManager.shared
        let dockerAbbr = manager.getAbbreviation(for: dockerFile)
        XCTAssertTrue(dockerAbbr.hasPrefix("drun"), "Docker/run.txt abbr='\(dockerAbbr)'")

        let docsAbbr = manager.getAbbreviation(for: docsFile)
        XCTAssertTrue(docsAbbr.hasPrefix("help"), "docs/help.txt abbr='\(docsAbbr)'")

        let matcher = AbbreviationMatcher(snippetFileManager: manager)
        let results = matcher.findSnippetCandidates(searchTerm: "drun")
        XCTAssertTrue(
            results.contains { samePath($0.filePath, dockerFile) },
            "candidate search for 'drun' must include Docker/run.txt")
    }

    // MARK: - Test_RightControlTrigger

    /// `_RightCtrl` with suffix `{right_control}`: key `a{right_control}`, and buffer `a`
    /// resolves to it through findBestMatch.
    func testRightControlSuffixTrigger() throws {
        let aFile = try utils.createFile(path: "_RightCtrl/a.txt", content: "Right Control Worked")
        try utils.createRuleFile(
            content: """
                collections:
                  - name: "_RightCtrl"
                    prefix: ""
                    suffix: "{right_control}"
                """)
        XCTAssertTrue(RuleManager.shared.loadRuleFile(at: sandbox.path), "_rule.yml load failed")
        loadSandbox()

        let manager = SnippetFileManager.shared
        XCTAssertEqual(manager.getAbbreviation(for: aFile), "a{right_control}")

        let rule = try XCTUnwrap(
            RuleManager.shared.getRule(for: "_RightCtrl"), "rule for _RightCtrl must be loaded")
        XCTAssertEqual(rule.suffix, "{right_control}")

        let matcher = AbbreviationMatcher(snippetFileManager: manager)
        let match = try XCTUnwrap(
            matcher.findBestMatch(in: "a", rule: rule), "buffer 'a' must match _RightCtrl/a.txt")
        XCTAssertEqual(match.snippet.abbreviation, "a{right_control}")
        XCTAssertTrue(samePath(match.snippet.filePath, aFile))
    }

    // MARK: - Test_KeypadCommaPrefix

    /// `_case4` with prefix `{keypad_comma}`: key `{keypad_comma}test`, and the same buffer
    /// resolves to it through findBestMatch.
    func testKeypadCommaPrefixTrigger() throws {
        let testFile = try utils.createFile(
            path: "_case4/test.txt", content: "Keypad Comma Prefix Worked")
        try utils.createRuleFile(
            content: """
                collections:
                  - name: "_case4"
                    prefix: "{keypad_comma}"
                    suffix: ""
                """)
        XCTAssertTrue(RuleManager.shared.loadRuleFile(at: sandbox.path), "_rule.yml load failed")
        loadSandbox()

        let manager = SnippetFileManager.shared
        XCTAssertEqual(manager.getAbbreviation(for: testFile), "{keypad_comma}test")

        let rule = try XCTUnwrap(
            RuleManager.shared.getRule(for: "_case4"), "rule for _case4 must be loaded")
        let matcher = AbbreviationMatcher(snippetFileManager: manager)
        let match = try XCTUnwrap(
            matcher.findBestMatch(in: "{keypad_comma}test", rule: rule),
            "buffer '{keypad_comma}test' must match _case4/test.txt")
        XCTAssertEqual(match.snippet.abbreviation, "{keypad_comma}test")
        XCTAssertTrue(samePath(match.snippet.filePath, testFile))
    }
}
