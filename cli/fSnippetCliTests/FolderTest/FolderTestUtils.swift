//
//  FolderTestUtils.swift
//  fSnippetCliTests
//
//  Issue123: FolderTest 인프라 복구 — Sandbox 헬퍼 (메인 레포 Tests/UnitTest/TestUtils.swift 이식)
//

import Foundation

/// FolderTest 전용 Sandbox 헬퍼.
/// 메인 fSnippet 레포의 TestUtils 패턴을 cliApp Tests 환경에 맞춰 XCTestCase 인스턴스에서 사용 가능하도록 단순화.
final class FolderTestUtils {

  private let fileManager = FileManager.default

  /// 현재 생성된 Sandbox URL (setupSandbox 호출 후 유효).
  private(set) var sandboxURL: URL?

  init() {}

  /// 임시 디렉터리에 고유한 Sandbox 폴더를 생성하여 URL을 반환.
  @discardableResult
  func setupSandbox() throws -> URL {
    let tempDir = fileManager.temporaryDirectory
    let sandbox = tempDir.appendingPathComponent("fSnippetCliTests-Folder-\(UUID().uuidString)")
    try fileManager.createDirectory(at: sandbox, withIntermediateDirectories: true, attributes: nil)
    self.sandboxURL = sandbox
    return sandbox
  }

  /// Sandbox 폴더와 내부 파일 일괄 제거.
  func tearDownSandbox() {
    guard let sandbox = sandboxURL else { return }
    try? fileManager.removeItem(at: sandbox)
    self.sandboxURL = nil
  }

  /// Sandbox 내 상대 경로에 파일 생성. 부모 디렉터리는 자동 생성.
  @discardableResult
  func createFile(path: String, content: String) throws -> URL {
    guard let sandbox = sandboxURL else {
      throw NSError(
        domain: "FolderTestUtils", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Sandbox not initialized"])
    }
    let fileURL = sandbox.appendingPathComponent(path)
    let folderURL = fileURL.deletingLastPathComponent()
    try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
    try content.write(to: fileURL, atomically: true, encoding: .utf8)
    return fileURL
  }

  /// Sandbox 루트에 _rule.yml 생성.
  @discardableResult
  func createRuleFile(content: String) throws -> URL {
    return try createFile(path: "_rule.yml", content: content)
  }
}
