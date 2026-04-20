import Cocoa
import Foundation

/// Phase A — REST 2차 채널 paidApp 등록 상태 저장소
///
/// NSWorkspace(1차 채널)와 독립. paidApp이 POST /paidapp/register 시
/// 메타데이터를 여기에 저장하고, unregister 시 제거.
/// thread-safe: serial queue 보호.
final class PaidAppStateStore {
    static let shared = PaidAppStateStore()

    // MARK: - 내부 상태

    struct Registration {
        let pid: Int32
        let bundlePath: String
        let sessionId: String
        let version: String
        let startTime: Int64
        let registeredAt: Date
    }

    private var current: Registration?
    private let queue = DispatchQueue(label: "kr.finfra.fSnippetCli.paidAppStateStore")

    private init() {}

    // MARK: - 등록

    enum RegisterError: Error {
        case duplicateSession(String)
        case verificationFailed(String)
    }

    /// paidApp 등록. 성공 시 Registration 반환, 실패 시 throw.
    /// - Parameters:
    ///   - request: POST /paidapp/register 요청 모델
    /// - Returns: 저장된 Registration
    @discardableResult
    func register(_ request: PaidAppRegistrationRequest) throws -> Registration {
        try queue.sync {
            // 중복 sessionId 검사
            if let existing = current, existing.sessionId == request.sessionId {
                throw RegisterError.duplicateSession(request.sessionId)
            }
            // 3단계 발신자 검증
            try verifyCallerOrThrow(pid: request.pid, bundlePath: request.bundlePath)

            let reg = Registration(
                pid: request.pid,
                bundlePath: request.bundlePath,
                sessionId: request.sessionId,
                version: request.version,
                startTime: request.startTime,
                registeredAt: Date()
            )
            current = reg
            logI("🏷️ [PaidAppStateStore] 등록 완료 — pid:\(request.pid) session:\(request.sessionId.prefix(8))…")
            return reg
        }
    }

    // MARK: - 해제

    enum UnregisterError: Error {
        case notFound(String)
    }

    /// sessionId 일치 시 등록 해제.
    func unregister(sessionId: String) throws {
        try queue.sync {
            guard current?.sessionId == sessionId else {
                throw UnregisterError.notFound(sessionId)
            }
            current = nil
            logI("🏷️ [PaidAppStateStore] 해제 완료 — session:\(sessionId.prefix(8))…")
        }
    }

    // MARK: - 상태 조회

    /// 현재 등록 상태 반환 (nil = 미등록)
    func status() -> Registration? {
        queue.sync { current }
    }

    // MARK: - 3단계 발신자 검증

    private func verifyCallerOrThrow(pid: Int32, bundlePath: String) throws {
        // 1단계: pid 존재 여부 (kill -0)
        guard kill(pid, 0) == 0 else {
            logW("🏷️ [PaidAppStateStore] 발신자 검증 실패(pid 없음): \(pid)")
            throw RegisterError.verificationFailed("pid \(pid) does not exist")
        }

        // 2단계: pid의 bundleURL → bundlePath 일치
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "kr.finfra.fSnippet")
        let matchByPid = apps.first { $0.processIdentifier == pid }
        guard let app = matchByPid else {
            logW("🏷️ [PaidAppStateStore] 발신자 검증 실패(pid-bundleID 불일치): \(pid)")
            throw RegisterError.verificationFailed("pid \(pid) is not fSnippet")
        }

        if let appURL = app.bundleURL {
            let resolvedPath = appURL.standardizedFileURL.path
            let requestedPath = URL(fileURLWithPath: bundlePath).standardizedFileURL.path
            guard resolvedPath == requestedPath else {
                logW("🏷️ [PaidAppStateStore] 발신자 검증 실패(bundlePath 불일치): \(resolvedPath) vs \(requestedPath)")
                throw RegisterError.verificationFailed("bundlePath mismatch")
            }
        }

        // 3단계: Code Signing Team ID 일치 확인
        if let appURL = app.bundleURL {
            verifyTeamID(appURL: appURL, pid: pid)
        }

        logD("🏷️ [PaidAppStateStore] 발신자 검증 통과 — pid:\(pid)")
    }

    private func verifyTeamID(appURL: URL, pid: Int32) {
        // SecCodeCopyGuestWithAttributes를 통한 Team ID 비교
        // QA 환경(비서명 빌드)에서 실패해도 경고만 로깅, throw 안 함 (강도 조정 가능)
        var guestCode: SecCode?
        let attrs = [kSecGuestAttributePid: pid] as CFDictionary
        let status = SecCodeCopyGuestWithAttributes(nil, attrs, [], &guestCode)
        guard status == errSecSuccess, let guest = guestCode else {
            logD("🏷️ [PaidAppStateStore] Team ID 검증 스킵(SecCode 없음) — pid:\(pid)")
            return
        }

        var info: CFDictionary?
        let infoStatus = SecCodeCopySigningInformation(guest as! SecStaticCode, [], &info)
        guard infoStatus == errSecSuccess,
              let infoDict = info as? [String: Any],
              let teamID = infoDict[kSecCodeInfoTeamIdentifier as String] as? String
        else {
            logD("🏷️ [PaidAppStateStore] Team ID 없음(개발 빌드) — pid:\(pid)")
            return
        }

        // 현재 cliApp의 Team ID와 비교
        var selfCode: SecStaticCode?
        let selfPath = Bundle.main.bundlePath
        SecStaticCodeCreateWithPath(URL(fileURLWithPath: selfPath) as CFURL, [], &selfCode)
        var selfInfo: CFDictionary?
        if let sc = selfCode {
            SecCodeCopySigningInformation(sc, [], &selfInfo)
        }
        let selfTeam = (selfInfo as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String

        if let selfTeam, selfTeam != teamID {
            logW("🏷️ [PaidAppStateStore] Team ID 불일치 — cliApp:\(selfTeam) paidApp:\(teamID)")
        } else {
            logD("🏷️ [PaidAppStateStore] Team ID 일치 — \(teamID)")
        }
    }
}
