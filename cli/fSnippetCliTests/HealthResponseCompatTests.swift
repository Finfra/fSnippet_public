import XCTest
@testable import fSnippetCli

/// GET / health response compatibility (Issue244 ①) and build identity (Issue253)
///
/// - Older paidApp builds decode `uptimeSeconds` (camelCase, required) while the spec says
///   `uptime_seconds`. Emitting only one key breaks one side, so both must be present.
/// - The response must carry `build`, `build_time`, `build_uuid` so a caller can tell
///   which binary is actually running.
final class HealthResponseCompatTests: XCTestCase {

    private func sample() -> HealthResponse {
        HealthResponse(
            status: "ok", app: "fSnippet", version: "1.1.1", build: "7",
            buildTime: "2026-10-09T01:02:03Z", buildUUID: "11111111-2222-3333-4444-555555555555",
            port: 3015, uptime: "00:01:40", uptimeSeconds: 100,
            isRunning: true, isMenuBarVisible: false, snippetCount: 3, clipboardCount: 1)
    }

    private func encodedObject(_ r: HealthResponse) throws -> [String: Any] {
        let data = try JSONEncoder().encode(r)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testEncodesBothUptimeKeys() throws {
        let obj = try encodedObject(sample())
        XCTAssertEqual(obj["uptime_seconds"] as? Int, 100, "spec key (openapi_v2)")
        XCTAssertEqual(obj["uptimeSeconds"] as? Int, 100, "legacy key read by paidApp <= 1.1.1")
    }

    /// Mirror of the legacy paidApp model: uptimeSeconds is a required Int.
    private struct LegacyPaidAppHealth: Decodable {
        let status: String
        let version: String
        let uptimeSeconds: Int
    }

    func testLegacyPaidAppModelDecodes() throws {
        let data = try JSONEncoder().encode(sample())
        let legacy = try JSONDecoder().decode(LegacyPaidAppHealth.self, from: data)
        XCTAssertEqual(legacy.uptimeSeconds, 100)
    }

    func testDecodesEitherUptimeKey() throws {
        let snake = #"{"status":"ok","app":"a","version":"1","port":1,"uptime":"x","uptime_seconds":5,"isRunning":true,"isMenuBarVisible":true,"snippet_count":0,"clipboard_count":0}"#
        let camel = #"{"status":"ok","app":"a","version":"1","port":1,"uptime":"x","uptimeSeconds":6,"isRunning":true,"isMenuBarVisible":true,"snippet_count":0,"clipboard_count":0}"#
        XCTAssertEqual(try JSONDecoder().decode(HealthResponse.self, from: Data(snake.utf8)).uptimeSeconds, 5)
        XCTAssertEqual(try JSONDecoder().decode(HealthResponse.self, from: Data(camel.utf8)).uptimeSeconds, 6)
    }

    func testEncodesBuildIdentity() throws {
        let obj = try encodedObject(sample())
        XCTAssertEqual(obj["build"] as? String, "7")
        XCTAssertEqual(obj["build_time"] as? String, "2026-10-09T01:02:03Z")
        XCTAssertEqual(obj["build_uuid"] as? String, "11111111-2222-3333-4444-555555555555")
    }

    func testBuildIdentityOfRunningBinary() throws {
        let uuid = try XCTUnwrap(BuildIdentity.executableUUID(), "LC_UUID of the main executable")
        XCTAssertNotNil(UUID(uuidString: uuid), "UUID format: \(uuid)")
        let time = try XCTUnwrap(BuildIdentity.executableModificationTime(), "mtime of the main executable")
        XCTAssertNotNil(ISO8601DateFormatter().date(from: time), "ISO8601: \(time)")
        XCTAssertTrue(time.hasSuffix("Z"), "UTC: \(time)")
    }
}
