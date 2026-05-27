//
//  FolderTestRunnerTests.swift
//  fSnippetCliTests
//
//  Issue123: 메인 fSnippet 레포 Tests/FolderTest/FolderTestRunner.swift (@main) 의
//  cliApp XCTest 이식. 33-case 매트릭스 실행 골격을 제공한다.
//
//  본 이슈(Issue123)의 완료 조건은 "빌드 통과 + setUp/tearDown + sanity test 동작" 까지이며,
//  실제 33-case 회귀 실행 + result_latest.md 비교·매트릭스 동기화는 Issue124 범위.
//

import XCTest
import Cocoa

@testable import fSnippetCli

/// 메인 레포 FolderTestRunner.swift 의 케이스 표현 구조 (XCTest 호환 형태로 재정의).
fileprivate struct FolderTestCase {
  let id: String
  let folder: String
  let prefix: String
  let keys: [String]
  let suffix: String
}

final class FolderTestRunnerTests: XCTestCase {

  // MARK: - Properties

  private var utils: FolderTestUtils!
  private var sandbox: URL!
  private var originalRoot: URL!

  // MARK: - Setup / Teardown

  override func setUpWithError() throws {
    try super.setUpWithError()

    // 1. Sandbox 디렉터리 생성
    utils = FolderTestUtils()
    sandbox = try utils.setupSandbox()

    // 2. SnippetRepository.shared 의 rootFolderURL 을 sandbox 로 교체.
    //    Issue123 의 swapRootForTests (#if DEBUG) 가 production root 보존을 위한 원복 책임을 호출 측에 부여.
    originalRoot = SnippetRepository.shared.rootFolderURL
    SnippetRepository.shared.swapRootForTests(sandbox)
  }

  override func tearDownWithError() throws {
    // Repository 원복 후 sandbox 정리.
    if let original = originalRoot {
      SnippetRepository.shared.swapRootForTests(original)
    }
    utils?.tearDownSandbox()
    utils = nil
    sandbox = nil
    originalRoot = nil

    try super.tearDownWithError()
  }

  // MARK: - Tests

  /// Sandbox 환경이 정상적으로 격리되는지 확인하는 sanity test.
  /// Issue123 의 완료 조건 (빌드 통과 + 인프라 동작) 검증용.
  func testSandboxIsolation() {
    XCTAssertNotNil(sandbox, "Sandbox URL must be created in setUp")
    XCTAssertEqual(
      SnippetRepository.shared.rootFolderURL.standardizedFileURL.path,
      sandbox.standardizedFileURL.path,
      "SnippetRepository.shared.rootFolderURL should be swapped to sandbox"
    )
    XCTAssertTrue(
      SnippetRepository.shared.snippetMap.isEmpty,
      "snippetMap should be empty after swapRootForTests"
    )
  }

  /// _rule.yml 로드 + 단일 case sandbox 구성이 정상 동작하는지 확인.
  /// Issue124 본격 매트릭스 실행 전 단일 케이스 smoke test.
  func testSingleCaseSmokeTest() throws {
    // 1. sandbox 에 _rule.yml + 단일 폴더 구성
    let ruleYAML = """
      collections:
        - name: _case_smoke
          prefix: '@'
          suffix: '@'
      """
    try utils.createRuleFile(content: ruleYAML)
    try utils.createFile(path: "_case_smoke/smoke.txt", content: "Smoke Content")

    // 2. RuleManager 로 sandbox _rule.yml 로드
    let ruleLoaded = RuleManager.shared.loadRuleFile(at: sandbox.path)
    XCTAssertTrue(ruleLoaded, "RuleManager should load sandbox _rule.yml")

    // 3. snippet repository reload
    SnippetRepository.shared.loadAllSnippets(reason: "Test", force: true)

    // 4. 폴더 인식 확인 (Issue124 에서 abbreviation 매칭까지 확장)
    let folders = SnippetRepository.shared.getSnippetFolders()
    XCTAssertFalse(folders.isEmpty, "Sandbox folders should be discovered after loadAllSnippets")
  }

  // MARK: - Issue124/Issue134 — 35-case 매트릭스 실행

