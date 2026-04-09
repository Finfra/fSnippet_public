import Foundation

/// 스니펫 항목 데이터 모델
struct SnippetItem: Identifiable {
    let id = UUID()
    let fileName: String  // 원본 파일명 (예: "ec2===EC2 Instance.txt")
    let name: String  // === 오른쪽 (comment) (예: "EC2 Instance")
    let folderPrefix: String  // 폴더 prefix (예: "aws")
    let keyword: String  // 파일 키워드 (예: "ec2")
    let folderSuffix: String  // 폴더 suffix (예: "◊")
    let content: String  // 파일 내용 (스니펫 텍스트)
    let filePath: String  // 전체 파일 경로

    var abbreviation: String {
        "\(folderPrefix)\(keyword)\(folderSuffix)"
    }

    // 화면 표시용 키워드 (특수문자 디코딩됨)
    var displayKeyword: String {
        SnippetItem.decodeKeyword(keyword)
    }

    // 화면 표시용 이름 (특수문자 디코딩됨)
    var displayName: String {
        SnippetItem.decodeKeyword(name)
    }

    static func decodeKeyword(_ text: String) -> String {
        var result = text
        let mappings = [
            "{period}": ".", "{comma}": ",", "{colon}": ":", "{semicolon}": ";",
            "{lbracket}": "[", "{rbracket}": "]", "{lparen}": "(", "{rparen}": ")",
            "{exclamation}": "!", "{question}": "?", "{asterisk}": "*", "{quote}": "\"",
            "{apostrophe}": "'", "{backtick}": "`", "{tilde}": "~", "{at}": "@",
            "{hash}": "#", "{dollar}": "$", "{percent}": "%", "{caret}": "^",
            "{ampersand}": "&", "{plus}": "+", "{equals}": "=", "{pipe}": "|",
            "{backslash}": "\\", "{lt}": "<", "{gt}": ">", "{space}": " ",
            "{underbar}": "_", "{lcurly}": "{", "{rcurly}": "}",
            // New mapping for space decoding (underscore -> space)
            // Note: Since we encode space to _, strict decoding of _ to space might be ambiguous if user intended underscore.
            // However, per Issue 609 requirements, we simplify space to _.
            // Decoding remains symmetric for compatibility where possible.

        ]

        for (placeholder, symbol) in mappings {
            result = result.replacingOccurrences(of: placeholder, with: symbol)
        }
        return result
    }

    // 파일명 저장을 위한 인코딩 (특수문자 -> 플래이스홀더)
    static func encodeKeyword(_ text: String) -> String {
        // Issue 573: Preserve trailing underscore
        // trailing underscore is used for Initcap rule signals (e.g. ===A_.txt)
        if text.hasSuffix("_") {
            return encodeKeywordInternal(String(text.dropLast())) + "_"
        }
        return encodeKeywordInternal(text)
    }

    private static func encodeKeywordInternal(_ text: String) -> String {
        var result = text
        
        // 1. Temporary Placeholders for Brackets
        // We replace { and } first with unique tokens to prevent them from being
        // re-encoded when we process other symbols (like {period} which contains { and }).
        // This solves the double encoding issue (Issue 609).
        // Note: Do not use characters that are mapped later (like '_') in these tokens.
        let tempLeft = "⟪LCURLY⟫"
        let tempRight = "⟪RCURLY⟫"
        
        result = result.replacingOccurrences(of: "{", with: tempLeft)
        result = result.replacingOccurrences(of: "}", with: tempRight)
        
        // 2. Handle Underscore
        // Issue 609_2: User wants to keep '_' as is. No encoding to {underbar}.
        // Issue 609: Space is simplified to "_"
        // Result: Both " " and "_" result in "_". This creates ambiguity in decoding (reverse mapping),
        // but ensures filenames are clean and readable as requested.
        result = result.replacingOccurrences(of: " ", with: "_")
        
        // 4. Other Mappings (Ordered Array)
        // We use an array to ensure deterministic order, though with temp tokens it's less critical.
        // Note: { and } and space are already handled.
        // Issue 609_2: '.' (period) is also kept as is. Removed form mapping.
        let mappings: [(String, String)] = [
            (",", "{comma}"), (":", "{colon}"), (";", "{semicolon}"),
            ("[", "{lbracket}"), ("]", "{rbracket}"), ("(", "{lparen}"), (")", "{rparen}"),
            ("!", "{exclamation}"), ("?", "{question}"), ("*", "{asterisk}"), ("\"", "{quote}"),
            ("'", "{apostrophe}"), ("`", "{backtick}"), ("~", "{tilde}"), ("@", "{at}"),
            ("#", "{hash}"), ("$", "{dollar}"), ("%", "{percent}"), ("^", "{caret}"),
            ("&", "{ampersand}"), ("+", "{plus}"), ("=", "{equals}"), ("|", "{pipe}"),
            ("\\", "{backslash}"), ("<", "{lt}"), (">", "{gt}")
        ]

        for (symbol, placeholder) in mappings {
            result = result.replacingOccurrences(of: symbol, with: placeholder)
        }
        
        // 5. Restore Brackets as Placeholders
        result = result.replacingOccurrences(of: tempLeft, with: "{lcurly}")
        result = result.replacingOccurrences(of: tempRight, with: "{rcurly}")
        
        return result
    }
}
