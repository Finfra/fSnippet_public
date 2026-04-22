import Foundation

/// Issue14: 다국어 문자열 관리자 전역 헬퍼
/// Issue35: NSLocalizedString/Text("key") 대신 L10n("key")로 통일
func L10n(_ key: String, default defaultValue: String? = nil) -> String {
    return LocalizedStringManager.shared.string(key, default: defaultValue)
}

/// Issue14: 다국어 문자열 관리자
/// _config.yml의 language 설정("ko", "en", "system" 등)에 따라 적절한 문자열을 반환함.
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
            "kr": "ko",  // 하위 호환: 구형 config의 "kr" 값 → "ko" 자동 변환
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

            // Issue35: 플레이스홀더 입력창
            "placeholder.window.title": "Placeholder Input",
            "placeholder.label.preview": "Preview",
            "placeholder.button.cancel": "Cancel",
            "placeholder.button.confirm": "Confirm",
            "placeholder.help.history": "Insert from clipboard history",

            // Issue35: 스니펫 팝업
            "popup.search.placeholder": "Search snippets...",
            "popup.preview.empty": "No preview available",
            "popup.create.button": "Create '%@'",
            "popup.create.help": "Tab to edit, Enter to select",
            "popup.empty.no_results": "No results found",

            // Issue35: 히스토리 검색바
            "history.search.placeholder": "Search clipboard history...",
            "history.filter.all": "All",
            "history.filter.images": "Images",
            "history.filter.apps": "Filter by App",

            // Issue35: 히스토리 뷰어 - 컨텍스트 메뉴
            "menu.copy": "Copy",
            "menu.save_image": "Save Image",
            "menu.register": "Register as Snippet",
            "menu.delete": "Delete",

            // Issue35: 히스토리 뷰어 - 삭제 확인
            "alert.delete_items.title": "Delete %d item(s)?",
            "alert.delete_items.message": "This action cannot be undone.",
            "alert.common.delete": "Delete",
            "alert.common.cancel": "Cancel",
            "alert.filtered_delete.title": "Delete all items matching query?",
            "alert.filtered_delete.button": "Delete %d Items",
            "alert.filtered_delete.message": "This will permanently delete %d items that match '%@'. This finding logic is exactly same as your search result.\nThis action cannot be undone.",

            // Issue35: 히스토리 뷰어 - 푸터
            "viewer.footer.items": "%d items",
            "viewer.footer.selected": "%d selected",
            "viewer.status.paused": "Paused",
            "viewer.status.active": "Active",
            "viewer.help.resume": "Click to resume clipboard monitoring",
            "viewer.help.pause": "Click to pause clipboard monitoring",
            "viewer.help.shortcuts": "Keyboard Shortcuts",
            "viewer.help.show_shortcuts": "Show Keyboard Shortcuts",
            "viewer.help.delete_matches": "Delete all items matching the search query",
            "viewer.button.delete_matches": "Delete Matches",
            "viewer.preview.empty": "No preview available",

            // Issue35: 히스토리 뷰어 - 단축키 도움말
            "viewer.key.tab": "Tab",
            "viewer.key.enter": "Enter",
            "viewer.key.backspace": "Delete",
            "viewer.key.esc": "Esc",
            "viewer.action.preview_edit": "Preview / Edit",
            "viewer.action.copy_paste": "Copy & Paste",
            "viewer.action.quick_select": "Quick Select",
            "viewer.action.delete": "Delete Item",
            "viewer.action.register": "Register as Snippet",
            "viewer.action.toggle_pause": "Toggle Pause",
            "viewer.action.close": "Close",
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

            // Issue35: 플레이스홀더 입력창
            "placeholder.window.title": "플레이스홀더 입력",
            "placeholder.label.preview": "미리보기",
            "placeholder.button.cancel": "취소",
            "placeholder.button.confirm": "확인",
            "placeholder.help.history": "클립보드 기록에서 삽입",

            // Issue35: 스니펫 팝업
            "popup.search.placeholder": "스니펫 검색...",
            "popup.preview.empty": "미리보기 없음",
            "popup.create.button": "'%@' 생성",
            "popup.create.help": "Tab: 편집, Enter: 선택",
            "popup.empty.no_results": "결과 없음",

            // Issue35: 히스토리 검색바
            "history.search.placeholder": "클립보드 기록 검색...",
            "history.filter.all": "전체",
            "history.filter.images": "이미지",
            "history.filter.apps": "앱별 필터",

            // Issue35: 히스토리 뷰어 - 컨텍스트 메뉴
            "menu.copy": "복사",
            "menu.save_image": "이미지 저장",
            "menu.register": "스니펫으로 등록",
            "menu.delete": "삭제",

            // Issue35: 히스토리 뷰어 - 삭제 확인
            "alert.delete_items.title": "%d개 항목 삭제?",
            "alert.delete_items.message": "이 작업은 되돌릴 수 없습니다.",
            "alert.common.delete": "삭제",
            "alert.common.cancel": "취소",
            "alert.filtered_delete.title": "검색 결과와 일치하는 모든 항목 삭제?",
            "alert.filtered_delete.button": "%d개 항목 삭제",
            "alert.filtered_delete.message": "검색어 '%@'에 일치하는 %d개 항목을 영구 삭제합니다. 검색 결과와 동일한 항목이 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.",

            // Issue35: 히스토리 뷰어 - 푸터
            "viewer.footer.items": "%d개 항목",
            "viewer.footer.selected": "%d개 선택됨",
            "viewer.status.paused": "일시정지",
            "viewer.status.active": "활성",
            "viewer.help.resume": "클릭하여 클립보드 모니터링 재개",
            "viewer.help.pause": "클릭하여 클립보드 모니터링 일시정지",
            "viewer.help.shortcuts": "키보드 단축키",
            "viewer.help.show_shortcuts": "키보드 단축키 보기",
            "viewer.help.delete_matches": "검색 결과와 일치하는 모든 항목 삭제",
            "viewer.button.delete_matches": "일치 항목 삭제",
            "viewer.preview.empty": "미리보기 없음",

            // Issue35: 히스토리 뷰어 - 단축키 도움말
            "viewer.key.tab": "Tab",
            "viewer.key.enter": "Enter",
            "viewer.key.backspace": "Delete",
            "viewer.key.esc": "Esc",
            "viewer.action.preview_edit": "미리보기 / 편집",
            "viewer.action.copy_paste": "복사 & 붙여넣기",
            "viewer.action.quick_select": "빠른 선택",
            "viewer.action.delete": "항목 삭제",
            "viewer.action.register": "스니펫으로 등록",
            "viewer.action.toggle_pause": "일시정지 토글",
            "viewer.action.close": "닫기",
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

            // Issue35: プレースホルダー入力ウィンドウ
            "placeholder.window.title": "プレースホルダー入力",
            "placeholder.label.preview": "プレビュー",
            "placeholder.button.cancel": "キャンセル",
            "placeholder.button.confirm": "確認",
            "placeholder.help.history": "クリップボード履歴から挿入",

            // Issue35: スニペットポップアップ
            "popup.search.placeholder": "スニペット検索...",
            "popup.preview.empty": "プレビューなし",
            "popup.create.button": "'%@'を作成",
            "popup.create.help": "Tab: 編集、Enter: 選択",
            "popup.empty.no_results": "結果なし",

            // Issue35: 履歴検索バー
            "history.search.placeholder": "クリップボード履歴を検索...",
            "history.filter.all": "すべて",
            "history.filter.images": "画像",
            "history.filter.apps": "アプリ別フィルター",

            // Issue35: 履歴ビューア - コンテキストメニュー
            "menu.copy": "コピー",
            "menu.save_image": "画像を保存",
            "menu.register": "スニペットとして登録",
            "menu.delete": "削除",

            // Issue35: 履歴ビューア - 削除確認
            "alert.delete_items.title": "%d件を削除しますか？",
            "alert.delete_items.message": "この操作は元に戻せません。",
            "alert.common.delete": "削除",
            "alert.common.cancel": "キャンセル",
            "alert.filtered_delete.title": "検索結果に一致するすべての項目を削除しますか？",
            "alert.filtered_delete.button": "%d件を削除",
            "alert.filtered_delete.message": "'%@'に一致する%d件を完全に削除します。検索結果と同じ項目が削除されます。\nこの操作は元に戻せません。",

            // Issue35: 履歴ビューア - フッター
            "viewer.footer.items": "%d件",
            "viewer.footer.selected": "%d件選択中",
            "viewer.status.paused": "一時停止",
            "viewer.status.active": "アクティブ",
            "viewer.help.resume": "クリックしてクリップボード監視を再開",
            "viewer.help.pause": "クリックしてクリップボード監視を一時停止",
            "viewer.help.shortcuts": "キーボードショートカット",
            "viewer.help.show_shortcuts": "キーボードショートカットを表示",
            "viewer.help.delete_matches": "検索結果に一致するすべての項目を削除",
            "viewer.button.delete_matches": "一致項目を削除",
            "viewer.preview.empty": "プレビューなし",

            // Issue35: 履歴ビューア - ショートカットヘルプ
            "viewer.key.tab": "Tab",
            "viewer.key.enter": "Enter",
            "viewer.key.backspace": "Delete",
            "viewer.key.esc": "Esc",
            "viewer.action.preview_edit": "プレビュー / 編集",
            "viewer.action.copy_paste": "コピー＆ペースト",
            "viewer.action.quick_select": "クイック選択",
            "viewer.action.delete": "項目を削除",
            "viewer.action.register": "スニペットとして登録",
            "viewer.action.toggle_pause": "一時停止切替",
            "viewer.action.close": "閉じる",
        ],
    ]
}
