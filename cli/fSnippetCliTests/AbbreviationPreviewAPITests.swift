//
//  AbbreviationPreviewAPITests.swift
//  fSnippetCliTests
//
//  Issue259: POST /api/v2/snippets/abbreviation-preview must return the
//  engine-calculated abbreviation and duplicate flag without side effects.
//

import XCTest
@testable import fSnippetCli

final class AbbreviationPreviewAPITests: XCTestCase {

    private let router = APIRouter.shared
    private let server = APIServer.shared

    private func post(_ body: [String: Any]) -> APIServer.HTTPResponse {
        let data = try! JSONSerialization.data(withJSONObject: body)
        let req = APIServer.HTTPRequest(
            method: "POST",
            path: "/api/v2/snippets/abbreviation-preview",
            query: [:],
            headers: ["Content-Type": "application/json"],
            body: data,
            remoteIP: "127.0.0.1")
        return router.route(request: req, server: server)
    }

    private func decode(_ resp: APIServer.HTTPResponse) -> [String: Any]? {
        guard let body = resp.rawBodyData ?? resp.body.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        else { return nil }
        return obj["data"] as? [String: Any]
    }

    /// Abbreviation matches the engine for a plain (mock) folder.
    func testPreview_matchesEngineCalculation() {
        let resp = post(["folder": "Markdownzq", "keyword": "p", "name": "preview"])
        XCTAssertEqual(resp.statusCode, 200)
        let data = decode(resp)
        let expected = SnippetFileManager.shared.calculateAbbreviation(
            folder: "Markdownzq", keyword: "p", name: "preview")
        XCTAssertEqual(data?["abbreviation"] as? String, expected)
        XCTAssertEqual(data?["isDuplicate"] as? Bool,
                       SnippetFileManager.shared.checkDuplicate(abbreviation: expected))
    }

    /// Abbreviation matches the engine for a rule-based special folder when one exists.
    func testPreview_ruleFolderMatchesEngine() throws {
        guard let ruleFolder = RuleManager.shared.getAllRulesDict().keys.first(where: { $0.hasPrefix("_") }) else {
            throw XCTSkip("no special folder rule loaded in test environment (verify via live REST)")
        }
        let resp = post(["folder": ruleFolder, "keyword": "zq", "name": "n"])
        XCTAssertEqual(resp.statusCode, 200)
        let expected = SnippetFileManager.shared.calculateAbbreviation(
            folder: ruleFolder, keyword: "zq", name: "n")
        XCTAssertEqual(decode(resp)?["abbreviation"] as? String, expected)
    }

    /// An unused abbreviation is not a duplicate.
    func testPreview_unusedAbbreviationNotDuplicate() {
        let resp = post(["folder": "Markdownzq", "keyword": "qzqzqz", "name": "none"])
        XCTAssertEqual(decode(resp)?["isDuplicate"] as? Bool, false)
    }

    /// An existing abbreviation is a duplicate, unless currentSnippetPath is its only owner.
    func testPreview_existingAbbreviationDuplicateAndSelfExcluded() throws {
        guard let (abbr, paths) = SnippetFileManager.shared.snippetMap.first(where: { $0.value.count == 1 }) else {
            throw XCTSkip("no indexed snippet in test environment (verify via live REST)")
        }
        let folder = URL(fileURLWithPath: paths[0]).deletingLastPathComponent().lastPathComponent
        let file = URL(fileURLWithPath: paths[0]).deletingPathExtension().lastPathComponent
        let parts = file.components(separatedBy: "===")
        let keyword = parts.count > 1 ? parts[0] : ""
        let name = parts.count > 1 ? parts[1] : file
        let calc = SnippetFileManager.shared.calculateAbbreviation(
            folder: folder, keyword: keyword, name: name)
        try XCTSkipIf(calc != abbr, "calculated abbreviation differs from indexed key")

        let dup = post(["folder": folder, "keyword": keyword, "name": name])
        XCTAssertEqual(decode(dup)?["isDuplicate"] as? Bool, true)
        let own = post(["folder": folder, "keyword": keyword, "name": name,
                        "currentSnippetPath": paths[0]])
        XCTAssertEqual(decode(own)?["isDuplicate"] as? Bool, false)
    }

    func testPreview_invalidBody_returns400() {
        let req = APIServer.HTTPRequest(
            method: "POST", path: "/api/v2/snippets/abbreviation-preview",
            query: [:], headers: [:], body: nil, remoteIP: "127.0.0.1")
        XCTAssertEqual(router.route(request: req, server: server).statusCode, 400)
    }
}
