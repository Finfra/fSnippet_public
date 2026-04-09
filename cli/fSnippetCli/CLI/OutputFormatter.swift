import Foundation

// MARK: - 출력 포매터

/// CLI 출력을 text/json 형식으로 변환
struct OutputFormatter {

    let jsonMode: Bool

    init(jsonMode: Bool = false) {
        self.jsonMode = jsonMode
    }

    // MARK: - JSON 출력

    /// API 응답 JSON을 그대로 출력 (--json 모드)
    func printJSON(_ data: Data?) {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else {
            print("{}")
            return
        }
        print(str)
    }

    // MARK: - 테이블 출력

    /// 테이블 헤더 + 행 출력
    func printTable(headers: [String], rows: [[String]]) {
        guard !rows.isEmpty else {
            print("결과 없음")
            return
        }

        // 열 너비 계산
        var widths = headers.map { $0.displayWidth }
        for row in rows {
            for (i, cell) in row.enumerated() where i < widths.count {
                widths[i] = max(widths[i], cell.displayWidth)
            }
        }

        // 헤더 출력
        let headerLine = zip(headers, widths).map { $0.0.padded(to: $0.1) }.joined(separator: "  ")
        print(headerLine)
        let separator = widths.map { String(repeating: "-", count: $0) }.joined(separator: "  ")
        print(separator)

        // 행 출력
        for row in rows {
            let line = zip(row, widths).map { $0.0.padded(to: $0.1) }.joined(separator: "  ")
            print(line)
        }
    }

    // MARK: - 키-값 출력

    /// 키-값 쌍 출력 (status, version 등)
    func printKeyValue(_ pairs: [(String, String)]) {
        let maxKeyWidth = pairs.map { $0.0.displayWidth }.max() ?? 0
        for (key, value) in pairs {
            print("  \(key.padded(to: maxKeyWidth)): \(value)")
        }
    }

    // MARK: - 에러 출력

    /// 에러 메시지 출력
    static func printError(_ message: String) {
        fputs("오류: \(message)\n", stderr)
    }
}

// MARK: - String 확장 (표시 너비 패딩)

private extension String {
    /// 유니코드 문자 표시 너비 (한글 등 2칸 문자 고려)
    var displayWidth: Int {
        var width = 0
        for scalar in unicodeScalars {
            if scalar.value >= 0x1100 && scalar.value <= 0x115F { width += 2 }
            else if scalar.value >= 0x2E80 && scalar.value <= 0xA4CF { width += 2 }
            else if scalar.value >= 0xAC00 && scalar.value <= 0xD7AF { width += 2 }
            else if scalar.value >= 0xF900 && scalar.value <= 0xFAFF { width += 2 }
            else if scalar.value >= 0xFE30 && scalar.value <= 0xFE6F { width += 2 }
            else if scalar.value >= 0xFF01 && scalar.value <= 0xFF60 { width += 2 }
            else if scalar.value >= 0x1F000 { width += 2 } // 이모지
            else { width += 1 }
        }
        return width
    }

    /// 표시 너비에 맞춰 패딩
    func padded(to targetWidth: Int) -> String {
        let padding = max(0, targetWidth - displayWidth)
        return self + String(repeating: " ", count: padding)
    }
}
