//
//  SnippetExpansionTrailingNewlineTests.swift
//  fSnippetCliTests
//
//  Issue160: File-reference placeholder {{~/path/file.txt}} must not inject the
//  referenced file's trailing newline into the expanded snippet. Value files such
//  as ~/.info/namee.txt commonly end with a single LF; that LF must be stripped so
//  the inlined value stays on the same line as the surrounding template text.
//

import XCTest
@testable import fSnippetCli

final class SnippetExpansionTrailingNewlineTests: XCTestCase {

    private var sandboxDir: URL!

    override func setUpWithError() throws {
        sandboxDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("issue160_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: sandboxDir,
                                                withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let dir = sandboxDir {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    // MARK: - Helpers

    private func writeValueFile(_ name: String, contents: String) throws -> String {
        let url = sandboxDir.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    // MARK: - Tests

    /// Single-value file ending with a trailing newline must inline without the LF.
    func testTrailingNewlineStrippedFromFileReference() throws {
        let path = try writeValueFile("namee.txt", contents: "Steve J. South\n")
        let content = "git config --global user.name \"{{\(path)}}\""

        let result = SnippetExpansionManager.shared.expand(content)

        XCTAssertEqual(result, "git config --global user.name \"Steve J. South\"",
                       "Trailing LF of the referenced file must not leak into the snippet")
        XCTAssertFalse(result.contains("South\n"),
                       "No spurious line break inside the quoted value")
    }

    /// Reproduce the exact gcfg layout: two placeholders on one line, value reused.
    func testGcfgLayoutNoSpuriousNewlines() throws {
        let namePath = try writeValueFile("namee.txt", contents: "Steve J. South\n")
        let mailPath = try writeValueFile("mail1.txt", contents: "nowage@gmail.com\n")
        let content = """
        git config --global user.name "{{\(namePath)}}({{\(namePath)}}) "
        git config --global user.email "{{\(mailPath)}}"
        """

        let result = SnippetExpansionManager.shared.expand(content)

        let expected = """
        git config --global user.name "Steve J. South(Steve J. South) "
        git config --global user.email "nowage@gmail.com"
        """
        XCTAssertEqual(result, expected)
    }

    /// Internal newlines of a multi-line value file must be preserved; only the
    /// trailing newline is stripped.
    func testInternalNewlinesPreserved() throws {
        let path = try writeValueFile("block.txt", contents: "line1\nline2\n")
        let content = "{{\(path)}}"

        let result = SnippetExpansionManager.shared.expand(content)

        XCTAssertEqual(result, "line1\nline2",
                       "Internal newline kept, single trailing newline removed")
    }

    /// Multiple trailing newlines are all stripped.
    func testMultipleTrailingNewlinesStripped() throws {
        let path = try writeValueFile("multi.txt", contents: "value\n\n\n")
        let content = "X{{\(path)}}Y"

        let result = SnippetExpansionManager.shared.expand(content)

        XCTAssertEqual(result, "XvalueY")
    }
}
