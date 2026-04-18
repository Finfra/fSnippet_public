//
//  PaidAppStateLoggerTests.swift
//  fSnippetCliTests
//
//  Created by Claude Code on 2026.04.18.
//  Phase 0-3: 상태 전환 로깅 모듈 단위 테스트

import XCTest
import Foundation

@testable import fSnippetCli

final class PaidAppStateLoggerTests: XCTestCase {

    var testTmpDir: URL!

    override func setUp() {
        super.setUp()
        testTmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PaidAppStateLoggerTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: testTmpDir, withIntermediateDirectories: true, attributes: nil)
    }

    override func tearDown() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: testTmpDir)
        PaidAppStateLogger.testableDefaultsOverride = nil
        super.tearDown()
    }

    private func setupUserDefaults() {
        let suiteName = "PaidAppStateLoggerTests_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        testDefaults.set(testTmpDir.path, forKey: "appRootPath")
        PaidAppStateLogger.testableDefaultsOverride = testDefaults
    }

    // 테스트 1: ISO8601 타임스탬프와 상태를 포함한 한 줄씩 기록
    func testRecord_writesISO8601LineWithStates() throws {
        setupUserDefaults()

        try PaidAppStateLogger.record(
            previous: "cli-only",
            next: "paidApp-active",
            eventType: "transition",
            extra: nil
        )

        let logFileURL = PaidAppStateLogger.logFileURL
        let content = try String(contentsOf: logFileURL, encoding: .utf8)
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)

        XCTAssertEqual(lines.count, 1, "로그 파일에 정확히 1줄이 있어야 함")

        let line = lines[0]
        // ISO8601 + [transition] + states 패턴
        let regex = try NSRegularExpression(
            pattern: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z \[transition\] cli-only -> paidApp-active$"#,
            options: []
        )
        let range = NSRange(line.startIndex..., in: line)
        let matches = regex.matches(in: line, options: [], range: range)

        XCTAssertFalse(matches.isEmpty, "로그 라인이 ISO8601 포맷을 따르고 상태를 포함해야 함: \(line)")
    }

    // 테스트 2: 다중 레코드가 순차적으로 기록됨
    func testRecord_appendsMultipleLinesInOrder() throws {
        setupUserDefaults()

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

        XCTAssertEqual(lines.count, 3, "로그 파일에 정확히 3줄이 있어야 함")
        XCTAssertTrue(lines[0].contains("cli-only -> paidApp-active"), "첫 번째 줄에 올바른 상태가 있어야 함")
        XCTAssertTrue(lines[1].contains("paidApp-active -> paidApp-inactive"), "두 번째 줄에 올바른 상태가 있어야 함")
        XCTAssertTrue(lines[2].contains("paidApp-inactive -> cli-only"), "세 번째 줄에 올바른 상태가 있어야 함")
    }

    // 테스트 3: extra 파라미터가 있을 때 suffix 포함
    func testRecord_includesExtraSuffixWhenProvided() throws {
        setupUserDefaults()

        try PaidAppStateLogger.record(
            previous: "cli-only",
            next: "connecting",
            eventType: "register",
            extra: ["pid": "1234", "bundleId": "com.nowage.fSnippet"]
        )

        let logFileURL = PaidAppStateLogger.logFileURL
        let content = try String(contentsOf: logFileURL, encoding: .utf8)
        let line = content.trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertTrue(line.contains("extra={"), "extra 사전이 포함되어야 함")
        XCTAssertTrue(line.contains("pid=1234"), "pid 값이 포함되어야 함")
        XCTAssertTrue(line.contains("bundleId=com.nowage.fSnippet"), "bundleId 값이 포함되어야 함")
    }

    // 테스트 4: extra가 nil 또는 empty일 때 suffix 없음
    func testRecord_noExtraSuffixWhenNilOrEmpty() throws {
        setupUserDefaults()

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

        XCTAssertEqual(lines.count, 2)
        for line in lines {
            XCTAssertFalse(line.contains("extra="), "extra 사전이 없으면 suffix도 없어야 함: \(line)")
        }
    }

    // 테스트 5: 디렉토리가 없으면 자동 생성
    func testRecord_createsDirectoryIfMissing() throws {
        // 존재하지 않는 하위 경로를 appRootPath로 직접 등록 (setupUserDefaults 미사용)
        let nonexistentPath = testTmpDir.appendingPathComponent("nonexistent").path
        let suiteName = "PaidAppStateLoggerTests_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        testDefaults.set(nonexistentPath, forKey: "appRootPath")
        PaidAppStateLogger.testableDefaultsOverride = testDefaults

        // record 호출 시 PaidAppStateLogger가 logs/ 하위 디렉토리를 자동 생성해야 함
        try PaidAppStateLogger.record(
            previous: "a",
            next: "b",
            eventType: "test",
            extra: nil
        )

        let logsDir = URL(fileURLWithPath: nonexistentPath).appendingPathComponent("logs")
        let dirExists = FileManager.default.fileExists(atPath: logsDir.path)
        XCTAssertTrue(dirExists, "로그 디렉토리가 자동으로 생성되어야 함: \(logsDir.path)")
    }

    // 테스트 6: legacyEnabledCount는 fresh 상태에서 1부터 시작
    func testIncrementLegacyEnabledCount_startsAt1() throws {
        setupUserDefaults()

        let count = try PaidAppStateLogger.incrementLegacyEnabledCount()
        XCTAssertEqual(count, 1, "첫 번째 호출 후 카운트는 1이어야 함")
    }

    // 테스트 7: legacyEnabledCount 누적
    func testIncrementLegacyEnabledCount_persistsAcrossCalls() throws {
        setupUserDefaults()

        let count1 = try PaidAppStateLogger.incrementLegacyEnabledCount()
        let count2 = try PaidAppStateLogger.incrementLegacyEnabledCount()
        let count3 = try PaidAppStateLogger.incrementLegacyEnabledCount()

        XCTAssertEqual(count1, 1)
        XCTAssertEqual(count2, 2)
        XCTAssertEqual(count3, 3)

        // 즉시 읽기 확인
        let currentCount = PaidAppStateLogger.legacyEnabledCount
        XCTAssertEqual(currentCount, 3, "현재 카운트는 3이어야 함")
    }

    // 테스트 8: legacyEnabledCount는 파일이 없을 때 0
    func testLegacyEnabledCount_zeroWhenAbsent() throws {
        setupUserDefaults()

        // counter 파일을 아직 생성하지 않음
        let count = PaidAppStateLogger.legacyEnabledCount
        XCTAssertEqual(count, 0, "counter 파일이 없을 때 카운트는 0이어야 함")
    }

    // 테스트 9: 스레드 안전성 - 동시 write 직렬화
    func testRecord_threadSafe_serializedWrites() throws {
        setupUserDefaults()

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

        // 동기화를 위해 DispatchSemaphore 사용
        let sema = DispatchSemaphore(value: 0)
        group.notify(queue: .global()) {
            sema.signal()
        }
        sema.wait()

        XCTAssertTrue(recordErrors.isEmpty, "동시 write 중에 오류가 없어야 함")

        let logFileURL = PaidAppStateLogger.logFileURL
        let content = try String(contentsOf: logFileURL, encoding: .utf8)
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)

        XCTAssertEqual(lines.count, recordCount, "정확히 \(recordCount)줄이 있어야 함, 실제: \(lines.count)")
    }

    // 테스트 10: 스레드 안전성 - increment 누적
    func testIncrementLegacyEnabledCount_threadSafe() throws {
        setupUserDefaults()

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

        // 동기화를 위해 DispatchSemaphore 사용
        let sema = DispatchSemaphore(value: 0)
        group.notify(queue: .global()) {
            sema.signal()
        }
        sema.wait()

        XCTAssertTrue(incrementErrors.isEmpty, "동시 increment 중에 오류가 없어야 함")

        let finalCount = PaidAppStateLogger.legacyEnabledCount
        XCTAssertEqual(finalCount, incrementCount, "최종 카운트는 \(incrementCount)이어야 함, 실제: \(finalCount)")
    }
}
