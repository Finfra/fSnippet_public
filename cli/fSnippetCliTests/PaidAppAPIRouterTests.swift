import XCTest
@testable import fSnippetCli

/// Phase A — APIRouter paidApp 엔드포인트 단위 테스트 (Issue826)
///
/// 대상: POST /paidapp/register 발신자 검증(3단계), GET /paidapp/status 라우팅
final class PaidAppAPIRouterTests: XCTestCase {

    private let router = APIRouter.shared
    private let server = APIServer.shared

    override func tearDown() {
        // 공유 스토어 초기화
        try? PaidAppStateStore.shared.unregister(sessionId: PaidAppStateStore.shared.status()?.sessionId ?? "")
        super.tearDown()
    }

    // MARK: - 헬퍼

    private func makeRegisterRequest(pid: Int32, bundlePath: String = "/Applications/fSnippet.app", sessionId: String? = nil) -> APIServer.HTTPRequest {
        let sid = sessionId ?? UUID().uuidString
        let body = PaidAppRegistrationRequest(
            pid: pid,
            bundlePath: bundlePath,
            sessionId: sid,
            version: "1.0.0",
            startTime: Int64(Date().timeIntervalSince1970 * 1000)
        )
        let data = try! JSONEncoder().encode(body)
        return APIServer.HTTPRequest(
            method: "POST",
            path: "/api/v2/paidapp/register",
            query: [:],
            headers: ["Content-Type": "application/json"],
            body: data,
            remoteIP: "127.0.0.1"
        )
    }

    private func makeUnregisterRequest(sessionId: String) -> APIServer.HTTPRequest {
        let body = PaidAppUnregistrationRequest(sessionId: sessionId)
        let data = try! JSONEncoder().encode(body)
        return APIServer.HTTPRequest(
            method: "POST",
            path: "/api/v2/paidapp/unregister",
            query: [:],
            headers: ["Content-Type": "application/json"],
            body: data,
            remoteIP: "127.0.0.1"
        )
    }

    private func makeStatusRequest() -> APIServer.HTTPRequest {
        APIServer.HTTPRequest(
            method: "GET",
            path: "/api/v2/paidapp/status",
            query: [:],
            headers: [:],
            body: nil,
            remoteIP: "127.0.0.1"
        )
    }

    // MARK: - A-4: 발신자 검증 실패 → 403

    /// 1단계: 존재하지 않는 pid → kill(pid,0) 실패 → 403
    func testRegister_nonExistentPid_returns403() {
        let req = makeRegisterRequest(pid: 999_999_999)
        let resp = router.route(request: req, server: server)
        XCTAssertEqual(resp.statusCode, 403, "존재하지 않는 pid는 403이어야 함")
    }

    /// 2단계: 존재하는 pid지만 fSnippet 아님 (테스트 프로세스 자신) → bundleID 불일치 → 403
    func testRegister_ownProcessPidNotFSnippet_returns403() {
        let selfPid = Int32(ProcessInfo.processInfo.processIdentifier)
        let req = makeRegisterRequest(pid: selfPid)
        let resp = router.route(request: req, server: server)
        // NSRunningApplication.runningApplications(withBundleIdentifier: "kr.finfra.fSnippet") 에
        // 테스트 프로세스가 없으므로 verificationFailed → 403
        XCTAssertEqual(resp.statusCode, 403, "fSnippet 아닌 pid는 403이어야 함")
    }

    /// 중복 sessionId: _registerForTesting으로 sid 선점 후 동일 sid 재등록 → 409
    /// (중복 체크는 verifyCallerOrThrow 전에 실행되므로 단위 테스트 가능)
    func testRegister_duplicateSession_returns409() throws {
        let sid = UUID().uuidString
        _ = PaidAppStateStore.shared._registerForTesting(
            pid: 1234,
            bundlePath: "/test.app",
            sessionId: sid,
            version: "1.0.0",
            startTime: 1_700_000_000_000
        )
        let req = makeRegisterRequest(pid: 999_999_999, sessionId: sid)
        let resp = router.route(request: req, server: server)
        XCTAssertEqual(resp.statusCode, 409, "중복 sessionId 재등록은 409이어야 함")
    }

    // MARK: - A-4: status 라우팅

    /// 등록 없음 → GET /paidapp/status → registered: false
    func testStatus_notRegistered_returnsNotRunning() throws {
        let resp = router.route(request: makeStatusRequest(), server: server)
        XCTAssertEqual(resp.statusCode, 200)
        guard let body = resp.body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { XCTFail("응답 바디 파싱 실패"); return }
        XCTAssertEqual(json["registered"] as? Bool, false, "등록 없음 → registered=false")
        XCTAssertNil(json["data"] as? [String: Any] ?? nil as [String: Any]?,
                     "등록 없음 → data=null")
    }

    /// _registerForTesting 후 GET /paidapp/status → registered: true, sessionId 일치
    func testStatus_afterDirectRegister_returnsRunning() throws {
        let sid = UUID().uuidString
        _ = PaidAppStateStore.shared._registerForTesting(
            pid: 9001,
            bundlePath: "/Applications/fSnippet.app",
            sessionId: sid,
            version: "2.0.0",
            startTime: 1_700_000_000_000
        )
        let resp = router.route(request: makeStatusRequest(), server: server)
        XCTAssertEqual(resp.statusCode, 200)
        guard let body = resp.body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { XCTFail("응답 바디 파싱 실패"); return }
        XCTAssertEqual(json["registered"] as? Bool, true, "등록 후 → registered=true")
        let dataDict = json["data"] as? [String: Any]
        XCTAssertEqual(dataDict?["sessionId"] as? String, sid, "sessionId 일치해야 함")
    }

    // MARK: - unregister 라우팅

    /// unregister — 존재하지 않는 sessionId → 404
    func testUnregister_unknownSession_returns404() {
        let req = makeUnregisterRequest(sessionId: "nonexistent-\(UUID().uuidString)")
        let resp = router.route(request: req, server: server)
        XCTAssertEqual(resp.statusCode, 404, "미등록 sessionId unregister는 404이어야 함")
    }
}
