import Foundation

/// Issue89: 박제된 hotkey 자동 정리 마이그레이션
///
/// 앱 시작 시 사용자 `_config.yml` 의 hotkey 라인을 검사하여 다음 3종을 자동 제거:
/// 1. **시스템 예약 충돌**: `ShortcutBlacklist.isReserved()` 매칭 (Issue90 활용)
/// 2. **폐기된 액션 키**: 코드에서 더 이상 참조하지 않는 hotkey 키
/// 3. **(보존)** Issue88 default 빈 값 정정: 사용자가 직접 설정한 값은 (1)에서 같이 처리됨
///
/// 동작:
/// - 정리 항목이 있으면 한 번만 `_config.yml.backup_YYYYMMDD-HHMMSS` 백업 후 in-place 수정
/// - 정리 항목이 0개면 백업도 생성하지 않음 (idempotent)
/// - 같은 날 두 번째 실행이라도 변경 항목이 있으면 새 백업 생성 (HH-MM-SS 까지 포함하여 고유)
enum ConfigMigration {

    /// 코드에서 인식하는 유효 hotkey 키 화이트리스트
    /// 이 목록 외의 `*.hotkey` / `*_hotkey` 키는 폐기된 것으로 간주
    static let knownHotkeyKeys: Set<String> = [
        "history.viewer.hotkey",
        "history.pause.hotkey",
        "history.preview.hotkey",
        "history.registerSnippet.hotkey",
        "settings.hotkey",
        "snippet_popup_hotkey",
    ]

    /// Issue95: 백업 파일 보존 개수 (가장 최근 N개만 유지)
    /// 새 백업이 생성된 직후 cleanup이 실행되므로, N=5면 새 1개 + 직전 4개가 보존됨
    static let backupKeepCount = 5

    /// 마이그레이션 결과
    struct Result {
        /// 시스템 예약(블랙리스트) 매칭으로 빈 값 처리된 키
        var blacklisted: [String] = []
        /// 폐기된 액션 키로 라인 제거된 키
        var obsolete: [String] = []
        /// 백업 파일 경로 (변경 발생 시에만)
        var backupPath: String?
        /// Issue95: cleanup으로 삭제된 오래된 백업 파일 경로
        var removedBackups: [String] = []

        var totalCleaned: Int { blacklisted.count + obsolete.count }
        var hasChanges: Bool { totalCleaned > 0 }
    }

    /// _config.yml 마이그레이션 수행
    /// - Parameter configURL: `_config.yml` 파일 URL
    /// - Returns: 마이그레이션 결과 (변경 없으면 hasChanges == false)
    @discardableResult
    static func migrate(at configURL: URL) -> Result {
        var result = Result()

        let fm = FileManager.default
        guard fm.fileExists(atPath: configURL.path) else {
            // 파일 없으면 마이그레이션 대상 아님
            return result
        }

        let content: String
        do {
            content = try String(contentsOf: configURL, encoding: .utf8)
        } catch {
            logE("⚙️ ❌ [ConfigMigration] 읽기 실패: \(error)")
            return result
        }

        let lines = content.components(separatedBy: "\n")
        var newLines: [String] = []
        newLines.reserveCapacity(lines.count)

        for line in lines {
            let (key, value) = parseHotkeyLine(line)

            // hotkey 라인이 아니면 그대로 통과
            guard let key = key, let value = value else {
                newLines.append(line)
                continue
            }

            // 1. 폐기된 액션 키: 라인 자체 제거
            if !knownHotkeyKeys.contains(key) {
                result.obsolete.append(key)
                logI("⚙️ [ConfigMigration] 폐기된 hotkey 키 제거: \(key)")
                continue
            }

            // 2. 시스템 예약 매칭: 빈 값으로 정정 (라인은 보존하여 사용자 가시성 유지)
            if !value.isEmpty && ShortcutBlacklist.isReserved(value) {
                let reason = ShortcutBlacklist.reason(for: value) ?? "System Reserved"
                result.blacklisted.append(key)
                logI(
                    "⚙️ [ConfigMigration] 시스템 예약 hotkey 정리: \(key)='\(value)' (\(reason)) → 빈 값"
                )
                // 들여쓰기 보존
                let indent = leadingWhitespace(line)
                newLines.append("\(indent)\(key): \"\"")
                continue
            }

            // 정상 — 그대로 통과
            newLines.append(line)
        }

        // 변경 없으면 idempotent — 종료 (단, 누적된 오래된 백업 정리는 항상 실행)
        guard result.hasChanges else {
            logV("⚙️ [ConfigMigration] 정리 대상 없음 (idempotent)")
            result.removedBackups = cleanupOldBackups(near: configURL, keep: backupKeepCount)
            return result
        }

        // 백업 생성 (한 번만, 같은 초까지 포함하여 고유)
        let backupURL = makeBackupURL(for: configURL)
        do {
            try fm.copyItem(at: configURL, to: backupURL)
            result.backupPath = backupURL.path
            logI("⚙️ [ConfigMigration] 백업 생성: \(backupURL.path)")
        } catch {
            // 백업 실패 시 in-place 수정 보류 (안전 우선)
            logE("⚙️ ❌ [ConfigMigration] 백업 실패 — 정리 중단: \(error)")
            result.blacklisted.removeAll()
            result.obsolete.removeAll()
            return result
        }

        // 정리된 내용 저장
        let newContent = newLines.joined(separator: "\n")
        do {
            try newContent.write(to: configURL, atomically: true, encoding: .utf8)
            logI(
                "⚙️ [ConfigMigration] hotkey 마이그레이션 완료: 정리 \(result.totalCleaned)건 (예약 \(result.blacklisted.count) + 폐기 \(result.obsolete.count)) — 백업 \(backupURL.lastPathComponent)"
            )
        } catch {
            logE("⚙️ ❌ [ConfigMigration] 쓰기 실패: \(error)")
        }

        // Issue95: 새 백업이 생성된 직후 누적된 오래된 백업 정리
        result.removedBackups = cleanupOldBackups(near: configURL, keep: backupKeepCount)

        return result
    }

