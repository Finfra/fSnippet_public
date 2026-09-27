//
//  TriggerPriorityGreedyDeleteLengthTests.swift
//  fSnippetCliTests
//
//  Port of the paidApp (prj15) standalone regression programs into XCTest:
//    - Tests/UnitTest/Test_Issue562_Priority.swift   (tier / component priority)
//    - Tests/UnitTest/Test_Issue563_Greedy.swift     (longest match wins)
//    - Tests/UnitTest/Test_DeleteLengthSpecialKeys.swift (visual length of special tokens)
//  prj15 playlist #3.
//
//  TriggerProcessor is exercised with an injected AbbreviationMatcher mock, so the
//  priority arbitration in checkForSuffixMatches is tested without real snippet files.
//  SnippetRepository.shared is swapped onto an empty sandbox so the unmocked
//  hasLongerMatches() never sees the host data root.
//

import XCTest

@testable import fSnippetCli

// MARK: - Test doubles

/// Captures the snippet chosen by TriggerProcessor.
private final class CapturingTriggerDelegate: TriggerProcessorDelegate {
    var lastExpandedSnippet: SnippetEntry?
    var lastDeleteLength: Int?

    func performTextReplacement(snippet: SnippetEntry, deleteLength: Int, triggerMethod: String) {
        lastExpandedSnippet = snippet
        lastDeleteLength = deleteLength
    }
}

/// Matcher whose results are decided by a closure per rule.
private class ScriptedAbbreviationMatcher: AbbreviationMatcher {
    var prefixMatchImpl: ((String, RuleManager.CollectionRule) -> AbbreviationMatcher.MatchCandidate?)?
    var bestMatchImpl: ((String, RuleManager.CollectionRule) -> (SnippetEntry, Int)?)?
    var longerMatchesImpl: ((String) -> Bool)?

    override func findPrefixShortcutMatch(buffer: String, rule: RuleManager.CollectionRule)
        -> AbbreviationMatcher.MatchCandidate?
    {
        prefixMatchImpl?(buffer, rule)
    }

    override func findBestMatch(in buffer: String, rule: RuleManager.CollectionRule) -> (
        snippet: SnippetEntry, matchedLength: Int
    )? {
        guard let r = bestMatchImpl?(buffer, rule) else { return nil }
        return (r.0, r.1)
    }

    override func hasLongerMatches(for abbreviation: String) -> Bool {
        if let impl = longerMatchesImpl { return impl(abbreviation) }
        return super.hasLongerMatches(for: abbreviation)
    }
}

