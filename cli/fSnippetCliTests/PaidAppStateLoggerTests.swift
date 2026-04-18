//
//  PaidAppStateLoggerTests.swift
//  fSnippetCliTests
//
//  Created by Claude Code on 2026.04.18.
//  Phase 0-3: 상태 전환 로깅 모듈 단위 테스트

import Testing
import Foundation

@testable import fSnippetCli

// 테스트 접근성을 위한 import 확인

struct PaidAppStateLoggerTests {

    var testTmpDir: URL!

    init() {
        testTmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PaidAppStateLoggerTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: testTmpDir, withIntermediateDirectories: true, attributes: nil)
    }

    mutating func setupUserDefaults() {
        let suiteName = "PaidAppStateLoggerTests_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        testDefaults.set(testTmpDir.path, forKey: "appRootPath")
        PaidAppStateLogger.testableDefaultsOverride = testDefaults
    }

    mutating func teardownUserDefaults() {
        PaidAppStateLogger.testableDefaultsOverride = nil
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: testTmpDir)
    }

    // 테스트 1: ISO8601 타임스탬프와 상태를 포함한 한 줄씩 기록
    @Test mutating func testRecord_writesISO8601LineWithStates() async throws {
        setupUserDefaults()
        defer { teardownUserDefaults() }

        try PaidAppStateLogger.record(
            previous: "cli-only",
            next: "paidApp-active",
            eventType: "transition",
            extra: nil
        )

        let logFileURL = PaidAppStateLogger.logFileURL
        let content = try String(contentsOf: logFileURL, encoding: .utf8)
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)

        #expect(lines.count == 1, "로그 파일에 정확히 1줄이 있어야 함")

        let line = lines[0]
        // ISO8601 + [transition] + states 패턴
        let regex = try NSRegularExpression(
            pattern: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z \[transition\] cli-only -> paidApp-active$"#,
            options: []
        )
        let range = NSRange(line.startIndex..., in: line)
        let matches = regex.matches(in: line, options: [], range: range)

        #expect(!matches.isEmpty, "로그 라인이 ISO8601 포맷을 따르고 상태를 포함해야 함: \(line)")
    }

    // 테스트 2: 다중 레코드가 순차적으로 기록됨
    @Test mutating func testRecord_appendsMultipleLinesInOrder() async throws {
        setupUserDefaults()
        defer { teardownUserDefaults() }

        try PaidAppStateLogger.record(
            previous: "cli-only",
            next: "paidApp-active",
            eventType: "transition",
            extra: nil
        )
        try PaidAppStateLogger.record(
            previous: "paidApp-active",
            next: "paidApp-inactive",
            eventType: "transition",
            extra: nil
        )
        try PaidAppStateLogger.record(
            previous: "paidApp-inactive",
            next: "cli-only",
            eventType: "transition",
            extra: nil
        )

        let logFileURL = PaidAppStateLogger.logFileURL
        let content = try String(contentsOf: logFileURL, encoding: .utf8)
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)

        #expect(lines.count == 3, "로그 파일에 정확히 3줄이 있어야 함")
        #expect(lines[0].contains("cli-only -> paidApp-active"), "첫 번째 줄에 올바른 상태가 있어야 함")
        #expect(lines[1].contains("paidApp-active -> paidApp-inactive"), "두 번째 줄에 올바른 상태가 있어야 함")
        #expect(lines[2].contains("paidApp-inactive -> cli-only"), "세 번째 줄에 올바른 상태가 있어야 함")
    }

    // 테스트 3: extra 파라미터가 있을 때 suffix 포함
    @Test mutating func testRecord_includesExtraSuffixWhenProvided() async throws {
        setupUserDefaults()
        defer { teardownUserDefaults() }

        try PaidAppStateLogger.record(
            previous: "cli-only",
            next: "connecting",
            eventType: "register",
            extra: ["pid": "1234", "bundleId": "com.nowage.fSnippet"]
        )

        let logFileURL = PaidAppStateLogger.logFileURL
        let content = try String(contentsOf: logFileURL, encoding: .utf8)
        let line = content.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(line.contains("extra={"), "extra 사전이 포함되어야 함")
        #expect(line.contains("pid=1234"), "pid 값이 포함되어야 함")
        #expect(line.contains("bundleId=com.nowage.fSnippet"), "bundleId 값이 포함되어야 함")
    }

    // 테스트 4: extra가 nil 또는 empty일 때 suffix 없음
    @Test mutating func testRecord_noExtraSuffixWhenNilOrEmpty() async throws {
        setupUserDefaults()
        defer { teardownUserDefaults() }

        try PaidAppStateLogger.record(
            previous: "a",
            next: "b",
            eventType: "transition",
            extra: nil
        )
        try PaidAppStateLogger.record(
            previous: "b",
            next: "c",
            eventType: "transition",
            extra: [:]
        )

        let logFileURL = PaidAppStateLogger.logFileURL
        let content = try String(contentsOf: logFileURL, encoding: .utf8)
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)

        #expect(lines.count == 2)
        for line in lines {
            #expect(!line.contains("extra="), "extra 사전이 없으면 suffix도 없어야 함: \(line)")
        }
    }

    // 테스트 5: 디렉토리가 없으면 자동 생성
    @Test mutating func testRecord_createsDirectoryIfMissing() throws {
        setupUserDefaults()
        defer { teardownUserDefaults() }

        let nonexistentPath = testTmpDir.path + "/nonexistent"
        UserDefaults(suiteName: "PaidAppStateLoggerTests")?.set(
            nonexistentPath,
            forKey: "appRootPath"
        )

        // PaidAppStateLogger는 logFileURL 접근 시 디렉토리 자동 생성
        try PaidAppStateLogger.record(
            previous: "a",
            next: "b",
            eventType: "test",
            extra: nil
        )

        let fileManager = FileManager.default
        let logsDir = testTmpDir.appendingPathComponent("nonexistent/logs")
        let dirExists = fileManager.fileExists(atPath: logsDir.path)
        #expect(dirExists, "로그 디렉토리가 자동으로 생성되어야 함")
    }

    // 테스트 6: legacyEnabledCount는 fresh 상태에서 1부터 시작
    @Test mutating func testIncrementLegacyEnabledCount_startsAt1() throws {
        setupUserDefaults()
        defer { teardownUserDefaults() }

        let count = try PaidAppStateLogger.incrementLegacyEnabledCount()
        #expect(count == 1, "첫 번째 호출 후 카운트는 1이어야 함")
    }

    // 테스트 7: legacyEnabledCount 누적
    @Test mutating func testIncrementLegacyEnabledCount_persistsAcrossCalls() throws {
        setupUserDefaults()
        defer { teardownUserDefaults() }

        let count1 = try PaidAppStateLogger.incrementLegacyEnabledCount()
        let count2 = try PaidAppStateLogger.incrementLegacyEnabledCount()
        let count3 = try PaidAppStateLogger.incrementLegacyEnabledCount()

        #expect(count1 == 1)
        #expect(count2 == 2)
        #expect(count3 == 3)

        // 즉시 읽기 확인
        let currentCount = PaidAppStateLogger.legacyEnabledCount
        #expect(currentCount == 3, "현재 카운트는 3이어야 함")
    }

    // 테스트 8: legacyEnabledCount는 파일이 없을 때 0
    @Test mutating func testLegacyEnabledCount_zeroWhenAbsent() throws {
        setupUserDefaults()
        defer { teardownUserDefaults() }

        // counter 파일을 아직 생성하지 않음
        let count = PaidAppStateLogger.legacyEnabledCount
        #expect(count == 0, "counter 파일이 없을 때 카운트는 0이어야 함")
    }

    // 테스트 9: 스레드 안전성 - 동시 write 직렬화
    @Test mutating func testRecord_threadSafe_serializedWrites() throws {
        setupUserDefaults()
        defer { teardownUserDefaults() }

        let recordCount = 50
        let group = DispatchGroup()
        var recordErrors: [Error] = []
        let errorLock = NSLock()

        for i in 0..<recordCount {
            DispatchQueue.global().async(group: group) {
                do {
                    try PaidAppStateLogger.record(
                        previous: "state_\(i)",
                        next: "state_\(i + 1)",
                        eventType: "concurrent_test",
                        extra: nil
                    )
                } catch {
                    errorLock.lock()
                    recordErrors.append(error)
                    errorLock.unlock()
                }
            }
        }

        // group.wait는 비동기 컨텍스트에서 사용 불가하므로 동기식으로 처리
        // DispatchSemaphore를 사용하여 동기화
        let sema = DispatchSemaphore(value: 0)
        group.notify(queue: .global()) {
            sema.signal()
        }
        sema.wait()

        #expect(recordErrors.isEmpty, "동시 write 중에 오류가 없어야 함")

        let logFileURL = PaidAppStateLogger.logFileURL
        let content = try String(contentsOf: logFileURL, encoding: .utf8)
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)

        #expect(lines.count == recordCount, "정확히 \(recordCount)줄이 있어야 함, 실제: \(lines.count)")
    }

    // 테스트 10: 스레드 안전성 - increment 누적
    @Test mutating func testIncrementLegacyEnabledCount_threadSafe() throws {
        setupUserDefaults()
        defer { teardownUserDefaults() }

        let incrementCount = 100
        let group = DispatchGroup()
        var incrementErrors: [Error] = []
        let errorLock = NSLock()

        for _ in 0..<incrementCount {
            DispatchQueue.global().async(group: group) {
                do {
                    _ = try PaidAppStateLogger.incrementLegacyEnabledCount()
                } catch {
                    errorLock.lock()
                    incrementErrors.append(error)
                    errorLock.unlock()
                }
            }
        }

        // group.wait는 비동기 컨텍스트에서 사용 불가하므로 동기식으로 처리
        // DispatchSemaphore를 사용하여 동기화
        let sema = DispatchSemaphore(value: 0)
        group.notify(queue: .global()) {
            sema.signal()
        }
        sema.wait()

        #expect(incrementErrors.isEmpty, "동시 increment 중에 오류가 없어야 함")

        let finalCount = PaidAppStateLogger.legacyEnabledCount
        #expect(finalCount == incrementCount, "최종 카운트는 \(incrementCount)이어야 함, 실제: \(finalCount)")
    }
}
