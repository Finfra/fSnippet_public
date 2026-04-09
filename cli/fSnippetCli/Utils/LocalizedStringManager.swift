import Foundation

/// Issue14: 다국어 문자열 관리자
/// _config.yml의 language 설정("kr", "en", "system" 등)에 따라 적절한 문자열을 반환함.
/// NSLocalizedString 대신 직접 딕셔너리 기반으로 관리하여 .strings 파일 없이도 동작.
class LocalizedStringManager {
    static let shared = LocalizedStringManager()

    /// 현재 활성화된 언어 코드 (ISO 639-1 기준: "ko", "en", "ja" 등)
    /// "system"이면 시스템 언어를 따름
    private(set) var currentLanguage: String = "en"

    private init() {
        reload()
    }

    /// PreferencesManager 설정에서 언어를 다시 읽어 반영
    func reload() {
        let configLang: String = PreferencesManager.shared.get("language") ?? "system"
        let normalized = Self.normalizeLanguageCode(configLang)

        if normalized == "system" {
            // 시스템 선호 언어에서 추출
            let preferred = Locale.preferredLanguages.first ?? "en"
            currentLanguage = String(preferred.prefix(2))  // "ko-KR" → "ko"
        } else {
            currentLanguage = normalized
        }
        logV("🌐 [L10n] 언어 설정 로드: config='\(configLang)' → normalized='\(normalized)' → active='\(currentLanguage)'")
    }

    /// 현재 언어가 한국어인지 여부
    var isKorean: Bool { currentLanguage == "ko" }

    /// 키에 해당하는 다국어 문자열 반환
    /// - Parameters:
    ///   - key: 문자열 키 (ex: "toast.clipboard_paused")
    ///   - defaultValue: 키가 없을 때 fallback 값 (nil이면 key 자체 반환)
    func string(_ key: String, default defaultValue: String? = nil) -> String {
        let table = strings[currentLanguage] ?? strings["en"]!
        return table[key] ?? defaultValue ?? key
    }

    // MARK: - 언어 코드 정규화

    /// 국가 코드 등 잘못된 언어 코드를 Apple 표준(ISO 639-1)으로 정규화
    /// SettingsObservableObject.normalizeLanguageCode와 동일 로직 (의존성 분리)
    static func normalizeLanguageCode(_ code: String) -> String {
        let countryToLanguage: [String: String] = [
            "kr": "ko",  // 한국(KR) → 한국어(ko)
            "jp": "ja",  // 일본(JP) → 일본어(ja)
            "cn": "zh-Hans",  // 중국(CN) → 중국어 간체
            "tw": "zh-Hant",  // 대만(TW) → 중국어 번체
            "us": "en",  // 미국(US) → 영어
            "gb": "en",  // 영국(GB) → 영어
            "br": "pt",  // 브라질(BR) → 포르투갈어
        ]
        let lowered = code.lowercased()
        return countryToLanguage[lowered] ?? code
    }

    // MARK: - 다국어 문자열 테이블

    /// 언어별 문자열 딕셔너리
    /// 새 언어 추가 시 여기에 딕셔너리를 추가하면 됨
    private let strings: [String: [String: String]] = [
        // 영어 (기본)
        "en": [
            // 토스트 - 클립보드
            "toast.clipboard_paused": "Clipboard Paused",
            "toast.clipboard_resumed": "Clipboard Resumed",

            // 토스트 - 프리뷰
            "toast.preview_off": "Preview : OFF",
            "toast.preview_on": "Preview : ON",

            // 토스트 - 히스토리
            "toast.no_matching_items": "No matching items to delete",
            "toast.deleted_matches": "Deleted matches",
            "toast.image_saved": "Image Saved",
            "toast.image_not_found": "Image File Not Found",
            "toast.save_failed": "Save Failed",
            "toast.no_image_data": "No Image Data",
            "toast.saved": "Saved",
            "toast.line_deleted": "Line Deleted",

            // 토스트 - 유료 기능
            "toast.paid_only": "Only Support\nthe Paid Version",
            "toast.paid_launched": "fSnippet Launched\nPlease try again",
        ],

        // 한국어
        "ko": [
            // 토스트 - 클립보드
            "toast.clipboard_paused": "클립보드 일시정지",
            "toast.clipboard_resumed": "클립보드 재개",

            // 토스트 - 프리뷰
            "toast.preview_off": "미리보기 : OFF",
            "toast.preview_on": "미리보기 : ON",

            // 토스트 - 히스토리
            "toast.no_matching_items": "삭제할 항목 없음",
            "toast.deleted_matches": "일치 항목 삭제됨",
            "toast.image_saved": "이미지 저장 완료",
            "toast.image_not_found": "이미지 파일 없음",
            "toast.save_failed": "저장 실패",
            "toast.no_image_data": "이미지 데이터 없음",
            "toast.saved": "저장 완료",
            "toast.line_deleted": "라인 삭제됨",

            // 토스트 - 유료 기능
            "toast.paid_only": "유료 버전에서만\n지원됩니다",
            "toast.paid_launched": "fSnippet 실행됨\n기능을 다시 시도해주세요",
        ],

        // 일본어
        "ja": [
            "toast.clipboard_paused": "クリップボード一時停止",
            "toast.clipboard_resumed": "クリップボード再開",
            "toast.preview_off": "プレビュー : OFF",
            "toast.preview_on": "プレビュー : ON",
            "toast.no_matching_items": "削除する項目なし",
            "toast.deleted_matches": "一致する項目を削除",
            "toast.image_saved": "画像を保存しました",
            "toast.image_not_found": "画像ファイルが見つかりません",
            "toast.save_failed": "保存失敗",
            "toast.no_image_data": "画像データなし",
            "toast.saved": "保存しました",
            "toast.line_deleted": "行を削除しました",
            "toast.paid_only": "有料版のみ\nサポート",
            "toast.paid_launched": "fSnippet起動済み\nもう一度お試しください",
        ],
    ]
}