final class TriggerPriorityGreedyDeleteLengthTests: XCTestCase {

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
        }
        utils?.tearDownSandbox()
        utils = nil
        sandbox = nil
        originalRoot = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func dummySnippet(id: String, abbreviation: String) -> SnippetEntry {
        SnippetEntry(
            id: id,
            abbreviation: abbreviation,
            filePath: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(id).txt"),
            folderName: "TestFolder",
            fileName: "\(id).txt",
            description: nil,
            snippetDescription: "",
            content: "Content",
            tags: [],
            fileSize: 0,
            modificationDate: Date(),
            isActive: true
        )
    }

    private func rule(_ name: String, prefix: String, suffix: String) -> RuleManager.CollectionRule {
        RuleManager.CollectionRule(name: name, suffix: suffix, prefix: prefix)
    }

    /// F1 key, as in the original test (character forced to "F1" to avoid headless key mapping).
    private let keyInfoF1 = KeyEventInfo(type: .special, character: "F1", keyCode: 122, modifiers: [])

    /// Matcher that answers like the original SmartMockMatcher:
    /// prefix-only rule -> prefix candidate (tier 2), suffix-only -> t3, prefix+suffix -> t1.
    private func smartMatcher(
        t1: SnippetEntry?, t2: SnippetEntry?, t3: SnippetEntry?
    ) -> ScriptedAbbreviationMatcher {
        let m = ScriptedAbbreviationMatcher()
        m.prefixMatchImpl = { _, rule in
            guard !rule.prefix.isEmpty, rule.suffix.isEmpty, let s = t2 else { return nil }
            return AbbreviationMatcher.MatchCandidate(
                snippet: s, deleteLength: 0, triggerMethod: "prefix_shortcut",
                priority: .prefixShortcut, componentPriority: .string,
                description: "Prefix Tier 2")
        }
        m.bestMatchImpl = { _, rule in
            if !rule.suffix.isEmpty && rule.prefix.isEmpty, let s = t3 { return (s, 10) }
            if !rule.suffix.isEmpty && !rule.prefix.isEmpty, let s = t1 { return (s, 10) }
            return nil
        }
        return m
    }

    // MARK: - Test_Issue562_Priority

    func testKeySpecOfF1MatchesRulePrefixToken() {
        // Precondition of the tier tests: the F1 key must be recognised as `{F1}`.
        let spec = keyInfoF1.normalizedKeySpec()
        let wrapped = spec.hasPrefix("{") ? spec : "{\(spec)}"
        XCTAssertEqual(wrapped, "{F1}", "normalizedKeySpec for F1 = '\(spec)'")
    }

    /// Tier 2 (prefix shortcut) beats Tier 3 (suffix only).
    func testTier2PrefixBeatsTier3Suffix() {
        let t2 = dummySnippet(id: "T2", abbreviation: "prefixMatches")
        let t3 = dummySnippet(id: "T3", abbreviation: "suffixMatches")
        let processor = TriggerProcessor(abbreviationMatcher: smartMatcher(t1: nil, t2: t2, t3: t3))
        let delegate = CapturingTriggerDelegate()
        processor.delegate = delegate

        let action = processor.checkForSuffixMatches(
            buffer: "buffer", keyInfo: keyInfoF1,
            rules: [
                rule("RuleSuffix", prefix: "", suffix: "{F1}"),
                rule("RulePrefix", prefix: "{F1}", suffix: ""),
            ])

        XCTAssertEqual(action, .consumed)
        XCTAssertEqual(delegate.lastExpandedSnippet?.id, "T2", "Tier 2 (prefix) must win over Tier 3")
    }

    /// Tier 1 (prefix + suffix) beats Tier 2 (prefix shortcut).
    func testTier1CombinedBeatsTier2Prefix() {
        let t1 = dummySnippet(id: "T1", abbreviation: "combinedMatch")
        let t2 = dummySnippet(id: "T2", abbreviation: "prefixMatches")
        let processor = TriggerProcessor(abbreviationMatcher: smartMatcher(t1: t1, t2: t2, t3: nil))
        let delegate = CapturingTriggerDelegate()
        processor.delegate = delegate

        let action = processor.checkForSuffixMatches(
            buffer: "buffer", keyInfo: keyInfoF1,
            rules: [
                rule("RuleCombined", prefix: "opt+s", suffix: "{F1}"),
                rule("RulePrefix", prefix: "{F1}", suffix: ""),
            ])

        XCTAssertEqual(action, .consumed)
        XCTAssertEqual(delegate.lastExpandedSnippet?.id, "T1", "Tier 1 (combined) must win over Tier 2")
    }

    /// Original Test 3 (adapted): `,` (string) vs `{keypad_comma}` (single), both Tier 3, fired by
    /// the REGULAR comma key. The original expected the `{keypad_comma}` rule to win on component
    /// priority. Since Issue718 (2026-03-02, areKeysEquivalent strict keypad_comma) the regular
    /// comma no longer triggers a `{keypad_comma}` rule at all, so the `,` rule is the only
    /// candidate and must win.
    func testRegularCommaTriggersOnlyCommaRule() {
        let single = dummySnippet(id: "SingleSuffix", abbreviation: "singleSuffix")
        let string = dummySnippet(id: "StringSuffix", abbreviation: "stringSuffix")
        let m = ScriptedAbbreviationMatcher()
        m.bestMatchImpl = { _, rule in
            if rule.name == "RuleString" { return (string, 10) }
            if rule.name == "RuleSingle" { return (single, 10) }
            return nil
        }
        let processor = TriggerProcessor(abbreviationMatcher: m)
        let delegate = CapturingTriggerDelegate()
        processor.delegate = delegate

        let keyInfoComma = KeyEventInfo(type: .special, character: ",", keyCode: 43, modifiers: [])
        let ruleString = rule("RuleString", prefix: "", suffix: ",")
        let ruleSingle = rule("RuleSingle", prefix: "", suffix: "{keypad_comma}")

        let action = processor.checkForSuffixMatches(
            buffer: "buffer", keyInfo: keyInfoComma, rules: [ruleString, ruleSingle])
        XCTAssertEqual(action, .consumed)
        XCTAssertEqual(delegate.lastExpandedSnippet?.id, "StringSuffix")

        // The `{keypad_comma}` rule alone must not fire on the regular comma key.
        delegate.lastExpandedSnippet = nil
        let singleOnly = processor.checkForSuffixMatches(
            buffer: "buffer", keyInfo: keyInfoComma, rules: [ruleSingle])
        XCTAssertEqual(singleOnly, .none, "regular ',' must not trigger a {keypad_comma} rule (Issue718)")
        XCTAssertNil(delegate.lastExpandedSnippet)
    }

    /// Counterpart: the keypad comma key fires the `{keypad_comma}` rule and not the `,` rule.
    func testKeypadCommaTriggersOnlyKeypadCommaRule() {
        let single = dummySnippet(id: "SingleSuffix", abbreviation: "singleSuffix")
        let string = dummySnippet(id: "StringSuffix", abbreviation: "stringSuffix")
        let m = ScriptedAbbreviationMatcher()
        m.bestMatchImpl = { _, rule in
            if rule.name == "RuleString" { return (string, 10) }
            if rule.name == "RuleSingle" { return (single, 10) }
            return nil
        }
        let processor = TriggerProcessor(abbreviationMatcher: m)
        let delegate = CapturingTriggerDelegate()
        processor.delegate = delegate

        let keyInfoKeypadComma = KeyEventInfo(
            type: .special, character: nil, keyCode: 95, modifiers: [])
        let action = processor.checkForSuffixMatches(
            buffer: "buffer", keyInfo: keyInfoKeypadComma,
            rules: [
                rule("RuleString", prefix: "", suffix: ","),
                rule("RuleSingle", prefix: "", suffix: "{keypad_comma}"),
            ])
        XCTAssertEqual(action, .consumed)
        XCTAssertEqual(delegate.lastExpandedSnippet?.id, "SingleSuffix")
    }

    // MARK: - Test_Issue563_Greedy

    /// Two suffix rules match the same buffer; the longer match (`test`) must win over `t`.
    func testGreedyLongestMatchWins() {
        let snippetTest = dummySnippet(id: "Test", abbreviation: "test")
        let snippetT = dummySnippet(id: "T", abbreviation: "t")
        let m = ScriptedAbbreviationMatcher()
        m.bestMatchImpl = { _, rule in
            if rule.name == "RuleA" { return (snippetTest, 18) }  // "test" + suffix
            if rule.name == "RuleB" { return (snippetT, 15) }  // "t" + suffix
            return nil
        }
        m.longerMatchesImpl = { _ in false }
        let processor = TriggerProcessor(abbreviationMatcher: m)
        let delegate = CapturingTriggerDelegate()
        processor.delegate = delegate

        let keyInfo = KeyEventInfo(type: .special, character: nil, keyCode: 95, modifiers: [])
        let action = processor.checkForSuffixMatches(
            buffer: "test{keypad_comma}", keyInfo: keyInfo,
            rules: [
                rule("RuleA", prefix: "", suffix: "{keypad_comma}"),
                rule("RuleB", prefix: "", suffix: "{keypad_comma}"),
            ])

        XCTAssertEqual(action, .consumed)
        XCTAssertEqual(delegate.lastExpandedSnippet?.id, "Test", "longest match must win (Issue 563)")
    }

    // MARK: - Test_DeleteLengthSpecialKeys

    /// Original expectation: `d{keypad_comma}` -> deleteLength 2, written when
    /// SharedKeyMap gave keypad_comma visualCount 1 (Issue555, 2026-02-12). The very next day
    /// paidApp set it back to 0 on user request (68eb3435, 2026-02-13) and cliApp inherited 0:
    /// the keypad comma leaves no visible glyph. The ported property is therefore
    /// "a special token contributes its visualCount, never its literal length":
    ///   d{keypad_comma} -> 1 + 0 = 1,  d{keypad_1} -> 1 + 1 = 2.
    func testDeleteLengthCountsSpecialTokenByVisualCount() {
        let mapper = SingleShortcutMapper.shared
        XCTAssertEqual(mapper.getVisualCount(for: "{keypad_comma}"), 0, "keypad_comma is non-visual")
        XCTAssertEqual(mapper.getVisualCount(for: "{keypad_1}"), 1, "keypad_1 prints one glyph")

        let cases: [(abbr: String, suffix: String, expected: Int)] = [
            ("d{keypad_comma}", "{keypad_comma}", 1),
            ("d{keypad_1}", "{keypad_1}", 2),
        ]
        for c in cases {
            let snippet = SnippetEntry(
                id: c.abbr,
                abbreviation: c.abbr,
                filePath: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fake.txt"),
                folderName: "Docker",
                fileName: "test.txt",
                description: nil,
                snippetDescription: "",
                content: "Snippet Content",
                tags: [],
                fileSize: 0,
                modificationDate: Date(),
                isActive: true
            )
            let docker = RuleManager.CollectionRule(
                name: "Docker", suffix: c.suffix, prefix: "", description: nil, triggerBias: 0)

            let result = DeleteLengthManager().calculate(
                snippet: snippet,
                matchedLength: 2,
                triggeredByKey: true,
                rule: docker,
                effectiveSuffix: c.suffix,
                triggerBias: 0,
                auxBias: 0,
                isKeyBuffered: true,
                matchedString: c.abbr,
                isImplicitTrigger: false
            )

            XCTAssertEqual(
                result.deleteLength, c.expected,
                "\(c.abbr): strategy=\(result.strategy) debug=\(result.debugInfo)")
            XCTAssertEqual(DeleteLengthManager.shared.getVisualLength(of: c.abbr), c.expected)
        }
    }
}