  /// testTable_org.md 파싱 → _rule.yml 생성 → 35-case 매트릭스 실행 → result_<timestamp>.md 출력.
  /// 각 case별 sandbox 내 `_case{N}/test.txt` 생성 후 SnippetRepository.loadAllSnippets 으로
  /// 기대 abbreviation 이 snippetMap 에 등록되는지 검증.
  func testAllFolderCases() throws {
    let cases = try Self.parseTestTable()
    XCTAssertEqual(cases.count, 38, "testTable_org.md 에서 38-case 파싱 기대 (Issue155 회귀 case 36-38)")

    // 1. _rule.yml 생성
    let ruleYAML = Self.buildRuleYAML(from: cases)
    try utils.createRuleFile(content: ruleYAML)

    // 2. 각 case 폴더 + test.txt 생성
    for c in cases {
      try utils.createFile(path: "\(c.folder)/test.txt", content: "Snippet for \(c.id)")
    }

    // 3. RuleManager 로드
    XCTAssertTrue(
      RuleManager.shared.loadRuleFile(at: sandbox.path),
      "_rule.yml 로드 실패"
    )

    // 4. SnippetRepository 강제 리빌드
    SnippetRepository.shared.loadAllSnippets(reason: "Issue124-Matrix", force: true)
    let snippetMap = SnippetRepository.shared.snippetMap

    // 5. 각 case 의 expected abbreviation 검증
    var results: [(id: String, expected: String, actual: String?, ok: Bool)] = []
    for c in cases {
      let entries = snippetMap.filter { (_, paths) in
        paths.contains { $0.contains("/\(c.folder)/") }
      }
      let actualAbbr = entries.first?.key
      let ok = actualAbbr == c.expected
      results.append((c.id, c.expected, actualAbbr, ok))
    }

    // 6. 결과 리포트 작성
    let report = Self.buildReport(results: results)
    Self.writeReports(report)

    // 7. 전 항목 통과 단언
    let failures = results.filter { !$0.ok }
    XCTAssertTrue(
      failures.isEmpty,
      "FolderTest 35-case 회귀: \(failures.count)건 실패. 상세는 result_latest.md 참조"
    )
  }

  // MARK: - Issue155 — Runtime Trigger Collision Tests

  /// Issue155: cleanBuffer 가 다른 longer abbreviation 의 prefix 일 때 짧은 매칭 reject 검증.
  ///
  /// 시나리오:
  ///   - `test{right_command}` (case 13) 와 `,test{keypad_comma}` (case 37) 가 모두 등록된 환경
  ///   - 사용자가 `test` + right_command → exact match 채택, expansion 정상 (정확 매칭 우선)
  ///   - 사용자가 `,test` + right_command → exact match 없음, cleanBuffer `,test` 가 case 37 prefix → reject
  ///   - 사용자가 `,,test` + right_command → cleanBuffer `,,test` 가 case 38 prefix → reject
  func testIssue155RuntimeCollision() throws {
    let cases = try Self.parseTestTable()
    let ruleYAML = Self.buildRuleYAML(from: cases)
    try utils.createRuleFile(content: ruleYAML)
    for c in cases {
      try utils.createFile(path: "\(c.folder)/test.txt", content: "Snippet for \(c.id)")
    }
    XCTAssertTrue(RuleManager.shared.loadRuleFile(at: sandbox.path), "_rule.yml 로드 실패")
    SnippetRepository.shared.loadAllSnippets(reason: "Issue155-Collision", force: true)

    // right_command (Code 54) trigger KeyEventInfo 시뮬레이션
    let rightCmdInfo = KeyEventInfo(
      type: .regular,
      character: "{right_command}",
      keyCode: 54,
      modifiers: []
    )

    // Sanity 1: exact match (test + right_command) → expansion 채택
    let exactAction = TriggerProcessor.shared.checkForSuffixMatches(
      buffer: "test{right_command}", keyInfo: rightCmdInfo
    )
    XCTAssertEqual(exactAction, .consumed,
                   "exact match 'test{right_command}' 는 .consumed 기대")

    // Issue155 fix 검증 2: cleanBuffer ',test' → ',test{keypad_comma}' (case 37) prefix → reject
    let collide37 = TriggerProcessor.shared.checkForSuffixMatches(
      buffer: ",test{right_command}", keyInfo: rightCmdInfo
    )
    XCTAssertEqual(collide37, .none,
                   "',test{right_command}' 는 cleanBuffer ',test' 가 case 37 prefix 이므로 reject (.none) 기대")

    // Issue155 fix 검증 3: cleanBuffer ',,test' → ',,test{keypad_comma}' (case 38) prefix → reject
    let collide38 = TriggerProcessor.shared.checkForSuffixMatches(
      buffer: ",,test{right_command}", keyInfo: rightCmdInfo
    )
    XCTAssertEqual(collide38, .none,
                   "',,test{right_command}' 는 cleanBuffer ',,test' 가 case 38 prefix 이므로 reject (.none) 기대")

    // Issue155 fix 검증 4 (재재오픈 2026-05-28): modifier press + release 시 token 중복.
    // searchBuffer 가 ',ant{right_command}{right_command}' 가 되어도 trailing trigger token 모두 제거하여
    // cleanBuffer = ',ant' 까지 도달 → case 37 prefix 매칭 → reject 보장.
    let doubleTok = TriggerProcessor.shared.checkForSuffixMatches(
      buffer: ",test{right_command}{right_command}", keyInfo: rightCmdInfo
    )
    XCTAssertEqual(doubleTok, .none,
                   "modifier 중복 token 케이스 ',test{right_command}{right_command}' 도 reject 기대 (trailing token loop 제거)")
  }

