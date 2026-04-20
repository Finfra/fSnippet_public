import XCTest
@testable import fSnippetCli

/// Phase A — paidApp 라이프사이클 REST 단위 테스트 (Issue826)
///
/// 대상: APIModels 라운드트립, PaidAppStateStore 상태 전환, NSWorkspace 직교
final class PaidAppPhaseATests: XCTestCase {

    override func tearDown() {
        // 공유 스토어 초기화 (각 테스트 후 state 정리)
        try? PaidAppStateStore.shared.unregister(sessionId: PaidAppStateStore.shared.status()?.sessionId ?? "")
        super.tearDown()
    }

    // MARK: - A-2: APIModels JSON 라운드트립 (5건)

    func testAPIModels_registrationRequestRoundtrip() throws {
        let original = PaidAppRegistrationRequest(
            pid: 12345,
            bundlePath: "/Applications/fSnippet.app",
            sessionId: "test-uuid-1234",
            version: "1.2.3",
            startTime: 1_700_000_000_000
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PaidAppRegistrationRequest.self, from: data)
        XCTAssertEqual(decoded.pid, original.pid)
        XCTAssertEqual(decoded.bundlePath, original.bundlePath)
        XCTAssertEqual(decoded.sessionId, original.sessionId)
        XCTAssertEqual(decoded.version, original.version)
        XCTAssertEqual(decoded.startTime, original.startTime)
    }

    func testAPIModels_registrationResponseRoundtrip() throws {
        let original = PaidAppRegistrationResponse(
            ok: true,
            sessionId: "resp-uuid-5678",
            cliVersion: "0.9.0",
            minPaidAppVersion: "1.0.0",
            compatible: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PaidAppRegistrationResponse.self, from: data)
        XCTAssertTrue(decoded.ok)
        XCTAssertEqual(decoded.sessionId, original.sessionId)
        XCTAssertEqual(decoded.minPaidAppVersion, "1.0.0")
        XCTAssertTrue(decoded.compatible)
    }

    func testAPIModels_unregistrationRequestRoundtrip() throws {
        let original = PaidAppUnregistrationRequest(sessionId: "unregister-session-abc")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PaidAppUnregistrationRequest.self, from: data)
        XCTAssertEqual(decoded.sessionId, original.sessionId)
    }

    func testAPIModels_statusResponseRunning() throws {
        let statusData = PaidAppStatusData(
            pid: 99,
            bundlePath: "/Applications/fSnippet.app",
            sessionId: "status-uuid-abc",
            version: "2.0.0",
            startTime: 1_700_000_000_000,
            registeredAt: "2026-04-20T00:00:00.000Z"
        )
        let original = PaidAppStatusResponse(registered: true, data: statusData)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PaidAppStatusResponse.self, from: data)
        XCTAssertTrue(decoded.registered)
        XCTAssertEqual(decoded.data?.pid, 99)
        XCTAssertEqual(decoded.data?.sessionId, "status-uuid-abc")
    }

    func testAPIModels_statusResponseNotRunning() throws {
        let original = PaidAppStatusResponse(registered: false, data: nil)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PaidAppStatusResponse.self, from: data)
        XCTAssertFalse(decoded.registered)
        XCTAssertNil(decoded.data)
    }

    // MARK: - A-3: PaidAppStateStore 상태 전환 (4건)

    func testPaidAppStateStore_normalRegisterStatusUnregisterCycle() throws {
        let store = PaidAppStateStore.shared
        let sid = UUID().uuidString
        let reg = store._registerForTesting(pid: 1001, bundlePath: "/test.app", sessionId: sid, version: "1.0.0", startTime: 1_700_000_000_000)
        XCTAssertEqual(reg.sessionId, sid)
        XCTAssertNotNil(store.status(), "등록 후 status는 non-nil")
        XCTAssertEqual(store.status()?.sessionId, sid)
        try store.unregister(sessionId: sid)
        XCTAssertNil(store.status(), "해제 후 status는 nil")
    }

    func testPaidAppStateStore_unregisterWithWrongSessionFails() {
        let store = PaidAppStateStore.shared
        XCTAssertThrowsError(try store.unregister(sessionId: "nonexistent-fake-session-xyz")) { error in
            guard case PaidAppStateStore.UnregisterError.notFound = error else {
                XCTFail("예상 에러 타입 아님: \(error)"); return
            }
        }
    }

    func testPaidAppStateStore_duplicateRegisterCausesStaleLog() throws {
        let store = PaidAppStateStore.shared
        let sid1 = UUID().uuidString
        let sid2 = UUID().uuidString
        _ = store._registerForTesting(pid: 2001, bundlePath: "/test.app", sessionId: sid1, version: "1.0.0", startTime: 1_700_000_000_000)
        // 동일 pid 중복 등록 → stale 후 새 세션 발급
        _ = store._registerForTesting(pid: 2001, bundlePath: "/test.app", sessionId: sid2, version: "1.0.0", startTime: 1_700_000_001_000)
        XCTAssertEqual(store.status()?.sessionId, sid2, "중복 등록 시 최신 sessionId가 유지돼야 함")
        try store.unregister(sessionId: sid2)
    }

    func testPaidAppStateStore_startTimeMsDistinguishesRapidRestarts() throws {
        let store = PaidAppStateStore.shared
        let sid1 = UUID().uuidString
        let sid2 = UUID().uuidString
        let t1 = Int64(Date().timeIntervalSince1970 * 1000)
        let t2 = t1 + 500  // 500ms 차이

        _ = store._registerForTesting(pid: 3001, bundlePath: "/test.app", sessionId: sid1, version: "1.0.0", startTime: t1)
        _ = store._registerForTesting(pid: 3002, bundlePath: "/test.app", sessionId: sid2, version: "1.0.0", startTime: t2)
        XCTAssertEqual(store.status()?.startTime, t2, "1초 내 재기동 시 startTime ms로 구분돼야 함")
        try store.unregister(sessionId: sid2)
    }

    // MARK: - A-11: NSWorkspace × REST 직교 (1건)

    func testMarkStaleFromWorkspace_clearsCorrectPid() throws {
        let store = PaidAppStateStore.shared
        let sid = UUID().uuidString
        _ = store._registerForTesting(pid: 4001, bundlePath: "/test.app", sessionId: sid, version: "1.0.0", startTime: 1_700_000_000_000)
        XCTAssertNotNil(store.status())

        store.markStaleFromWorkspace(pid: 4001)

        // markStaleFromWorkspace는 async이므로 잠시 대기
        let expectation = XCTestExpectation(description: "stale 처리 완료")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(store.status(), "NSWorkspace terminate 후 Store가 nil이어야 함")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
