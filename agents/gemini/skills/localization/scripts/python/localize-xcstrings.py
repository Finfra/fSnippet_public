import json

import os

# Create path relative to this script: ../../../../../fSnippet/fSnippet/fSnippet/Resources/Localizable.xcstrings
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# Go up 5 levels from .agent/skills/localization/scripts/python
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "../../../../.."))
FILE_PATH = os.path.join(REPO_ROOT, "fSnippet/fSnippet/fSnippet/Resources/Localizable.xcstrings")

def get_translations_map():
    def t(en, ko, ja, zhS, zhT, de, es, fr):
        return {"en": en, "ko": ko, "ja": ja, "zh-Hans": zhS, "zh-Hant": zhT, "de": de, "es": es, "fr": fr}

    return {
        # Long Descriptions
        "settings.general.desc.popup_key": t("Shortcut combination to open snippet popup", "스니펫 검색창을 여는 글로벌 단축키입니다.", "スニペットポップアップを開くショートカット。", "打开片段弹窗的快捷键。", "開啟片段彈窗的快捷鍵。", "Tastenkombination zum Öffnen des Snippet-Popups.", "Atajo para abrir la ventana emergente de fragmentos.", "Raccourci pour ouvrir la fenêtre contextuelle des extraits."),
        "settings.general.desc.popup_rows": t("Sets the maximum number of snippet items to display in the popup window.", "팝업 창에 표시할 최대 스니펫 목록 개수를 설정합니다.", "ポップアップウィンドウに表示するスニペットの最大数を設定します。", "设置弹窗中显示的最大片段数。", "設定彈窗中顯示的最大片段數。", "Legt die maximale Anzahl der im Popup-Fenster angezeigten Snippet-Elemente fest.", "Establece el número máximo de fragmentos para mostrar en la ventana emergente.", "Définit le nombre maximum d'éléments d'extrait à afficher dans la fenêtre contextuelle."),
        "settings.general.desc.quick_select": t("Press number keys (1-9) in popup to instantly execute items.", "팝업에서 숫자키(1-9)를 눌러 항목을 즉시 실행합니다.", "ポップアップで数字キー（1-9）を押して項目を即座に実行します。", "在弹窗中按数字键 (1-9) 即时执行项目。", "在彈窗中按數字鍵 (1-9) 即時執行項目。", "Drücken Sie die Zifferntasten (1-9) im Popup, um Elemente sofort auszuführen.", "Presione las teclas numéricas (1-9) en la ventana emergente para ejecutar elementos instantáneamente.", "Appuyez sur les touches numériques (1-9) dans la fenêtre contextuelle pour exécuter instantanément les éléments."),
        
        # KeyLogger & Debug
        "KeyLogger": t("KeyLogger", "키로거", "キーロガー", "键盘记录器", "鍵盤記錄器", "KeyLogger", "KeyLogger", "Enregistreur de frappe"),
        "KeyLogger 메타데이터": t("KeyLogger Metadata", "KeyLogger 메타데이터", "KeyLogger メタデータ", "键盘记录器元数据", "鍵盤記錄器元數據", "KeyLogger-Metadaten", "Metadatos de KeyLogger", "Métadonnées de l'enregistreur de frappe"),
        "KeyLogger 모니터": t("KeyLogger Monitor", "KeyLogger 모니터", "KeyLogger モニター", "键盘记录器监视器", "鍵盤記錄器監視器", "KeyLogger-Monitor", "Monitor de KeyLogger", "Moniteur de l'enregistreur de frappe"),
        "KeyLogger 형식: %@": t("KeyLogger Format: %@", "KeyLogger 형식: %@", "KeyLogger 形式: %@", "键盘记录器格式: %@", "鍵盤記錄器格式: %@", "KeyLogger-Format: %@", "Formato de KeyLogger: %@", "Format de l'enregistreur de frappe : %@"),
        "📋 실제 트리거: '%@' 문자 입력 → KeyLogger 값으로 정확한 매칭": t("📋 Actual Trigger: Input '%@' → Exact match with KeyLogger value", "📋 실제 트리거: '%@' 문자 입력 → KeyLogger 값으로 정확한 매칭", "📋 実際のトリガー: 入力 '%@' → KeyLogger値と完全一致", "📋 实际触发: 输入 '%@' → 与键盘记录器值精确匹配", "📋 實際觸發: 輸入 '%@' → 與鍵盤記錄器值精確匹配", "📋 Tatsächlicher Auslöser: Eingabe '%@' → Exakte Übereinstimmung mit KeyLogger-Wert", "📋 Disparador real: Entrada '%@' → Coincidencia exacta con el valor de KeyLogger", "📋 Déclencheur réel : Entrée '%@' → Correspondance exacte avec la valeur de l'enregistreur de frappe"),
        
        # Formatted Strings
        "(실제 파일명: %@===%@.txt)": t("(Actual filename: %1$@===%2$@.txt)", "(실제 파일명: %1$@===%2$@.txt)", "(実際のファイル名: %1$@===%2$@.txt)", "(实际文件名: %1$@===%2$@.txt)", "(實際檔名: %1$@===%2$@.txt)", "(Tatsächlicher Dateiname: %1$@===%2$@.txt)", "(Nombre de archivo real: %1$@===%2$@.txt)", "(Nom de fichier réel : %1$@===%2$@.txt)"),
        "%@ and %lld more...": t("%1$@ and %2$lld more...", "%1$@ 외 %2$lld개...", "%1$@ と他 %2$lld 件...", "%1$@ 和其他 %2$lld 个...", "%1$@ 和其他 %2$lld 個...", "%1$@ und %2$lld weitere...", "%1$@ y %2$lld más...", "%1$@ et %2$lld de plus..."),
        
        # Advanced Labels
        "settings.advanced.label.buffer_size": t("Key Buffer Size:", "키 버퍼 크기:", "キーバッファサイズ:", "键缓冲区大小:", "鍵緩衝區大小:", "Tastenpuffergröße:", "Tamaño del búfer de teclas:", "Taille du tampon de touches :"),
        "settings.advanced.label.cache_size": t("Search Cache Size:", "검색 캐시 크기:", "検索キャッシュサイズ:", "搜索缓存大小:", "搜尋快取大小:", "Suchcache-Größe:", "Tamaño de caché de búsqueda:", "Taille du cache de recherche :"),
        "settings.advanced.label.force_input": t("Force Input Source:", "입력 소스 강제:", "入力ソースを強制:", "强制输入源:", "強制輸入來源:", "Eingabequelle erzwingen:", "Forzar fuente de entrada:", "Forcer la source d'entrée :"),
        "settings.advanced.label.global_excluded": t("Global Excluded Files:", "전역 제외 파일:", "グローバル除外ファイル:", "全局排除文件:", "全域排除檔案:", "Global ausgeschlossene Dateien:", "Archivos excluidos globalmente:", "Fichiers exclus globalement :"),
        "settings.advanced.label.snippet_count": t("Loaded Snippets:", "로드된 스니펫:", "ロードされたスニペット:", "已加载片段:", "已載入片段:", "Geladene Snippets:", "Fragmentos cargados:", "Extraits chargés :"),
        "settings.advanced.label.stats_retention": t("Stats Retention:", "통계 보존 기간:", "統計保持期間:", "统计保留:", "統計保留:", "Statistikaufbewahrung:", "Retención de estadísticas:", "Rétention des statistiques :"),

        # Clipboard Settings
        "settings.clipboard.header.title": t("Clipboard History", "클립보드 히스토리", "クリップボード履歴", "剪贴板历史", "剪貼簿歷史", "Zwischenablage-Verlauf", "Historial del portapapeles", "Historique du presse-papiers"),
        "settings.clipboard.header.desc": t("Manage and reuse clipboard history of text and images.", "텍스트와 이미지의 복사 이력을 관리하고 재사용합니다.", "テキストと画像のクリップボード履歴を管理して再利用します。", "管理和重用文本和图像的剪贴板历史记录。", "管理和重複使用文字和圖片的剪貼簿歷史記錄。", "Verwalten und verwenden Sie den Zwischenablage-Verlauf von Text und Bildern wieder.", "Administre y reutilice el historial del portapapeles de texto e imágenes.", "Gérez et réutilisez l'historique du presse-papiers du texte et des images."),
    }