    /// Issue95: `_config.yml.backup_*` 누적 정리
    ///
    /// 정책: **최근 N개 보존, 그 외 삭제** (단순 개수 기반 — 시간 기반 추가 정책은 향후 이슈에서 확장 가능)
    /// 호출 시점: `migrate()` 종료 직전 (변경 유무 무관)
    /// idempotent: N개 이하면 no-op
    ///
    /// - Parameters:
    ///   - configURL: `_config.yml` 파일 URL (백업은 같은 디렉토리 내 `<name>.backup_<stamp>` 패턴)
    ///   - keep: 보존할 백업 개수 (기본 `backupKeepCount`)
    /// - Returns: 삭제된 백업 파일 절대경로 목록
    @discardableResult
    static func cleanupOldBackups(near configURL: URL, keep: Int = backupKeepCount) -> [String] {
        let fm = FileManager.default
        let dir = configURL.deletingLastPathComponent()
        let baseName = configURL.lastPathComponent
        let prefix = "\(baseName).backup_"

        var removed: [String] = []

        guard let entries = try? fm.contentsOfDirectory(atPath: dir.path) else {
            return removed
        }

        let backups = entries
            .filter { $0.hasPrefix(prefix) }
            .sorted()  // stamp가 yyyyMMdd-HHmmss 이므로 사전순 = 시간순

        guard backups.count > keep else {
            return removed
        }

        let toRemove = backups.prefix(backups.count - keep)
        for name in toRemove {
            let fileURL = dir.appendingPathComponent(name)
            do {
                try fm.removeItem(at: fileURL)
                removed.append(fileURL.path)
                logI("⚙️ [ConfigMigration] 오래된 백업 삭제: \(name) (정책: 최근 \(keep)개만 보존)")
            } catch {
                logW("⚙️ [ConfigMigration] 백업 삭제 실패 \(name): \(error)")
            }
        }

        return removed
    }

    // MARK: - Helpers

    /// `  key: "value"` 또는 `key: value` 라인에서 (key, value) 추출
    /// hotkey 키가 아니면 (nil, nil)
    static func parseHotkeyLine(_ line: String) -> (key: String?, value: String?) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return (nil, nil) }

        // "key: value" 형태
        let parts = trimmed.split(separator: ":", maxSplits: 1).map { String($0) }
        guard parts.count == 2 else { return (nil, nil) }

        let key = parts[0].trimmingCharacters(in: .whitespaces)
        var value = parts[1].trimmingCharacters(in: .whitespaces)

        // hotkey 키만 대상 — `.hotkey` 로 끝나거나 `_hotkey` 로 끝나는 것
        guard key.hasSuffix(".hotkey") || key.hasSuffix("_hotkey") else {
            return (nil, nil)
        }

        // 따옴표 제거
        if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
            value = String(value.dropFirst().dropLast())
        } else if value.hasPrefix("'") && value.hasSuffix("'") && value.count >= 2 {
            value = String(value.dropFirst().dropLast())
        }

        return (key, value)
    }

    private static func leadingWhitespace(_ line: String) -> String {
        var ws = ""
        for ch in line {
            if ch == " " || ch == "\t" {
                ws.append(ch)
            } else {
                break
            }
        }
        return ws
    }

    private static func makeBackupURL(for configURL: URL) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let dir = configURL.deletingLastPathComponent()
        let name = configURL.lastPathComponent
        return dir.appendingPathComponent("\(name).backup_\(stamp)")
    }
}
