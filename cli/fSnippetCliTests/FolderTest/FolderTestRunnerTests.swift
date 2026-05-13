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

  // MARK: - Issue124 확장 지점

  /// Issue124 에서 본격 구현. 현재는 비활성 (XCTSkip).
  /// testTable_org.md 파싱 → _rule.yml 생성 → 33-case 매트릭스 실행 → result_<timestamp>.md 출력.
  func testAllFolderCases_DISABLED() throws {
    throw XCTSkip("Issue124 범위 — testTable_org.md 파싱 + 33-case 매트릭스 실행은 후속 이슈에서 구현")
  }
}