def apply_translations():
    try:
        with open(FILE_PATH, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Error loading JSON: {e}")
        return

    strings = data.get("strings", {})
    t_map = get_translations_map()
    updated_count = 0
    target_langs = ["de", "es", "fr", "ja", "zh-Hans", "zh-Hant", "ko", "en"]
    
    symbols = set(["+", "-", ":", "•", "␣", "(%@)", "• %@", "%lld", "%@", "KeyLogger"]) # Add more if found
    
    for key, entry in strings.items():
        if not key: continue
        localizations = entry.get("localizations", {})
        
        # 1. Map
        if key in t_map:
            mapping = t_map[key]
            for lang in target_langs:
                if lang in mapping:
                    state = localizations.get(lang, {}).get("stringUnit", {}).get("state", "new")
                    val = localizations.get(lang, {}).get("stringUnit", {}).get("value", "")
                    if state == "new" or not val:
                        if lang not in localizations: localizations[lang] = {"stringUnit": {}}
                        localizations[lang]["stringUnit"]["state"] = "translated"
                        localizations[lang]["stringUnit"]["value"] = mapping[lang]
                        updated_count += 1
                        
        # 2. Heuristic Copies (Symbols / Punctuation Start)
        # If key starts with special char and looks like "-> %@" copy it?
        # Be careful not to copy English text to Japanese.
        # Safe symbols: •, →, +, -, :, 1-9, %
        safe_start = ("•", "→", "+", "-", ":", "⚠️", "💡", "📋", "❌", "✅") 
        if key.startswith(safe_start) or key in symbols:
            # Check if it contains letters?
            # "⚠️ Warning" -> should be translated.
            # "→ %@" -> Copy.
            # Only copy if key is mostly symbols/vars.
            has_letters = any(c.isalpha() for c in key)
            if not has_letters or key.startswith("→"):
                 for lang in target_langs:
                    state = localizations.get(lang, {}).get("stringUnit", {}).get("state", "new")
                    val = localizations.get(lang, {}).get("stringUnit", {}).get("value", "")
                    if state == "new" or not val:
                         if lang not in localizations: localizations[lang] = {"stringUnit": {}}
                         localizations[lang]["stringUnit"]["state"] = "translated"
                         localizations[lang]["stringUnit"]["value"] = key
                         updated_count += 1

    with open(FILE_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        
    print(f"Updated {updated_count} translation units.")

if __name__ == "__main__":
    apply_translations()
