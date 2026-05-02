import Foundation

/// Issue90 + Issue96_2: macOS 시스템 표준 단축키 블랙리스트
///
/// `ShortcutMgr.registerAppGlobalShortcuts()` 진입 시 사용자 `_config.yml` 의
/// hotkey 토큰을 검사하여 macOS 표준 단축키와 충돌할 경우 등록을 거부함.
///
/// 차단 대상 (14개 + α):
/// - ⌘S (Save), ⌘C (Copy), ⌘V (Paste), ⌘X (Cut), ⌘A (Select All), ⌘Z (Undo)
/// - ⌘N (New), ⌘O (Open), ⌘P (Print), ⌘F (Find)
/// - ⌘Q (Quit), ⌘W (Close Window), ⌘T (New Tab), ⌘R (Reload)
/// - ⌘⇧Z (Redo) — 명세 외 추가 (사용자 충돌 빈도 높음)
/// - Issue96_2 추가: ⌘⇧S (Save As), ⌘D (Duplicate), ⌘E (Use Selection for Find), ⌘G (Find Next)
///
/// 비차단 (사용자 임의):
/// - ⌃⇧⌘; (settings.hotkey 기존 사용)
/// - ⌃⇧Space (snippet popup 기존 사용)
/// - ⌘; / 그 외 단일 ⌘+키 조합 중 위 명시 항목만 차단
enum ShortcutBlacklist {

    /// macOS 표준 예약 단축키 (정규화된 keySpec 기준)
    /// 정규화 규칙:
    /// - 중괄호 `{}` 래핑 제거
    /// - 한글/영문 호환을 위해 키 부분 대문자
    /// - modifier 순서: `^⌥⌘⇧` (`⌃` → `^` 정규화)
    private static let reservedSet: Set<String> = [
        "⌘S",   // Save
        "⌘C",   // Copy
        "⌘V",   // Paste
        "⌘X",   // Cut
        "⌘A",   // Select All
        "⌘Z",   // Undo
        "⌘N",   // New
        "⌘O",   // Open
        "⌘P",   // Print
        "⌘F",   // Find
        "⌘Q",   // Quit
        "⌘W",   // Close Window
        "⌘T",   // New Tab
        "⌘R",   // Reload
        "⌘⇧Z",  // Redo (추가)
        "⌘⇧S",  // Save As (Issue96_2)
        "⌘D",   // Duplicate / Don't Save (Issue96_2)
        "⌘E",   // Use Selection for Find (Issue96_2)
        "⌘G",   // Find Next (Issue96_2)
    ]

    /// 사용자 친화 설명 (logW + 알림 메시지용)
    private static let reasonMap: [String: String] = [
        "⌘S": "Save (저장)",
        "⌘C": "Copy (복사)",
        "⌘V": "Paste (붙여넣기)",
        "⌘X": "Cut (잘라내기)",
        "⌘A": "Select All (모두 선택)",
        "⌘Z": "Undo (실행 취소)",
        "⌘N": "New (새로 만들기)",
        "⌘O": "Open (열기)",
        "⌘P": "Print (인쇄)",
        "⌘F": "Find (찾기)",
        "⌘Q": "Quit (종료)",
        "⌘W": "Close Window (창 닫기)",
        "⌘T": "New Tab (새 탭)",
        "⌘R": "Reload (새로 고침)",
        "⌘⇧Z": "Redo (다시 실행)",
        "⌘⇧S": "Save As (다른 이름으로 저장)",
        "⌘D": "Duplicate (복제) / Don't Save (저장 안 함)",
        "⌘E": "Use Selection for Find (찾기에 사용)",
        "⌘G": "Find Next (다음 찾기)",
    ]

    /// 단축키 토큰을 정규화된 형태로 변환
    /// - 중괄호 `{}` 제거
    /// - `⌃` → `^` 변환은 modifier 셋 내에서만 (⌘S 와 ^S 는 분리: ^S는 control+S)
    /// - 알파벳 키 대문자화
    static func normalize(_ token: String) -> String {
        var s = token

        // 중괄호 래핑 제거
        if s.hasPrefix("{") && s.hasSuffix("}") {
            s = String(s.dropFirst().dropLast())
        }

        // modifier 와 key 분리
        let modifiers: Set<Character> = ["^", "⌃", "⌥", "⌘", "⇧"]
        var modPart = ""
        var keyPart = ""
        for ch in s {
            if modifiers.contains(ch) {
                modPart.append(ch == "⌃" ? "^" : ch)
            } else {
                keyPart.append(ch)
            }
        }

        // 단일 알파벳 키만 대문자화 (이름 키 ex Space, F1 은 그대로)
        if keyPart.count == 1, let scalar = keyPart.unicodeScalars.first,
            scalar.isASCII && CharacterSet.letters.contains(scalar)
        {
            keyPart = keyPart.uppercased()
        }

        return modPart + keyPart
    }

    /// 토큰이 macOS 시스템 예약 단축키와 충돌하는지 검사
    /// - Parameter token: `_config.yml` 의 hotkey 값 (ex: `"⌘S"`, `"{⌘S}"`, `"⌘s"`)
    /// - Returns: 예약 단축키이면 true
    static func isReserved(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        return reservedSet.contains(normalize(token))
    }

    /// 차단 사유 설명 반환 (로그/알림용)
    /// - Returns: 매칭되는 시스템 액션 설명 (없으면 nil)
    static func reason(for token: String) -> String? {
        guard !token.isEmpty else { return nil }
        return reasonMap[normalize(token)]
    }

    /// 전체 블랙리스트 카운트 (테스트/디버그용)
    static var count: Int { reservedSet.count }

    /// 전체 블랙리스트 셋 노출 (테스트용)
    static var allReserved: Set<String> { reservedSet }
}