  // MARK: - testTable_org.md 파싱

  private struct MatrixCase {
    let id: String
    let folder: String
    let prefix: String
    let keys: [String]
    let suffix: String
    let expected: String
  }

  private static func parseTestTable() throws -> [MatrixCase] {
    let testFile = URL(fileURLWithPath: #filePath)
    let mdURL = testFile.deletingLastPathComponent().appendingPathComponent("testTable_org.md")
    let text = try String(contentsOf: mdURL, encoding: .utf8)

    var cases: [MatrixCase] = []
    let lines = text.components(separatedBy: .newlines)
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      guard trimmed.hasPrefix("|") else { continue }
      // 헤더/구분선 스킵 (구분선은 `| --- | --- |...` 형태)
      if trimmed.hasPrefix("| ---") || trimmed.contains("Folder") { continue }
      let cells = trimmed.split(separator: "|", omittingEmptySubsequences: false).map {
        $0.trimmingCharacters(in: .whitespaces)
      }
      // 양끝 빈 셀 포함 8개 (0: 빈, 1: id, 2: folder, ..., 6: abbreviation, 7: 빈)
      guard cells.count >= 7,
            Int(cells[1]) != nil else { continue }
      let id = cells[1]
      let folder = cells[2]
      let prefix = cells[3]
      let keys = cells[4].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
      let suffix = cells[5]
      let expected = cells[6]
      cases.append(MatrixCase(
        id: id, folder: folder, prefix: prefix, keys: keys, suffix: suffix, expected: expected
      ))
    }
    return cases
  }

  // MARK: - _rule.yml 빌더

  private static func buildRuleYAML(from cases: [MatrixCase]) -> String {
    var lines: [String] = ["collections:"]
    for c in cases {
      lines.append("  - name: \"\(c.folder)\"")
      if !c.prefix.isEmpty {
        lines.append("    prefix: \"\(c.prefix)\"")
      }
      if !c.suffix.isEmpty {
        lines.append("    suffix: \"\(c.suffix)\"")
      }
    }
    return lines.joined(separator: "\n") + "\n"
  }

  // MARK: - 리포트

  private static func buildReport(
    results: [(id: String, expected: String, actual: String?, ok: Bool)]
  ) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let now = formatter.string(from: Date())
    let passed = results.filter { $0.ok }.count
    let total = results.count

    var out: [String] = []
    out.append("---")
    out.append("title: Folder Test Result (Issue124)")
    out.append("date: \(now)")
    out.append("passed: \(passed)/\(total)")
    out.append("---")
    out.append("")
    out.append("# 결과 요약")
    out.append("")
    out.append("* 통과: \(passed)/\(total)")
    out.append("* 실행 시각: \(now)")
    out.append("")
    out.append("# 케이스별 상세")
    out.append("")
    out.append("| id | expected | actual | status |")
    out.append("| -- | -------- | ------ | ------ |")
    for r in results {
      let mark = r.ok ? "✅" : "❌"
      let actual = r.actual ?? "(none)"
      out.append("| \(r.id) | `\(r.expected)` | `\(actual)` | \(mark) |")
    }
    return out.joined(separator: "\n") + "\n"
  }

  private static func writeReports(_ content: String) {
    let testFile = URL(fileURLWithPath: #filePath)
    let resultsDir = testFile.deletingLastPathComponent().appendingPathComponent("Results")
    try? FileManager.default.createDirectory(
      at: resultsDir, withIntermediateDirectories: true
    )

    let latest = resultsDir.appendingPathComponent("result_latest.md")
    try? content.write(to: latest, atomically: true, encoding: .utf8)

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    let ts = formatter.string(from: Date())
    let dated = resultsDir.appendingPathComponent("result_\(ts).md")
    try? content.write(to: dated, atomically: true, encoding: .utf8)
  }
}
