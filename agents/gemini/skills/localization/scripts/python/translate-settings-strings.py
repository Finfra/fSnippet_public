#!/usr/bin/env python3
"""
Settings.strings 파일 번역 스크립트
"""
import os
import re

RESOURCES_DIR = 'fSnippet/fSnippet/Resources'

# Settings.strings 전용 번역 사전
SETTINGS_TRANSLATIONS = {
    # === Advanced Settings ===
    "settings.advanced.alert.clear_stats.message": {
        "ko": "⚠️ 모든 스니펫 사용 내역 및 통계 데이터가 영구적으로 삭제됩니다. 계속하시겠습니까?",
        "en": "⚠️ All snippet usage history and statistics will be permanently deleted. Continue?",
        "ja": "⚠️ すべてのスニペット使用履歴と統計データが完全に削除されます。続行しますか？",
        "de": "⚠️ Alle Snippet-Nutzungsdaten und Statistiken werden dauerhaft gelöscht. Fortfahren?",
        "es": "⚠️ Todo el historial de uso y estadísticas se eliminarán permanentemente. ¿Continuar?",
        "fr": "⚠️ Tout l'historique d'utilisation et les statistiques seront définitivement supprimés. Continuer ?",
        "zh-Hans": "⚠️ 所有片段使用历史和统计数据将被永久删除。继续？",
        "zh-Hant": "⚠️ 所有片段使用歷史和統計數據將被永久刪除。繼續？"
    },
    "settings.advanced.alert.clear_stats.title": {
        "ko": "통계 데이터 초기화", "en": "Clear Statistics",
        "ja": "統計データを初期化", "de": "Statistiken löschen",
        "es": "Borrar estadísticas", "fr": "Effacer les statistiques",
        "zh-Hans": "清除统计数据", "zh-Hant": "清除統計數據"
    },
    "settings.advanced.alert.full_reset.message": {
        "ko": "⚠️ 경고: 이 작업은 되돌릴 수 없습니다.\n\n앱 설정, 스니펫 파일, 로그 등 모든 데이터가 삭제되고 앱이 초기 상태로 재설정됩니다.\n\n정말로 진행하시겠습니까?",
        "en": "⚠️ WARNING: This action cannot be undone.\n\nAll app settings, snippet files, and logs will be deleted and the app will be reset to initial state.\n\nAre you sure you want to proceed?",
        "ja": "⚠️ 警告：この操作は取り消せません。\n\nすべてのアプリ設定、スニペットファイル、ログが削除され、アプリが初期状態にリセットされます。\n\n本当に続行しますか？",
        "de": "⚠️ WARNUNG: Diese Aktion kann nicht rückgängig gemacht werden.\n\nAlle App-Einstellungen, Snippet-Dateien und Protokolle werden gelöscht und die App wird zurückgesetzt.\n\nMöchten Sie wirklich fortfahren?",
        "es": "⚠️ ADVERTENCIA: Esta acción no se puede deshacer.\n\nTodos los ajustes, archivos de fragmentos y registros se eliminarán.\n\n¿Está seguro de que desea continuar?",
        "fr": "⚠️ ATTENTION : Cette action est irréversible.\n\nTous les paramètres, fichiers d'extraits et journaux seront supprimés.\n\nÊtes-vous sûr de vouloir continuer ?",
        "zh-Hans": "⚠️ 警告：此操作无法撤销。\n\n所有应用设置、片段文件和日志都将被删除，应用将重置为初始状态。\n\n确定要继续吗？",
        "zh-Hant": "⚠️ 警告：此操作無法復原。\n\n所有應用程式設定、片段檔案和日誌都將被刪除，應用程式將重置為初始狀態。\n\n確定要繼續嗎？"
    },
    "settings.advanced.alert.full_reset.title": {
        "ko": "모든 데이터 완전 초기화", "en": "Factory Reset",
        "ja": "完全リセット", "de": "Werkseinstellungen",
        "es": "Restablecer de fábrica", "fr": "Réinitialisation d'usine",
        "zh-Hans": "恢复出厂设置", "zh-Hant": "恢復原廠設定"
    },
    "settings.advanced.alert.log_level_denied.message": {
        "ko": "디버그 로그를 활성화해야 로그 레벨을 변경할 수 있습니다.",
        "en": "Debug logging must be enabled to change the log level.",
        "ja": "ログレベルを変更するにはデバッグログを有効にする必要があります。",
        "de": "Debug-Protokollierung muss aktiviert sein, um die Protokollstufe zu ändern.",
        "es": "El registro de depuración debe estar habilitado para cambiar el nivel de registro.",
        "fr": "La journalisation de débogage doit être activée pour modifier le niveau de journal.",
        "zh-Hans": "必须启用调试日志才能更改日志级别。",
        "zh-Hant": "必須啟用除錯日誌才能更改日誌級別。"
    },
    "settings.advanced.alert.log_level_denied.title": {
        "ko": "변경 불가", "en": "Cannot Change",
        "ja": "変更不可", "de": "Änderung nicht möglich",
        "es": "No se puede cambiar", "fr": "Impossible de modifier",
        "zh-Hans": "无法更改", "zh-Hant": "無法更改"
    },
    "settings.advanced.alert.reset_settings_only.message": {
        "ko": "앱 설정이 초기화되지만, 스니펫 파일은 유지됩니다.\n\n앱이 재시작됩니다.",
        "en": "App settings will be reset, but snippet files will be kept.\n\nThe app will restart.",
        "ja": "アプリ設定は初期化されますが、スニペットファイルは保持されます。\n\nアプリが再起動します。",
        "de": "App-Einstellungen werden zurückgesetzt, aber Snippet-Dateien bleiben erhalten.\n\nDie App wird neu gestartet.",
        "es": "Los ajustes se restablecerán, pero los archivos de fragmentos se conservarán.\n\nLa aplicación se reiniciará.",
        "fr": "Les paramètres seront réinitialisés, mais les fichiers d'extraits seront conservés.\n\nL'application redémarrera.",
        "zh-Hans": "应用设置将被重置，但片段文件将保留。\n\n应用将重新启动。",
        "zh-Hant": "應用程式設定將被重置，但片段檔案將保留。\n\n應用程式將重新啟動。"
    },
    "settings.advanced.alert.reset_settings_only.title": {
        "ko": "설정만 초기화", "en": "Reset Settings Only",
        "ja": "設定のみリセット", "de": "Nur Einstellungen zurücksetzen",
        "es": "Restablecer solo ajustes", "fr": "Réinitialiser les paramètres uniquement",
        "zh-Hans": "仅重置设置", "zh-Hant": "僅重置設定"
    },
    "settings.advanced.button.clear_stats": {
        "ko": "통계 데이터 초기화", "en": "Clear Statistics",
        "ja": "統計を初期化", "de": "Statistiken löschen",
        "es": "Borrar estadísticas", "fr": "Effacer les statistiques",
        "zh-Hans": "清除统计", "zh-Hant": "清除統計"
    },
    "settings.advanced.button.clear_stats_execute": {
        "ko": "통계 삭제", "en": "Clear Stats",
        "ja": "統計を削除", "de": "Statistiken löschen",
        "es": "Borrar estadísticas", "fr": "Effacer les stats",
        "zh-Hans": "清除统计", "zh-Hant": "清除統計"
    },
    "settings.advanced.button.full_reset_execute": {
        "ko": "완전 초기화 실행", "en": "Execute Full Reset",
        "ja": "完全リセット実行", "de": "Vollständiges Zurücksetzen",
        "es": "Ejecutar restablecimiento completo", "fr": "Exécuter la réinitialisation complète",
        "zh-Hans": "执行完全重置", "zh-Hant": "執行完全重置"
    },
    "settings.advanced.button.hard_reset": {
        "ko": "완전 초기화\n(스니펫 포함)", "en": "Full Reset\n(Include Snippets)",
        "ja": "完全リセット\n(スニペット含む)", "de": "Vollständiges Zurücksetzen\n(inkl. Snippets)",
        "es": "Restablecimiento completo\n(Incluir fragmentos)", "fr": "Réinitialisation complète\n(Inclure les extraits)",
        "zh-Hans": "完全重置\n(包括片段)", "zh-Hant": "完全重置\n(包括片段)"
    },
    "settings.advanced.button.import": {
        "ko": "가져오기", "en": "Import",
        "ja": "インポート", "de": "Importieren",
        "es": "Importar", "fr": "Importer",
        "zh-Hans": "导入", "zh-Hant": "匯入",
        "ar": "استيراد", "hi": "आयात"
    },
    "settings.advanced.button.reset_execute": {
        "ko": "초기화 실행", "en": "Reset",
        "ja": "リセット", "de": "Zurücksetzen",
        "es": "Restablecer", "fr": "Réinitialiser",
        "zh-Hans": "重置", "zh-Hant": "重置",
        "ar": "إعادة تعيين", "hi": "रीसेट"
    },
    "settings.advanced.button.soft_reset": {
        "ko": "설정만 초기화\n(스니펫 유지)", "en": "Reset Settings Only\n(Keep Snippets)",
        "ja": "設定のみリセット\n(スニペット保持)", "de": "Nur Einstellungen zurücksetzen\n(Snippets behalten)",
        "es": "Restablecer solo ajustes\n(Conservar fragmentos)", "fr": "Réinitialiser les paramètres uniquement\n(Conserver les extraits)",
        "zh-Hans": "仅重置设置\n(保留片段)", "zh-Hant": "僅重置設定\n(保留片段)"
    },
    "settings.advanced.danger.warning": {
        "ko": "주의: 모든 데이터가 삭제됩니다.", "en": "Warning: All data will be deleted.",
        "ja": "警告：すべてのデータが削除されます。", "de": "Warnung: Alle Daten werden gelöscht.",
        "es": "Advertencia: Todos los datos se eliminarán.", "fr": "Attention : Toutes les données seront supprimées.",
        "zh-Hans": "警告：所有数据将被删除。", "zh-Hant": "警告：所有數據將被刪除。",
        "ar": "تحذير: سيتم حذف جميع البيانات.", "hi": "चेतावनी: सारा डेटा हटा दिया जाएगा।"
    },
    "settings.advanced.import.desc": {
        "ko": "Alfred 스니펫 가져오기", "en": "Import Alfred Snippets",
        "ja": "Alfred スニペットをインポート", "de": "Alfred-Snippets importieren",
        "es": "Importar fragmentos de Alfred", "fr": "Importer les extraits Alfred",
        "zh-Hans": "导入Alfred片段", "zh-Hant": "匯入Alfred片段"
    },
    "settings.advanced.import_alfred.failure": {
        "ko": "❌ Alfred 스니펫 가져오기 실패\n%@", "en": "❌ Failed to import Alfred snippets\n%@",
        "ja": "❌ Alfred スニペットのインポートに失敗\n%@", "de": "❌ Import der Alfred-Snippets fehlgeschlagen\n%@",
        "es": "❌ Error al importar fragmentos de Alfred\n%@", "fr": "❌ Échec de l'importation des extraits Alfred\n%@",
        "zh-Hans": "❌ 导入Alfred片段失败\n%@", "zh-Hant": "❌ 匯入Alfred片段失敗\n%@"
    },
    "settings.advanced.import_alfred.start": {
        "ko": "Alfred 스니펫 가져오기 시작...", "en": "Importing Alfred snippets...",
        "ja": "Alfred スニペットをインポート中...", "de": "Alfred-Snippets werden importiert...",
        "es": "Importando fragmentos de Alfred...", "fr": "Importation des extraits Alfred...",
        "zh-Hans": "正在导入Alfred片段...", "zh-Hant": "正在匯入Alfred片段..."
    },
    "settings.advanced.import_alfred.success": {
        "ko": "✅ 가져오기 완료: 컬렉션 %1$lld개, 스니펫 %2$lld개",
        "en": "✅ Import complete: %1$lld collections, %2$lld snippets",
        "ja": "✅ インポート完了：コレクション%1$lld個、スニペット%2$lld個",
        "de": "✅ Import abgeschlossen: %1$lld Sammlungen, %2$lld Snippets",
        "es": "✅ Importación completa: %1$lld colecciones, %2$lld fragmentos",
        "fr": "✅ Importation terminée : %1$lld collections, %2$lld extraits",
        "zh-Hans": "✅ 导入完成：%1$lld个集合，%2$lld个片段",
        "zh-Hant": "✅ 匯入完成：%1$lld個集合，%2$lld個片段"
    },
    "settings.advanced.input.no_change": {
        "ko": "변경 안함", "en": "No Change",
        "ja": "変更なし", "de": "Keine Änderung",
        "es": "Sin cambios", "fr": "Aucun changement",
        "zh-Hans": "无更改", "zh-Hant": "無更改",
        "ar": "لا تغيير", "hi": "कोई बदलाव नहीं"
    },
    "settings.advanced.label.buffer_size": {
        "ko": "키 버퍼 크기:", "en": "Key Buffer Size:",
        "ja": "キーバッファサイズ：", "de": "Tastenpuffergröße:",
        "es": "Tamaño del búfer de teclas:", "fr": "Taille du tampon de touches :",
        "zh-Hans": "键缓冲区大小：", "zh-Hant": "鍵緩衝區大小："
    },
    "settings.advanced.label.cache_size": {
        "ko": "검색 캐시 크기:", "en": "Search Cache Size:",
        "ja": "検索キャッシュサイズ：", "de": "Suchcache-Größe:",
        "es": "Tamaño de caché de búsqueda:", "fr": "Taille du cache de recherche :",
        "zh-Hans": "搜索缓存大小：", "zh-Hant": "搜尋快取大小："
    },
    "settings.advanced.label.force_input": {
        "ko": "검색창 입력 언어 강제:", "en": "Force Search Input Language:",
        "ja": "検索入力言語を強制：", "de": "Eingabesprache erzwingen:",
        "es": "Forzar idioma de entrada de búsqueda:", "fr": "Forcer la langue de saisie de recherche :",
        "zh-Hans": "强制搜索输入语言：", "zh-Hant": "強制搜尋輸入語言："
    },
    "settings.advanced.label.global_excluded": {
        "ko": "전역 제외 파일:", "en": "Global Excluded Files:",
        "ja": "グローバル除外ファイル：", "de": "Global ausgeschlossene Dateien:",
        "es": "Archivos excluidos globalmente:", "fr": "Fichiers exclus globalement :",
        "zh-Hans": "全局排除文件：", "zh-Hant": "全域排除檔案："
    },
    "settings.advanced.label.log_level": {
        "ko": "로그 레벨:", "en": "Log Level:",
        "ja": "ログレベル：", "de": "Protokollstufe:",
        "es": "Nivel de registro:", "fr": "Niveau de journal :",
        "zh-Hans": "日志级别：", "zh-Hant": "日誌級別："
    },
    "settings.advanced.label.snippet_count": {
        "ko": "로드된 Snippet 수:", "en": "Loaded Snippets:",
        "ja": "読み込まれたスニペット数：", "de": "Geladene Snippets:",
        "es": "Fragmentos cargados:", "fr": "Extraits chargés :",
        "zh-Hans": "已加载的片段数：", "zh-Hant": "已載入的片段數："
    },
    "settings.advanced.label.stats_retention": {
        "ko": "통계 저장 기간:", "en": "Statistics Retention:",
        "ja": "統計保持期間：", "de": "Statistik-Aufbewahrung:",
        "es": "Retención de estadísticas:", "fr": "Conservation des statistiques :",
        "zh-Hans": "统计保留期：", "zh-Hant": "統計保留期："
    },
    "settings.advanced.label.version": {
        "ko": "앱 버전:", "en": "App Version:",
        "ja": "アプリバージョン：", "de": "App-Version:",
        "es": "Versión de la app:", "fr": "Version de l'app :",
        "zh-Hans": "应用版本：", "zh-Hant": "應用程式版本："
    },
    "settings.advanced.picker.log_level": {
        "ko": "로그 레벨", "en": "Log Level",
        "ja": "ログレベル", "de": "Protokollstufe",
        "es": "Nivel de registro", "fr": "Niveau de journal",
        "zh-Hans": "日志级别", "zh-Hant": "日誌級別"
    },
    "settings.advanced.retention.12months": {
        "ko": "12개월", "en": "12 Months",
        "ja": "12ヶ月", "de": "12 Monate",
        "es": "12 meses", "fr": "12 mois",
        "zh-Hans": "12个月", "zh-Hant": "12個月"
    },
    "settings.advanced.retention.1month": {
        "ko": "1개월", "en": "1 Month",
        "ja": "1ヶ月", "de": "1 Monat",
        "es": "1 mes", "fr": "1 mois",
        "zh-Hans": "1个月", "zh-Hant": "1個月"
    },
    "settings.advanced.retention.3months": {
        "ko": "3개월", "en": "3 Months",
        "ja": "3ヶ月", "de": "3 Monate",
        "es": "3 meses", "fr": "3 mois",
        "zh-Hans": "3个月", "zh-Hant": "3個月"
    },
    "settings.advanced.retention.6months": {
        "ko": "6개월", "en": "6 Months",
        "ja": "6ヶ月", "de": "6 Monate",
        "es": "6 meses", "fr": "6 mois",
        "zh-Hans": "6个月", "zh-Hant": "6個月"
    },
    "settings.advanced.retention.infinite": {
        "ko": "무한대", "en": "Infinite",
        "ja": "無制限", "de": "Unbegrenzt",
        "es": "Infinito", "fr": "Infini",
        "zh-Hans": "无限", "zh-Hant": "無限"
    },
    "settings.advanced.section.danger": {
        "ko": "위험 구역", "en": "Danger Zone",
        "ja": "危険ゾーン", "de": "Gefahrenzone",
        "es": "Zona de peligro", "fr": "Zone de danger",
        "zh-Hans": "危险区域", "zh-Hant": "危險區域"
    },
    "settings.advanced.section.debug": {
        "ko": "디버그", "en": "Debug",
        "ja": "デバッグ", "de": "Debug",
        "es": "Depuración", "fr": "Débogage",
        "zh-Hans": "调试", "zh-Hant": "除錯",
        "ar": "تصحيح", "hi": "डिबग"
    },
    "settings.advanced.section.files": {
        "ko": "파일 관리", "en": "File Management",
        "ja": "ファイル管理", "de": "Dateiverwaltung",
        "es": "Gestión de archivos", "fr": "Gestion des fichiers",
        "zh-Hans": "文件管理", "zh-Hant": "檔案管理"
    },
    "settings.advanced.section.import": {
        "ko": "Alfred Import", "en": "Alfred Import",
        "ja": "Alfred インポート", "de": "Alfred-Import",
        "es": "Importar Alfred", "fr": "Import Alfred",
        "zh-Hans": "Alfred导入", "zh-Hant": "Alfred匯入"
    },
    "settings.advanced.section.info": {
        "ko": "정보", "en": "Info",
        "ja": "情報", "de": "Info",
        "es": "Información", "fr": "Info",
        "zh-Hans": "信息", "zh-Hant": "資訊"
    },
    "settings.advanced.section.input": {
        "ko": "입력 설정", "en": "Input Settings",
        "ja": "入力設定", "de": "Eingabeeinstellungen",
        "es": "Ajustes de entrada", "fr": "Paramètres de saisie",
        "zh-Hans": "输入设置", "zh-Hant": "輸入設定"
    },
    "settings.advanced.section.performance": {
        "ko": "성능", "en": "Performance",
        "ja": "パフォーマンス", "de": "Leistung",
        "es": "Rendimiento", "fr": "Performance",
        "zh-Hans": "性能", "zh-Hant": "效能"
    },
    "settings.advanced.toggle.debug_log": {
        "ko": "디버그 로그", "en": "Debug Logging",
        "ja": "デバッグログ", "de": "Debug-Protokollierung",
        "es": "Registro de depuración", "fr": "Journalisation de débogage",
        "zh-Hans": "调试日志", "zh-Hant": "除錯日誌"
    },
    "settings.advanced.toggle.perf_monitor": {
        "ko": "성능 모니터링", "en": "Performance Monitoring",
        "ja": "パフォーマンス監視", "de": "Leistungsüberwachung",
        "es": "Monitoreo de rendimiento", "fr": "Surveillance des performances",
        "zh-Hans": "性能监控", "zh-Hant": "效能監控"
    },

    # === Clipboard/History Settings ===
    "settings.clipboard.button.clear_all": {
        "ko": "전체 삭제", "en": "Clear All",
        "ja": "すべて削除", "de": "Alle löschen",
        "es": "Borrar todo", "fr": "Tout effacer",
        "zh-Hans": "全部清除", "zh-Hant": "全部清除",
        "ar": "مسح الكل", "hi": "सब साफ़ करें"
    },
    "settings.clipboard.button.delete_all": {
        "ko": "전체 삭제", "en": "Delete All",
        "ja": "すべて削除", "de": "Alle löschen",
        "es": "Eliminar todo", "fr": "Tout supprimer",
        "zh-Hans": "全部删除", "zh-Hant": "全部刪除",
        "ar": "حذف الكل", "hi": "सभी हटाएं"
    },
    "settings.clipboard.desc.clear_data": {
        "ko": "통계 및 히스토리 데이터 등 모든 수집된 정보를 영구적으로 삭제합니다.",
        "en": "Permanently delete all collected data including statistics and history.",
        "ja": "統計と履歴を含むすべての収集データを完全に削除します。",
        "de": "Alle gesammelten Daten einschließlich Statistiken und Verlauf dauerhaft löschen.",
        "es": "Eliminar permanentemente todos los datos recopilados, incluyendo estadísticas e historial.",
        "fr": "Supprimer définitivement toutes les données collectées, y compris les statistiques et l'historique.",
        "zh-Hans": "永久删除所有收集的数据，包括统计和历史记录。",
        "zh-Hant": "永久刪除所有收集的數據，包括統計和歷史記錄。",
        "ar": "حذف جميع البيانات المجمعة بما في ذلك الإحصائيات والسجل بشكل دائم.",
        "hi": "सांख्यिकी और इतिहास सहित सभी एकत्र किए गए डेटा को स्थायी रूप से हटाएं।"
    },
    "settings.clipboard.header.desc": {
        "ko": "복사된 텍스트와 이미지의 이력을 관리하고 다시 사용합니다.",
        "en": "Manage and reuse clipboard history of text and images.",
        "ja": "コピーしたテキストと画像の履歴を管理し、再利用します。",
        "de": "Verwalten und wiederverwenden Sie den Verlauf von kopiertem Text und Bildern.",
        "es": "Gestione y reutilice el historial del portapapeles de texto e imágenes.",
        "fr": "Gérez et réutilisez l'historique du presse-papiers de texte et d'images.",
        "zh-Hans": "管理和重用文本和图像的剪贴板历史。",
        "zh-Hant": "管理和重用文字和圖片的剪貼簿歷史。"
    },
    "settings.clipboard.header.title": {
        "ko": "클립보드 히스토리", "en": "Clipboard History",
        "ja": "クリップボード履歴", "de": "Zwischenablage-Verlauf",
        "es": "Historial del portapapeles", "fr": "Historique du presse-papiers",
        "zh-Hans": "剪贴板历史", "zh-Hant": "剪貼簿歷史"
    },
    "settings.clipboard.label.clear_data": {
        "ko": "통계 및 히스토리 데이터 삭제", "en": "Clear History & Stats",
        "ja": "履歴と統計を削除", "de": "Verlauf & Statistiken löschen",
        "es": "Borrar historial y estadísticas", "fr": "Effacer l'historique et les statistiques",
        "zh-Hans": "清除历史和统计", "zh-Hant": "清除歷史和統計",
        "ar": "مسح السجل والإحصائيات", "hi": "इतिहास और आँकड़े साफ़ करें"
    },
    "settings.clipboard.label.clear_data.desc": {
        "ko": "저장된 모든 클립보드 이력과 사용 통계를 즉시 초기화합니다.",
        "en": "Immediately clear all stored clipboard history and usage statistics.",
        "ja": "保存されているすべてのクリップボード履歴と使用統計を即座に初期化します。",
        "de": "Alle gespeicherten Verlaufsdaten und Nutzungsstatistiken sofort löschen.",
        "es": "Borrar inmediatamente todo el historial y estadísticas de uso almacenados.",
        "fr": "Effacer immédiatement tout l'historique et les statistiques d'utilisation stockés.",
        "zh-Hans": "立即清除所有存储的剪贴板历史和使用统计。",
        "zh-Hant": "立即清除所有儲存的剪貼簿歷史和使用統計。"
    },
    "settings.clipboard.label.pause": {
        "ko": "수집 일시 중단", "en": "Pause Collection",
        "ja": "収集を一時停止", "de": "Erfassung pausieren",
        "es": "Pausar recopilación", "fr": "Suspendre la collecte",
        "zh-Hans": "暂停收集", "zh-Hant": "暂停收集",
        "ar": "إيقاف المجموعة مؤقتًا", "hi": "संग्रह रोकें"
    },
    "settings.clipboard.label.register_snippet": {
        "ko": "스니펫으로 등록", "en": "Register as Snippet",
        "ja": "スニペットとして登録", "de": "Als Snippet registrieren",
        "es": "Registrar como fragmento", "fr": "Enregistrer comme extrait",
        "zh-Hans": "注册为片段", "zh-Hant": "註冊為片段",
        "ar": "تسجيل كمقتطف", "hi": "स्निपेट के रूप में पंजीकृत करें"
    },
    "settings.clipboard.label.retention": {
        "ko": "보관:", "en": "Keep:",
        "ja": "保持：", "de": "Behalten:",
        "es": "Conservar:", "fr": "Conserver :",
        "zh-Hans": "保留：", "zh-Hant": "保留："
    },
    "settings.clipboard.label.toggle_preview": {
        "ko": "미리보기 전환", "en": "Toggle Preview",
        "ja": "プレビューを切り替え", "de": "Vorschau umschalten",
        "es": "Alternar vista previa", "fr": "Basculer l'aperçu",
        "zh-Hans": "切换预览", "zh-Hant": "切換預覽",
        "ar": "تبديل المعاينة", "hi": "पूर्वावलोकन टॉगल करें"
    },
    "settings.clipboard.label.viewer_hotkey": {
        "ko": "뷰어 단축키", "en": "Viewer Hotkey",
        "ja": "ビューアホットキー", "de": "Viewer-Hotkey",
        "es": "Tecla de acceso del visor", "fr": "Raccourci du visualiseur",
        "zh-Hans": "查看器热键", "zh-Hant": "檢視器快捷鍵"
    },
    "settings.clipboard.section.data": {
        "ko": "데이터 관리", "en": "Data Management",
        "ja": "データ管理", "de": "Datenverwaltung",
        "es": "Gestión de datos", "fr": "Gestion des données",
        "zh-Hans": "数据管理", "zh-Hant": "數據管理"
    },
    "settings.clipboard.section.filter": {
        "ko": "호출/필터", "en": "Hotkeys/Filters",
        "ja": "呼び出し/フィルター", "de": "Hotkeys/Filter",
        "es": "Atajos/Filtros", "fr": "Raccourcis/Filtres",
        "zh-Hans": "快捷键/过滤器", "zh-Hant": "快捷鍵/篩選器"
    },
    "settings.clipboard.section.retention": {
        "ko": "수집 데이터 보존 제한", "en": "Data Retention Limits",
        "ja": "データ保持制限", "de": "Datenaufbewahrungslimits",
        "es": "Límites de retención de datos", "fr": "Limites de conservation des données",
        "zh-Hans": "数据保留限制", "zh-Hant": "數據保留限制"
    },
    "settings.clipboard.section.viewer": {
        "ko": "히스토리 뷰어", "en": "History Viewer",
        "ja": "履歴ビューア", "de": "Verlaufsanzeige",
        "es": "Visor de historial", "fr": "Visualiseur d'historique",
        "zh-Hans": "历史查看器", "zh-Hant": "歷史檢視器",
        "ar": "عارض السجل", "hi": "इतिहास दर्शक"
    },
    "settings.clipboard.toggle.filelist": {
        "ko": "파일 목록 (File Lists)", "en": "File Lists",
        "ja": "ファイルリスト", "de": "Dateilisten",
        "es": "Listas de archivos", "fr": "Listes de fichiers",
        "zh-Hans": "文件列表", "zh-Hant": "檔案清單"
    },
    "settings.clipboard.toggle.ignore_filelists": {
        "ko": "검색 시 파일 목록 제외", "en": "Exclude File Lists from Search",
        "ja": "検索からファイルリストを除外", "de": "Dateilisten von Suche ausschließen",
        "es": "Excluir listas de archivos de la búsqueda", "fr": "Exclure les listes de fichiers de la recherche",
        "zh-Hans": "搜索时排除文件列表", "zh-Hant": "搜尋時排除檔案清單"
    },
    "settings.clipboard.toggle.ignore_images": {
        "ko": "검색 시 이미지 제외", "en": "Exclude Images from Search",
        "ja": "検索から画像を除外", "de": "Bilder von Suche ausschließen",
        "es": "Excluir imágenes de la búsqueda", "fr": "Exclure les images de la recherche",
        "zh-Hans": "搜索时排除图片", "zh-Hant": "搜尋時排除圖片"
    },
    "settings.clipboard.toggle.image": {
        "ko": "이미지 (Images)", "en": "Images",
        "ja": "画像", "de": "Bilder",
        "es": "Imágenes", "fr": "Images",
        "zh-Hans": "图片", "zh-Hant": "圖片"
    },
    "settings.clipboard.toggle.image_floating": {
        "ko": "이미지 상세 창 항상 위", "en": "Image Detail Window Always on Top",
        "ja": "画像詳細ウィンドウを常に最前面に", "de": "Bilddetailfenster immer im Vordergrund",
        "es": "Ventana de detalle de imagen siempre arriba", "fr": "Fenêtre de détail d'image toujours au premier plan",
        "zh-Hans": "图片详情窗口总在最前", "zh-Hant": "圖片詳情視窗總在最前"
    },
    "settings.clipboard.toggle.move_top": {
        "ko": "중복 항목 최상단으로 이동", "en": "Move Duplicates to Top",
        "ja": "重複を最上部に移動", "de": "Duplikate nach oben verschieben",
        "es": "Mover duplicados arriba", "fr": "Déplacer les doublons en haut",
        "zh-Hans": "将重复项移至顶部", "zh-Hant": "將重複項移至頂部"
    },
    "settings.clipboard.toggle.preview_window": {
        "ko": "미리보기 창 표시", "en": "Show Preview Window",
        "ja": "プレビューウィンドウを表示", "de": "Vorschaufenster anzeigen",
        "es": "Mostrar ventana de vista previa", "fr": "Afficher la fenêtre d'aperçu",
        "zh-Hans": "显示预览窗口", "zh-Hant": "顯示預覽視窗"
    },
    "settings.clipboard.toggle.statusbar": {
        "ko": "뷰어 상태바 표시", "en": "Show Viewer Status Bar",
        "ja": "ビューアステータスバーを表示", "de": "Viewer-Statusleiste anzeigen",
        "es": "Mostrar barra de estado del visor", "fr": "Afficher la barre d'état du visualiseur",
        "zh-Hans": "显示查看器状态栏", "zh-Hant": "顯示檢視器狀態列"
    },
    "settings.clipboard.toggle.text": {
        "ko": "텍스트 (Plain Text)", "en": "Text (Plain Text)",
        "ja": "テキスト（プレーンテキスト）", "de": "Text (Klartext)",
        "es": "Texto (Texto sin formato)", "fr": "Texte (Texte brut)",
        "zh-Hans": "文本（纯文本）", "zh-Hant": "文字（純文字）"
    },
    "settings.clipboard.unit.days": {
        "ko": "일", "en": "days",
        "ja": "日", "de": "Tage",
        "es": "días", "fr": "jours",
        "zh-Hans": "天", "zh-Hant": "天"
    },

    # === Folder Settings ===
    "settings.folder.button.add": {
        "ko": "추가", "en": "Add",
        "ja": "追加", "de": "Hinzufügen",
        "es": "Añadir", "fr": "Ajouter",
        "zh-Hans": "添加", "zh-Hant": "新增",
        "ar": "إضافة", "hi": "जोड़ें"
    },
    "settings.folder.button.delete": {
        "ko": "삭제", "en": "Delete",
        "ja": "削除", "de": "Löschen",
        "es": "Eliminar", "fr": "Supprimer",
        "zh-Hans": "删除", "zh-Hant": "刪除",
        "ar": "حذف", "hi": "हटाएं"
    },
    "settings.folder.label.description": {
        "ko": "설명 (Description)", "en": "Description", "ja": "説明 (Description)",
        "zh-Hans": "描述"
    },
    "settings.folder.label.rule_name": {
        "ko": "규칙 이름 (폴더명)", "en": "Rule Name (Folder Name)",
        "ja": "規則名 (フォルダ名)", "zh-Hans": "规则名称"
    },
    "settings.folder.menu.change_icon": {
        "ko": "아이콘 변경...", "en": "Change Icon...", "ja": "アイコンを変更...",
        "zh-Hans": "更改图标..."
    },
    "settings.folder.menu.copy_icon": {
        "ko": "아이콘 복사", "en": "Copy Icon", "ja": "アイコンをコピー",
        "zh-Hans": "复制图标"
    },
    "settings.folder.menu.paste_icon": {
        "ko": "아이콘 붙여넣기", "en": "Paste Icon", "ja": "アイコンを貼り付け",
        "zh-Hans": "粘贴图标"
    },
    "settings.folder.menu.remove_icon": {
        "ko": "아이콘 제거", "en": "Remove Icon", "ja": "アイコンを削除",
        "zh-Hans": "移除图标"
    },
    "settings.folder.placeholder.description": {
        "ko": "규칙에 대한 설명", "en": "Description for the rule", "ja": "規則の詳細説明",
        "zh-Hans": "规则描述"
    },
    "settings.folder.placeholder.rule_name": {
        "ko": "규칙 이름", "en": "Rule Name", "ja": "規則名", "zh-Hans": "规则名称"
    },
    "settings.folder.label.prefix": {
        "ko": "접두사 (Prefix)", "en": "Prefix", "ja": "プレフィックス (Prefix)",
        "zh-Hans": "前缀"
    },
    "settings.folder.label.suffix": {
        "ko": "접미사 (Suffix)", "en": "Suffix", "ja": "サフィックス (Suffix)",
        "zh-Hans": "后缀"
    },
    "settings.folder.type.none": {
        "ko": "없음", "en": "None", "ja": "なし", "zh-Hans": "无"
    },
    "settings.folder.type.text": {
        "ko": "텍스트", "en": "Text", "ja": "テキスト", "zh-Hans": "文本"
    },
    "settings.folder.type.hotkey": {
        "ko": "단축키", "en": "Hotkey", "ja": "ホットキー", "zh-Hans": "热键"
    },
    "settings.snippet.label.filename": {
        "ko": "파일명:", "en": "Filename:", "ja": "ファイル名:", "zh-Hans": "文件名:"
    },
    "settings.snippet.button.insert_prompt": {
        "ko": "삽입", "en": "Insert", "ja": "挿入", "zh-Hans": "插入"
    },
    "settings.snippet.message.select_file": {
        "ko": "스니펫에 포함할 파일을 선택하세요", "en": "Select a file to include in the snippet",
        "ja": "スニペットに含めるファイルを選択してください", "zh-Hans": "选择要包含在片段中的文件"
    },
    "settings.folder.desc.excluded_files": {
        "ko": "특정 폴더에서 제외할 파일을 관리합니다.",
        "en": "Manage files to exclude from specific folders.",
        "ja": "特定のフォルダから除外するファイルを管理します。",
        "de": "Verwalten Sie Dateien, die von bestimmten Ordnern ausgeschlossen werden sollen.",
        "es": "Gestione los archivos a excluir de carpetas específicas.",
        "fr": "Gérez les fichiers à exclure de dossiers spécifiques.",
        "zh-Hans": "管理要从特定文件夹中排除的文件。",
        "zh-Hant": "管理要從特定資料夾中排除的檔案。"
    },
    "settings.folder.empty_state": {
        "ko": "폴더를 선택하면 제외할 파일을 관리할 수 있습니다.",
        "en": "Select a folder to manage excluded files.",
        "ja": "フォルダを選択して除外ファイルを管理します。",
        "de": "Wählen Sie einen Ordner, um ausgeschlossene Dateien zu verwalten.",
        "es": "Seleccione una carpeta para gestionar archivos excluidos.",
        "fr": "Sélectionnez un dossier pour gérer les fichiers exclus.",
        "zh-Hans": "选择文件夹以管理排除的文件。",
        "zh-Hant": "選擇資料夾以管理排除的檔案。"
    },
    "settings.folder.help.delete": {
        "ko": "선택한 폴더 설정 삭제", "en": "Delete selected folder settings",
        "ja": "選択したフォルダ設定を削除", "de": "Ausgewählte Ordnereinstellungen löschen",
        "es": "Eliminar configuración de carpeta seleccionada", "fr": "Supprimer les paramètres du dossier sélectionné",
        "zh-Hans": "删除所选文件夹设置", "zh-Hant": "刪除所選資料夾設定",
        "ar": "حذف إعدادات المجلد المحدد", "hi": "चयनित फ़ोल्डर सेटिंग्स हटाएं"
    },
    "settings.folder.label.configured_folders": {
        "ko": "설정된 폴더:", "en": "Configured Folders:",
        "ja": "設定済みフォルダ：", "de": "Konfigurierte Ordner:",
        "es": "Carpetas configuradas:", "fr": "Dossiers configurés :",
        "zh-Hans": "已配置的文件夹：", "zh-Hant": "已設定的資料夾："
    },
    "settings.folder.label.select_folder_to_add": {
        "ko": "설정할 폴더 선택:", "en": "Select Folder to Add:",
        "ja": "追加するフォルダを選択：", "de": "Ordner zum Hinzufügen auswählen:",
        "es": "Seleccionar carpeta para añadir:", "fr": "Sélectionner le dossier à ajouter :",
        "zh-Hans": "选择要添加的文件夹：", "zh-Hant": "選擇要新增的資料夾："
    },
    "settings.folder.list.excluded_files_title": {
        "ko": "제외된 파일 목록", "en": "Excluded Files",
        "ja": "除外ファイル一覧", "de": "Ausgeschlossene Dateien",
        "es": "Archivos excluidos", "fr": "Fichiers exclus",
        "zh-Hans": "排除的文件", "zh-Hant": "排除的檔案"
    },
    "settings.folder.list.files_in_folder_title": {
        "ko": "폴더 내 파일 (클릭하여 제외)", "en": "Files in Folder (Click to Exclude)",
        "ja": "フォルダ内のファイル（クリックで除外）", "de": "Dateien im Ordner (Klicken zum Ausschließen)",
        "es": "Archivos en carpeta (Clic para excluir)", "fr": "Fichiers dans le dossier (Cliquez pour exclure)",
        "zh-Hans": "文件夹中的文件（点击排除）", "zh-Hant": "資料夾中的檔案（點擊排除）"
    },
    "settings.folder.list.no_files_to_show": {
        "ko": "표시할 파일이 없습니다.", "en": "No files to show.",
        "ja": "表示するファイルがありません。", "de": "Keine Dateien anzuzeigen.",
        "es": "No hay archivos para mostrar.", "fr": "Aucun fichier à afficher.",
        "zh-Hans": "没有要显示的文件。", "zh-Hant": "沒有要顯示的檔案。"
    },
    "settings.folder.menu.no_folders_available": {
        "ko": "추가할 폴더가 없습니다", "en": "No folders available to add",
        "ja": "追加できるフォルダがありません", "de": "Keine Ordner zum Hinzufügen verfügbar",
        "es": "No hay carpetas disponibles para añadir", "fr": "Aucun dossier disponible à ajouter",
        "zh-Hans": "没有可添加的文件夹", "zh-Hant": "沒有可新增的資料夾"
    },
    "settings.folder.picker.no_folder": {
        "ko": "폴더 없음", "en": "No Folder",
        "ja": "フォルダなし", "de": "Kein Ordner",
        "es": "Sin carpeta", "fr": "Aucun dossier",
        "zh-Hans": "无文件夹", "zh-Hant": "無資料夾",
        "ar": "لا يوجد مجلد", "hi": "कोई फ़ोल्डर नहीं"
    },
    "settings.folder.placeholder.file_name": {
        "ko": "파일명 직접 입력", "en": "Enter filename",
        "ja": "ファイル名を入力", "de": "Dateinamen eingeben",
        "es": "Ingrese nombre de archivo", "fr": "Entrez le nom du fichier",
        "zh-Hans": "输入文件名", "zh-Hant": "輸入檔案名稱",
        "ar": "أدخل اسم الملف", "hi": "फ़ाइल नाम दर्ज करें"
    },
    "settings.folder.placeholder.folder_name": {
        "ko": "폴더명 입력 또는 선택", "en": "Enter or Select Folder Name",
        "ja": "フォルダ名を入力または選択", "de": "Ordnernamen eingeben oder auswählen",
        "es": "Ingrese o seleccione nombre de carpeta", "fr": "Entrez ou sélectionnez le nom du dossier",
        "zh-Hans": "输入或选择文件夹名", "zh-Hant": "輸入或選擇資料夾名稱",
        "ar": "أدخل أو اختر اسم المجلد", "hi": "फ़ोल्डर का नाम दर्ज करें या चुनें"
    },
    "settings.folder.title.excluded_files": {
        "ko": "폴더별 제외 파일 설정", "en": "Per-Folder Excluded Files",
        "ja": "フォルダごとの除外ファイル設定", "de": "Ordnerspezifische ausgeschlossene Dateien",
        "es": "Archivos excluidos por carpeta", "fr": "Fichiers exclus par dossier",
        "zh-Hans": "按文件夹排除文件", "zh-Hant": "按資料夾排除檔案"
    },

    # === General Settings ===
    "settings.general.backspace_adj": {
        "ko": "백스페이스 조정값:", "en": "Backspace Adjust:",
        "ja": "バックスペース調整：", "de": "Rücktasten-Anpassung:",
        "es": "Ajuste de retroceso:", "fr": "Ajustement du retour arrière :",
        "zh-Hans": "退格调整：", "zh-Hant": "退格調整：",
        "ar": "تعديل المسافة للخلف:", "hi": "बैकस्पेस समायोजन:"
    },
    "settings.general.backspace_adj.help": {
        "ko": "• -1: 한 글자 덜 지움 (빠른 입력 시 유용)\n• 0: 기본값 (권장)\n• +1: 한 글자 더 지움 (느린 입력 시 유용)",
        "en": "• -1: Delete one less char (Fast typing)\n• 0: Default (Recommended)\n• +1: Delete one more char (Slow typing)",
        "ja": "• -1: 1文字少なく削除（高速入力時に便利）\n• 0: デフォルト（推奨）\n• +1: 1文字多く削除（低速入力時に便利）",
        "de": "• -1: Ein Zeichen weniger löschen (Schnelle Eingabe)\n• 0: Standard (Empfohlen)\n• +1: Ein Zeichen mehr löschen (Langsame Eingabe)",
        "es": "• -1: Eliminar un carácter menos (Escritura rápida)\n• 0: Predeterminado (Recomendado)\n• +1: Eliminar un carácter más (Escritura lenta)",
        "fr": "• -1 : Supprimer un caractère de moins (Frappe rapide)\n• 0 : Par défaut (Recommandé)\n• +1 : Supprimer un caractère de plus (Frappe lente)",
        "zh-Hans": "• -1：少删一个字符（快速输入）\n• 0：默认（推荐）\n• +1：多删一个字符（慢速输入）",
        "zh-Hant": "• -1：少刪一個字元（快速輸入）\n• 0：預設（建議）\n• +1：多刪一個字元（慢速輸入）"
    },
    "settings.general.button.apply": {
        "ko": "적용", "en": "Apply",
        "ja": "適用", "de": "Anwenden",
        "es": "Aplicar", "fr": "Appliquer",
        "zh-Hans": "应用", "zh-Hant": "套用",
        "ar": "تطبيق", "hi": "लागू करें"
    },
    "settings.general.button.cancel": {
        "ko": "취소", "en": "Cancel",
        "ja": "キャンセル", "de": "Abbrechen",
        "es": "Cancelar", "fr": "Annuler",
        "zh-Hans": "取消", "zh-Hant": "取消",
        "ar": "إلغاء", "hi": "रद्द करें"
    },
    "settings.general.button.change": {
        "ko": "변경", "en": "Change",
        "ja": "変更", "de": "Ändern",
        "es": "Cambiar", "fr": "Modifier",
        "zh-Hans": "更改", "zh-Hant": "更改",
        "ar": "تغيير", "hi": "बदलें"
    },
    "settings.general.button.rebuild_index": {
        "ko": "인덱스 재구성", "en": "Rebuild Index",
        "ja": "インデックスを再構築", "de": "Index neu aufbauen",
        "es": "Reconstruir índice", "fr": "Reconstruire l'index",
        "zh-Hans": "重建索引", "zh-Hant": "重建索引"
    },
    "settings.general.button.reindex": {
        "ko": "인덱스 재구성", "en": "Rebuild Index",
        "ja": "インデックス再構築", "de": "Index neu erstellen",
        "es": "Reconstruir índice", "fr": "Reconstruire l'index",
        "zh-Hans": "重建索引", "zh-Hant": "重建索引"
    },
    "settings.general.desc.popup_height": {
        "ko": "팝업 창에 표시할 최대 스니펫 목록 개수를 설정합니다. (최대 높이: 약 %lldpx)",
        "en": "Set the maximum number of snippets to display in the popup. (Max height: ~%lldpx)",
        "ja": "ポップアップに表示するスニペットの最大数を設定します。（最大高さ：約%lldpx）",
        "de": "Legen Sie die maximale Anzahl der Snippets im Popup fest. (Max. Höhe: ~%lldpx)",
        "es": "Establezca el número máximo de fragmentos a mostrar en el popup. (Altura máx.: ~%lldpx)",
        "fr": "Définissez le nombre maximum d'extraits à afficher dans la popup. (Hauteur max : ~%lldpx)",
        "zh-Hans": "设置弹窗中显示的最大片段数。（最大高度：约%lldpx）",
        "zh-Hant": "設定彈出視窗中顯示的最大片段數。（最大高度：約%lldpx）"
    },
    "settings.general.desc.popup_key": {
        "ko": "스니펫 검색창을 여는 글로벌 단축키입니다.",
        "en": "Global hotkey to open the snippet search window.",
        "ja": "スニペット検索ウィンドウを開くグローバルホットキーです。",
        "de": "Globaler Hotkey zum Öffnen des Snippet-Suchfensters.",
        "es": "Tecla de acceso global para abrir la ventana de búsqueda de fragmentos.",
        "fr": "Raccourci global pour ouvrir la fenêtre de recherche d'extraits.",
        "zh-Hans": "打开片段搜索窗口的全局热键。",
        "zh-Hant": "開啟片段搜尋視窗的全域快捷鍵。"
    },
    "settings.general.desc.popup_rows": {
        "ko": "팝업 창에 표시할 최대 스니펫 목록 개수를 설정합니다.",
        "en": "Set the maximum number of snippets to display in the popup.",
        "ja": "ポップアップに表示するスニペットの最大数を設定します。",
        "de": "Legen Sie die maximale Anzahl der Snippets im Popup fest.",
        "es": "Establezca el número máximo de fragmentos a mostrar.",
        "fr": "Définissez le nombre maximum d'extraits à afficher.",
        "zh-Hans": "设置弹窗中显示的最大片段数。",
        "zh-Hant": "設定彈出視窗中顯示的最大片段數。"
    },
    "settings.general.desc.quick_select": {
        "ko": "팝업에서 숫자키(1-9)를 눌러 항목을 즉시 실행합니다.",
        "en": "Press number keys (1-9) in the popup to instantly select items.",
        "ja": "ポップアップで数字キー（1-9）を押してアイテムを即座に選択します。",
        "de": "Drücken Sie Zahlentasten (1-9) im Popup, um Elemente sofort auszuwählen.",
        "es": "Presione teclas numéricas (1-9) en el popup para seleccionar elementos al instante.",
        "fr": "Appuyez sur les touches numériques (1-9) dans la popup pour sélectionner instantanément.",
        "zh-Hans": "在弹窗中按数字键（1-9）即时选择项目。",
        "zh-Hant": "在彈出視窗中按數字鍵（1-9）即時選擇項目。"
    },
    "settings.general.error.validation": {
        "ko": "설정 검증 오류:", "en": "Settings validation error:",
        "ja": "設定検証エラー：", "de": "Einstellungsvalidierungsfehler:",
        "es": "Error de validación de ajustes:", "fr": "Erreur de validation des paramètres :",
        "zh-Hans": "设置验证错误：", "zh-Hant": "設定驗證錯誤："
    },
    "settings.general.label.backspace_adj": {
        "ko": "백스페이스 조정값:", "en": "Backspace Adj:",
        "ja": "バックスペース調整：", "de": "Rücktasten-Anp.:",
        "es": "Ajuste de retroceso:", "fr": "Ajust. retour arrière :",
        "zh-Hans": "退格调整：", "zh-Hant": "退格調整："
    },
    "settings.general.label.popup_key": {
        "ko": "팝업 단축키:", "en": "Popup Key (Shortcut):",
        "ja": "ポップアップホットキー：", "de": "Popup-Hotkey:",
        "es": "Tecla de popup:", "fr": "Raccourci popup :",
        "zh-Hans": "弹窗快捷键：", "zh-Hant": "彈出視窗快捷鍵："
    },
    "settings.general.label.popup_rows": {
        "ko": "팝업 목록 수", "en": "Popup Rows",
        "ja": "ポップアップ行数", "de": "Popup-Zeilen",
        "es": "Filas de popup", "fr": "Lignes de popup",
        "zh-Hans": "弹窗行数", "zh-Hant": "彈出視窗列數"
    },
    "settings.general.label.quick_select": {
        "ko": "빠른 선택 키", "en": "Quick Select Modifier",
        "ja": "クイック選択修飾キー", "de": "Schnellwahl-Modifikator",
        "es": "Modificador de selección rápida", "fr": "Modificateur de sélection rapide",
        "zh-Hans": "快速选择修饰键", "zh-Hant": "快速選擇修飾鍵"
    },
    "settings.general.label.rows_count": {
        "ko": "%lld 행", "en": "%lld Rows",
        "ja": "%lld行", "de": "%lld Zeilen",
        "es": "%lld filas", "fr": "%lld lignes",
        "zh-Hans": "%lld行", "zh-Hant": "%lld列"
    },
    "settings.general.label.search_scope": {
        "ko": "검색 범위", "en": "Search Scope",
        "ja": "検索範囲", "de": "Suchbereich",
        "es": "Ámbito de búsqueda", "fr": "Portée de la recherche",
        "zh-Hans": "搜索范围", "zh-Hant": "搜尋範圍"
    },
    "settings.general.label.trigger_bias": {
        "ko": "트리거 바이어스:", "en": "Trigger Bias:",
        "ja": "トリガーバイアス：", "de": "Trigger-Bias:",
        "es": "Sesgo de activación:", "fr": "Biais de déclenchement :",
        "zh-Hans": "触发偏差：", "zh-Hant": "觸發偏差："
    },
    "settings.general.label.trigger_key": {
        "ko": "트리거 키:", "en": "Trigger Key:",
        "ja": "トリガーキー：", "de": "Auslösetaste:",
        "es": "Tecla de activación:", "fr": "Touche de déclenchement :",
        "zh-Hans": "触发键：", "zh-Hant": "觸發鍵："
    },
    "settings.general.language": {
        "ko": "언어", "en": "Language",
        "ja": "言語", "de": "Sprache",
        "es": "Idioma", "fr": "Langue",
        "zh-Hans": "语言", "zh-Hant": "語言",
        "ar": "اللغة", "hi": "भाषा"
    },
    "settings.general.language.restart_required": {
        "ko": "변경 사항을 적용하려면 앱을 재시작해야 합니다.",
        "en": "Restart required to apply changes.",
        "ja": "変更を適用するにはアプリの再起動が必要です。",
        "de": "Neustart erforderlich, um Änderungen anzuwenden.",
        "es": "Se requiere reiniciar para aplicar los cambios.",
        "fr": "Redémarrage requis pour appliquer les modifications.",
        "zh-Hans": "需要重启以应用更改。",
        "zh-Hant": "需要重新啟動以套用更改。",
        "ar": "إعادة التشغيل مطلوبة لتطبيق التغييرات.",
        "hi": "परिवर्तनों को लागू करने के लिए पुनरारंभ आवश्यक है।"
    },
    "settings.general.popover.backspace_desc": {
        "ko": "백스페이스 키가 삭제하는 문자 수를 조정합니다.\n\n• 양수(+): 더 많은 문자 삭제\n• 음수(-): 더 적은 문자 삭제\n• 0: 기본 동작",
        "en": "Adjusts the number of backspaces sent before pasting text.\n\n• Positive (+): Deletes more characters\n• Negative (-): Deletes fewer characters\n• 0: Default behavior",
        "ja": "テキスト貼り付け前に送信するバックスペースの数を調整します。\n\n• 正の値(+): より多くの文字を削除\n• 負の値(-): より少ない文字を削除\n• 0: デフォルト動作",
        "de": "Passt die Anzahl der Rücktasten vor dem Einfügen an.\n\n• Positiv (+): Löscht mehr Zeichen\n• Negativ (-): Löscht weniger Zeichen\n• 0: Standardverhalten",
        "es": "Ajusta el número de retrocesos enviados antes de pegar.\n\n• Positivo (+): Elimina más caracteres\n• Negativo (-): Elimina menos caracteres\n• 0: Comportamiento predeterminado",
        "fr": "Ajuste le nombre de retours arrière envoyés avant le collage.\n\n• Positif (+) : Supprime plus de caractères\n• Négatif (-) : Supprime moins de caractères\n• 0 : Comportement par défaut",
        "zh-Hans": "调整粘贴前发送的退格次数。\n\n• 正数(+)：删除更多字符\n• 负数(-)：删除更少字符\n• 0：默认行为",
        "zh-Hant": "調整貼上前發送的退格次數。\n\n• 正數(+)：刪除更多字元\n• 負數(-)：刪除更少字元\n• 0：預設行為"
    },
    "settings.general.popup_key": {
        "ko": "팝업 단축키", "en": "Popup Hotkey",
        "ja": "ポップアップホットキー", "de": "Popup-Hotkey",
        "es": "Tecla de acceso de popup", "fr": "Raccourci popup",
        "zh-Hans": "弹窗热键", "zh-Hant": "彈出視窗快捷鍵"
    },
    "settings.general.popup_key.desc": {
        "ko": "스니펫 검색창을 여는 글로벌 단축키입니다.",
        "en": "Global hotkey to open the snippet search window.",
        "ja": "スニペット検索ウィンドウを開くグローバルホットキーです。",
        "de": "Globaler Hotkey zum Öffnen des Snippet-Suchfensters.",
        "es": "Tecla de acceso global para abrir la búsqueda de fragmentos.",
        "fr": "Raccourci global pour ouvrir la recherche d'extraits.",
        "zh-Hans": "打开片段搜索窗口的全局热键。",
        "zh-Hant": "開啟片段搜尋視窗的全域快捷鍵。"
    },
    "settings.general.popup_rows": {
        "ko": "팝업 목록 수", "en": "Popup Rows",
        "ja": "ポップアップ行数", "de": "Popup-Zeilen",
        "es": "Filas de popup", "fr": "Lignes de popup",
        "zh-Hans": "弹窗行数", "zh-Hant": "彈出視窗列數"
    },
    "settings.general.popup_rows.desc": {
        "ko": "팝업 창에 표시할 최대 스니펫 목록 개수를 설정합니다.",
        "en": "Set the maximum number of snippets to display in the popup.",
        "ja": "ポップアップに表示するスニペットの最大数を設定します。",
        "de": "Legen Sie die maximale Anzahl der Snippets im Popup fest.",
        "es": "Establezca el número máximo de fragmentos a mostrar.",
        "fr": "Définissez le nombre maximum d'extraits à afficher.",
        "zh-Hans": "设置弹窗中显示的最大片段数。",
        "zh-Hant": "設定彈出視窗中顯示的最大片段數。"
    },
    "settings.general.quick_select": {
        "ko": "빠른 선택 조회 키", "en": "Quick Select Modifier",
        "ja": "クイック選択修飾キー", "de": "Schnellwahl-Modifikator",
        "es": "Modificador de selección rápida", "fr": "Modificateur de sélection rapide",
        "zh-Hans": "快速选择修饰键", "zh-Hant": "快速選擇修飾鍵"
    },
    "settings.general.quick_select.desc": {
        "ko": "팝업에서 %@ + 숫자키(1~9)를 눌러 리스트의 항목을 즉시 실행합니다.",
        "en": "Press %@ + Number (1-9) in the popup to instantly select items.",
        "ja": "ポップアップで%@ + 数字（1-9）を押してアイテムを即座に選択します。",
        "de": "Drücken Sie %@ + Zahl (1-9) im Popup für Schnellauswahl.",
        "es": "Presione %@ + Número (1-9) en el popup para selección rápida.",
        "fr": "Appuyez sur %@ + Numéro (1-9) dans la popup pour sélection rapide.",
        "zh-Hans": "在弹窗中按%@ + 数字（1-9）快速选择。",
        "zh-Hant": "在彈出視窗中按%@ + 數字（1-9）快速選擇。"
    },
    "settings.general.quick_select_modifier.command": {
        "ko": "Command (⌘)", "en": "Command (⌘)",
        "ja": "Command (⌘)", "de": "Command (⌘)",
        "es": "Command (⌘)", "fr": "Command (⌘)",
        "zh-Hans": "Command (⌘)", "zh-Hant": "Command (⌘)"
    },
    "settings.general.quick_select_modifier.control": {
        "ko": "Control (⌃)", "en": "Control (⌃)",
        "ja": "Control (⌃)", "de": "Control (⌃)",
        "es": "Control (⌃)", "fr": "Control (⌃)",
        "zh-Hans": "Control (⌃)", "zh-Hant": "Control (⌃)"
    },
    "settings.general.quick_select_modifier.option": {
        "ko": "Option (⌥)", "en": "Option (⌥)",
        "ja": "Option (⌥)", "de": "Option (⌥)",
        "es": "Option (⌥)", "fr": "Option (⌥)",
        "zh-Hans": "Option (⌥)", "zh-Hant": "Option (⌥)"
    },
    "settings.general.search_scope": {
        "ko": "검색 범위", "en": "Search Scope",
        "ja": "検索範囲", "de": "Suchbereich",
        "es": "Ámbito de búsqueda", "fr": "Portée de la recherche",
        "zh-Hans": "搜索范围", "zh-Hant": "搜尋範圍"
    },
    "settings.general.search_scope.desc.abbreviation": {
        "ko": "단축어(Keyword)만 검색합니다. (가장 빠름)",
        "en": "Search keywords only. (Fastest)",
        "ja": "キーワードのみを検索します。（最速）",
        "de": "Nur Schlüsselwörter durchsuchen. (Schnellste)",
        "es": "Buscar solo palabras clave. (Más rápido)",
        "fr": "Rechercher uniquement les mots-clés. (Plus rapide)",
        "zh-Hans": "仅搜索关键词。（最快）",
        "zh-Hant": "僅搜尋關鍵字。（最快）"
    },
    "settings.general.search_scope.desc.content": {
        "ko": "단축어, 파일명, 폴더명, 설명, 본문 내용을 모두 검색합니다.",
        "en": "Search keywords, filenames, folders, descriptions, and content.",
        "ja": "キーワード、ファイル名、フォルダ、説明、内容をすべて検索します。",
        "de": "Schlüsselwörter, Dateinamen, Ordner, Beschreibungen und Inhalt durchsuchen.",
        "es": "Buscar palabras clave, nombres de archivo, carpetas, descripciones y contenido.",
        "fr": "Rechercher mots-clés, noms de fichiers, dossiers, descriptions et contenu.",
        "zh-Hans": "搜索关键词、文件名、文件夹、描述和内容。",
        "zh-Hant": "搜尋關鍵字、檔案名稱、資料夾、描述和內容。"
    },
    "settings.general.search_scope.desc.name": {
        "ko": "단축어, 파일명, 폴더명, 설명을 검색합니다.",
        "en": "Search keywords, filenames, folders, and descriptions.",
        "ja": "キーワード、ファイル名、フォルダ、説明を検索します。",
        "de": "Schlüsselwörter, Dateinamen, Ordner und Beschreibungen durchsuchen.",
        "es": "Buscar palabras clave, nombres de archivo, carpetas y descripciones.",
        "fr": "Rechercher mots-clés, noms de fichiers, dossiers et descriptions.",
        "zh-Hans": "搜索关键词、文件名、文件夹和描述。",
        "zh-Hant": "搜尋關鍵字、檔案名稱、資料夾和描述。"
    },
    "settings.general.section.app_behavior": {
        "ko": "앱 동작", "en": "App Behavior",
        "ja": "アプリ動作", "de": "App-Verhalten",
        "es": "Comportamiento de la app", "fr": "Comportement de l'app",
        "zh-Hans": "应用行为", "zh-Hant": "應用程式行為"
    },
    "settings.general.section.basic": {
        "ko": "기본 설정", "en": "Basic Settings",
        "ja": "基本設定", "de": "Grundeinstellungen",
        "es": "Ajustes básicos", "fr": "Paramètres de base",
        "zh-Hans": "基本设置", "zh-Hant": "基本設定",
        "ar": "الإعدادات الأساسية", "hi": "बुनियादी सेटिंग्स"
    },
    "settings.general.section.behavior": {
        "ko": "앱 동작", "en": "App Behavior",
        "ja": "アプリ動作", "de": "App-Verhalten",
        "es": "Comportamiento de la app", "fr": "Comportement de l'app",
        "zh-Hans": "应用行为", "zh-Hant": "應用程式行為"
    },
    "settings.general.section.popup": {
        "ko": "팝업 설정", "en": "Popup Settings",
        "ja": "ポップアップ設定", "de": "Popup-Einstellungen",
        "es": "Ajustes de popup", "fr": "Paramètres de popup",
        "zh-Hans": "弹窗设置", "zh-Hant": "彈出視窗設定"
    },
    "settings.general.settings_folder": {
        "ko": "설정 폴더 위치:", "en": "Settings Folder:",
        "ja": "設定フォルダの場所：", "de": "Einstellungsordner:",
        "es": "Carpeta de ajustes:", "fr": "Dossier des paramètres :",
        "zh-Hans": "设置文件夹：", "zh-Hant": "設定資料夾："
    },
    "settings.general.snippet_folder": {
        "ko": "Snippet 폴더 위치:", "en": "Snippet Folder:",
        "ja": "スニペットフォルダの場所：", "de": "Snippet-Ordner:",
        "es": "Carpeta de fragmentos:", "fr": "Dossier des extraits :",
        "zh-Hans": "片段文件夹：", "zh-Hant": "片段資料夾：",
        "ar": "مجلد المقتطفات:", "hi": "स्निपेट फ़ोल्डर:"
    },
    "settings.general.title": {
        "ko": "일반 설정", "en": "General Settings",
        "ja": "一般設定", "de": "Allgemeine Einstellungen",
        "es": "Configuración general", "fr": "Paramètres généraux",
        "zh-Hans": "通用设置", "zh-Hant": "一般設定",
        "ar": "إعدادات عامة", "hi": "सामान्य सेटिंग्स"
    },
    "settings.general.toggle.auto_start": {
        "ko": "시스템 시작 시 자동 실행", "en": "Launch at Login",
        "ja": "ログイン時に起動", "de": "Beim Login starten",
        "es": "Iniciar al iniciar sesión", "fr": "Lancer à la connexion",
        "zh-Hans": "登录时启动", "zh-Hant": "登入時啟動"
    },
    "settings.general.toggle.hide_menubar": {
        "ko": "메뉴바에서 숨기기", "en": "Hide from Menu Bar",
        "ja": "メニューバーから隠す", "de": "Aus Menüleiste ausblenden",
        "es": "Ocultar de la barra de menús", "fr": "Masquer de la barre de menus",
        "zh-Hans": "从菜单栏隐藏", "zh-Hant": "從選單列隱藏",
        "ar": "إخفاء من شريط القوائم", "hi": "मेनू बार से छिपाएं"
    },
    "settings.general.toggle.launch_at_login": {
        "ko": "로그인 시 실행", "en": "Launch at Login",
        "ja": "ログイン時に起動", "de": "Beim Login starten",
        "es": "Iniciar al iniciar sesión", "fr": "Lancer à la connexion",
        "zh-Hans": "登录时启动", "zh-Hant": "登入時啟動"
    },
    "settings.general.toggle.notifications": {
        "ko": "알림 표시", "en": "Show Notifications",
        "ja": "通知を表示", "de": "Benachrichtigungen anzeigen",
        "es": "Mostrar notificaciones", "fr": "Afficher les notifications",
        "zh-Hans": "显示通知", "zh-Hant": "顯示通知"
    },
    "settings.general.toggle.play_sound": {
        "ko": "준비 완료 시 알림음 재생 (딩동)", "en": "Play Sound on Ready (Ding-Dong)",
        "ja": "準備完了時に音を鳴らす（ディンドン）", "de": "Ton bei Bereitschaft abspielen (Ding-Dong)",
        "es": "Reproducir sonido al estar listo (Ding-Dong)", "fr": "Jouer un son quand prêt (Ding-Dong)",
        "zh-Hans": "准备就绪时播放声音（叮咚）", "zh-Hant": "準備就緒時播放音效（叮咚）"
    },
    "settings.general.toggle.ready_sound": {
        "ko": "스니펫 준비 시 알림음(딩동)", "en": "Play Sound on Ready (Ding-Dong)",
        "ja": "スニペット準備時に音を鳴らす（ディンドン）", "de": "Ton bei Snippet-Bereitschaft (Ding-Dong)",
        "es": "Reproducir sonido al preparar fragmento (Ding-Dong)", "fr": "Jouer un son à la préparation de l'extrait (Ding-Dong)",
        "zh-Hans": "片段准备就绪时播放声音（叮咚）", "zh-Hant": "片段準備就緒時播放音效（叮咚）"
    },
    "settings.general.toggle.show_notifications": {
        "ko": "알림 표시", "en": "Show Notifications",
        "ja": "通知を表示", "de": "Benachrichtigungen anzeigen",
        "es": "Mostrar notificaciones", "fr": "Afficher les notifications",
        "zh-Hans": "显示通知", "zh-Hant": "顯示通知"
    },
    "settings.general.trigger_bias": {
        "ko": "트리거 바이어스:", "en": "Trigger Bias:",
        "ja": "トリガーバイアス：", "de": "Trigger-Bias:",
        "es": "Sesgo de activación:", "fr": "Biais de déclenchement :",
        "zh-Hans": "触发偏差：", "zh-Hant": "觸發偏差："
    },
    "settings.general.trigger_key": {
        "ko": "트리거 키", "en": "Trigger Key",
        "ja": "トリガーキー", "de": "Auslösetaste",
        "es": "Tecla de activación", "fr": "Touche de déclenchement",
        "zh-Hans": "触发键", "zh-Hant": "觸發鍵"
    },
    "settings.general.toggle.show_in_app_switcher": {
        "ko": "앱 스위처에 표시 (Cmd+Tab)", "en": "Show in App Switcher (Cmd+Tab)",
        "ja": "Appスイッチャーに表示 (Cmd+Tab)", "de": "Im App-Umschalter anzeigen (Cmd+Tab)",
        "es": "Mostrar en el selector de apps (Cmd+Tab)", "fr": "Afficher dans le sélecteur d'applications (Cmd+Tab)",
        "zh-Hans": "在应用切换器中显示 (Cmd+Tab)", "zh-Hant": "在應用程式切換器中顯示 (Cmd+Tab)",
        "ar": "إظهار في مبدل التطبيقات (Cmd+Tab)", "hi": "ऐप स्विचर में दिखाएं (Cmd+Tab)"
    },
    "settings.general.permissions": {
        "ko": "권한:", "en": "Permissions:",
        "ja": "権限:", "de": "Berechtigungen:",
        "es": "Permisos:", "fr": "Autorisations :",
        "zh-Hans": "权限：", "zh-Hant": "權限：",
        "ar": "الأذونات:", "hi": "अनुमतियां:"
    },
    "settings.general.permissions.desc": {
        "ko": "fSnippet은 Mac 자동화를 위해 접근성 권한이 필요합니다. 클릭하여 허용하세요.", "en": "fSnippet requires Accessibility permissions to automate your Mac. Click to allow.",
        "ja": "fSnippetがMacを自動化するにはアクセシビリティ権限が必要です。クリックして許可してください。", "de": "fSnippet benötigt Bedienungshilfen-Berechtigungen zur Automatisierung Ihres Mac. Klicken Sie zum Erlauben.",
        "es": "fSnippet requiere permisos de Accesibilidad para automatizar su Mac. Haga clic para permitir.", "fr": "fSnippet nécessite des autorisations d'accessibilité pour automatiser votre Mac. Cliquez pour autoriser.",
        "zh-Hans": "fSnippet需要辅助功能权限才能自动执行您的Mac。点击允许。", "zh-Hant": "fSnippet需要輔助功能權限才能自動執行您的Mac。點擊允許。",
        "ar": "يتطلب fSnippet أذونات إمكانية الوصول لأتمتة جهاز Mac الخاص بك. انقر للسماح.", "hi": "fSnippet को आपके Mac को स्वचालित करने के लिए एक्सेसिबिलिटी अनुमतियों की आवश्यकता है। अनुमति देने के लिए क्लिक करें।"
    },
    "settings.general.permissions.granted": {
        "ko": "권한 허용됨", "en": "Permission Granted",
        "ja": "権限付与済み", "de": "Berechtigung erteilt",
        "es": "Permiso concedido", "fr": "Autorisation accordée",
        "zh-Hans": "已授予权限", "zh-Hant": "已授予權限",
        "ar": "تم منح الإذن", "hi": "अनुमति प्रदान की गई"
    },
    "settings.general.permissions.request": {
        "ko": "권한 요청...", "en": "Request Permission...",
        "ja": "権限をリクエスト...", "de": "Berechtigung anfordern...",
        "es": "Solicitar permiso...", "fr": "Demander l'autorisation...",
        "zh-Hans": "请求权限...", "zh-Hant": "請求權限...",
        "ar": "طلب إذن...", "hi": "अनुमति मांगें..."
    },
    "Appearance": {
        "ko": "화면 모드", "en": "Appearance",
        "ja": "外観", "de": "Erscheinungsbild",
        "es": "Apariencia", "fr": "Apparence",
        "zh-Hans": "外观", "zh-Hant": "外觀",
        "ar": "المظهر", "hi": "दिखावट"
    },
    "settings.general.popup_width": {
        "ko": "팝업창 너비", "en": "Popup Width",
        "ja": "ポップアップの幅", "de": "Popup-Breite",
        "es": "Ancho del popup", "fr": "Largeur du popup",
        "zh-Hans": "弹窗宽度", "zh-Hant": "彈出視窗寬度",
        "ar": "عرض النافذة المنبثقة", "hi": "पॉपअप चौड़ाई"
    },
    "settings.general.desc.popup_width": {
        "ko": "스니펫 목록 창의 너비를 조절합니다 (300-800)", "en": "Adjust width of the snippet list window (300-800)",
        "ja": "スニペットリストウィンドウの幅を調整します (300-800)", "de": "Breite des Snippet-Listenfensters anpassen (300-800)",
        "es": "Ajustar el ancho de la ventana de la lista de fragmentos (300-800)", "fr": "Ajuster la largeur de la fenêtre de la liste des extraits (300-800)",
        "zh-Hans": "调整片段列表窗口的宽度 (300-800)", "zh-Hant": "調整片段列表視窗的寬度 (300-800)",
        "ar": "يعدل عرض نافذة قائمة المقتطفات (300-800)", "hi": "स्निपेट सूची विंडो की चौड़ाई समायोजित करें (300-800)"
    },
    "settings.history.label.preview_width": {
        "ko": "미리보기 창 너비", "en": "Preview Window Width",
        "ja": "プレビューウィンドウの幅", "de": "Breite des Vorschaufensters",
        "es": "Ancho de la ventana de vista previa", "fr": "Largeur de la fenêtre d'aperçu",
        "zh-Hans": "预览窗口宽度", "zh-Hant": "預覽視窗寬度",
        "ar": "عرض نافذة المعاينة", "hi": "पूर्वावलोकन विंडो की चौड़ाई"
    },
    "settings.general.desc.clipboard_preview_width": {
        "ko": "클립보드 미리보기 창의 너비를 조절합니다 (300-800)", "en": "Adjust the width of the clipboard preview window (300-800)",
        "ja": "クリップボードプレビューウィンドウの幅を調整します (300-800)", "de": "Breite des Zwischenablage-Vorschaufensters anpassen (300-800)",
        "es": "Ajustar el ancho de la ventana de vista previa del portapapeles (300-800)", "fr": "Ajuster la largeur de la fenêtre d'aperçu du presse-papiers (300-800)",
        "zh-Hans": "调整剪贴板预览窗口的宽度 (300-800)", "zh-Hant": "調整剪貼簿預覽視窗的寬度 (300-800)",
        "ar": "ضبط عرض نافذة معاينة الحافظة (300-800)", "hi": "क्लिपबोर्ड पूर्वावलोकन विंडो की चौड़ाई समायोजित करें (300-800)"
    },

    # === History Settings ===
    "settings.history.desc": {
        "ko": "텍스트와 이미지의 클립보드 히스토리를 관리하세요.",
        "en": "Manage clipboard history of text and images.",
        "ja": "テキストと画像のクリップボード履歴を管理します。",
        "de": "Verwalten Sie den Zwischenablage-Verlauf von Text und Bildern.",
        "es": "Gestione el historial del portapapeles de texto e imágenes.",
        "fr": "Gérez l'historique du presse-papiers de texte et d'images.",
        "zh-Hans": "管理文本和图像的剪贴板历史。",
        "zh-Hant": "管理文字和圖片的剪貼簿歷史。"
    },
    "settings.history.footer.config_path": {
        "ko": "설정 파일: %@", "en": "Config file: %@",
        "ja": "設定ファイル：%@", "de": "Konfigurationsdatei: %@",
        "es": "Archivo de configuración: %@", "fr": "Fichier de configuration : %@",
        "zh-Hans": "配置文件：%@", "zh-Hant": "設定檔：%@"
    },
    "settings.history.footer.desc": {
        "ko": "설정은 자동으로 저장됩니다.", "en": "Settings are saved automatically.",
        "ja": "設定は自動的に保存されます。", "de": "Einstellungen werden automatisch gespeichert.",
        "es": "Los ajustes se guardan automáticamente.", "fr": "Les paramètres sont enregistrés automatiquement.",
        "zh-Hans": "设置自动保存。", "zh-Hant": "設定自動儲存。"
    },
    "settings.history.label.keep": {
        "ko": "보관:", "en": "Keep:",
        "ja": "保持：", "de": "Behalten:",
        "es": "Conservar:", "fr": "Conserver :",
        "zh-Hans": "保留：", "zh-Hant": "保留："
    },
    "settings.history.label.pause": {
        "ko": "수집 일시정지", "en": "Pause Collection",
        "ja": "収集を一時停止", "de": "Erfassung pausieren",
        "es": "Pausar recopilación", "fr": "Suspendre la collecte",
        "zh-Hans": "暂停收集", "zh-Hant": "暫停收集"
    },
    "settings.history.label.preview_hotkey": {
        "ko": "미리보기 토글", "en": "Toggle Preview",
        "ja": "プレビューを切り替え", "de": "Vorschau umschalten",
        "es": "Alternar vista previa", "fr": "Basculer l'aperçu",
        "zh-Hans": "切换预览", "zh-Hant": "切換預覽"
    },
    "settings.history.label.register_hotkey": {
        "ko": "스니펫으로 등록", "en": "Register as Snippet",
        "ja": "スニペットとして登録", "de": "Als Snippet registrieren",
        "es": "Registrar como fragmento", "fr": "Enregistrer comme extrait",
        "zh-Hans": "注册为片段", "zh-Hant": "註冊為片段"
    },
    "settings.history.label.viewer_hotkey": {
        "ko": "뷰어 단축키", "en": "Viewer Hotkey",
        "ja": "ビューアホットキー", "de": "Viewer-Hotkey",
        "es": "Tecla de acceso del visor", "fr": "Raccourci du visualiseur",
        "zh-Hans": "查看器热键", "zh-Hant": "檢視器快捷鍵"
    },
    "settings.history.section.data": {
        "ko": "데이터 관리", "en": "Data Management",
        "ja": "データ管理", "de": "Datenverwaltung",
        "es": "Gestión de datos", "fr": "Gestion des données",
        "zh-Hans": "数据管理", "zh-Hant": "數據管理"
    },
    "settings.history.section.hotkeys": {
        "ko": "단축키 및 필터", "en": "Hotkeys & Filters",
        "ja": "ホットキーとフィルター", "de": "Hotkeys & Filter",
        "es": "Atajos y filtros", "fr": "Raccourcis et filtres",
        "zh-Hans": "快捷键和过滤器", "zh-Hant": "快捷鍵和篩選器"
    },
    "settings.history.section.retention": {
        "ko": "수집 및 보관", "en": "Collection & Retention",
        "ja": "収集と保持", "de": "Erfassung & Aufbewahrung",
        "es": "Recopilación y retención", "fr": "Collecte et conservation",
        "zh-Hans": "收集和保留", "zh-Hant": "收集和保留"
    },
    "settings.history.section.viewer": {
        "ko": "뷰어 설정", "en": "Viewer Settings",
        "ja": "ビューア設定", "de": "Viewer-Einstellungen",
        "es": "Ajustes del visor", "fr": "Paramètres du visualiseur",
        "zh-Hans": "查看器设置", "zh-Hant": "檢視器設定"
    },
    "settings.history.title": {
        "ko": "히스토리", "en": "History",
        "ja": "履歴", "de": "Verlauf",
        "es": "Historial", "fr": "Historique",
        "zh-Hans": "历史", "zh-Hant": "歷史"
    },
    "settings.history.toggle.files": {
        "ko": "파일 목록", "en": "File Lists",
        "ja": "ファイルリスト", "de": "Dateilisten",
        "es": "Listas de archivos", "fr": "Listes de fichiers",
        "zh-Hans": "文件列表", "zh-Hant": "檔案清單"
    },
    "settings.history.toggle.ignore_files": {
        "ko": "검색 시 파일 목록 제외", "en": "Exclude File Lists from Search",
        "ja": "検索からファイルリストを除外", "de": "Dateilisten von Suche ausschließen",
        "es": "Excluir listas de archivos de la búsqueda", "fr": "Exclure les listes de fichiers de la recherche",
        "zh-Hans": "搜索时排除文件列表", "zh-Hant": "搜尋時排除檔案清單"
    },
    "settings.history.toggle.ignore_images": {
        "ko": "검색 시 이미지 제외", "en": "Exclude Images from Search",
        "ja": "検索から画像を除外", "de": "Bilder von Suche ausschließen",
        "es": "Excluir imágenes de la búsqueda", "fr": "Exclure les images de la recherche",
        "zh-Hans": "搜索时排除图片", "zh-Hant": "搜尋時排除圖片"
    },
    "settings.history.toggle.image_floating": {
        "ko": "이미지 플로팅 창 항상 위", "en": "Image Detail Window Always on Top",
        "ja": "画像詳細ウィンドウを常に最前面に", "de": "Bilddetailfenster immer im Vordergrund",
        "es": "Ventana de detalle de imagen siempre arriba", "fr": "Fenêtre de détail d'image toujours au premier plan",
        "zh-Hans": "图片详情窗口总在最前", "zh-Hant": "圖片詳情視窗總在最前"
    },
    "settings.history.toggle.images": {
        "ko": "이미지", "en": "Images",
        "ja": "画像", "de": "Bilder",
        "es": "Imágenes", "fr": "Images",
        "zh-Hans": "图片", "zh-Hant": "圖片"
    },
    "settings.history.toggle.move_duplicates": {
        "ko": "중복 항목 최상단 이동", "en": "Move Duplicates to Top",
        "ja": "重複を最上部に移動", "de": "Duplikate nach oben verschieben",
        "es": "Mover duplicados arriba", "fr": "Déplacer les doublons en haut",
        "zh-Hans": "将重复项移至顶部", "zh-Hant": "將重複項移至頂部"
    },
    "settings.history.toggle.show_preview": {
        "ko": "미리보기 패널 표시", "en": "Show Preview Panel",
        "ja": "プレビューパネルを表示", "de": "Vorschau-Panel anzeigen",
        "es": "Mostrar panel de vista previa", "fr": "Afficher le panneau d'aperçu",
        "zh-Hans": "显示预览面板", "zh-Hant": "顯示預覽面板"
    },
    "settings.history.toggle.show_statusbar": {
        "ko": "상태바 표시", "en": "Show Status Bar",
        "ja": "ステータスバーを表示", "de": "Statusleiste anzeigen",
        "es": "Mostrar barra de estado", "fr": "Afficher la barre d'état",
        "zh-Hans": "显示状态栏", "zh-Hant": "顯示狀態列"
    },
    "settings.history.toggle.text": {
        "ko": "텍스트", "en": "Text",
        "ja": "テキスト", "de": "Text",
        "es": "Texto", "fr": "Texte",
        "zh-Hans": "文本", "zh-Hant": "文字"
    },
    "settings.history.unit.days": {
        "ko": "일", "en": "days",
        "ja": "日", "de": "Tage",
        "es": "días", "fr": "jours",
        "zh-Hans": "天", "zh-Hant": "天"
    },

    # === Navigation ===
    "settings.nav.advanced": {
        "ko": "고급", "en": "Advanced",
        "ja": "詳細", "de": "Erweitert",
        "es": "Avanzado", "fr": "Avancé",
        "zh-Hans": "高级", "zh-Hant": "進階"
    },
    "settings.nav.clipboard": {
        "ko": "히스토리", "en": "History",
        "ja": "履歴", "de": "Verlauf",
        "es": "Historial", "fr": "Historique",
        "zh-Hans": "历史", "zh-Hant": "歷史"
    },
    "settings.nav.folders": {
        "ko": "폴더", "en": "Folders",
        "ja": "フォルダ", "de": "Ordner",
        "es": "Carpetas", "fr": "Dossiers",
        "zh-Hans": "文件夹", "zh-Hant": "資料夾"
    },
    "settings.nav.general": {
        "ko": "일반", "en": "General",
        "ja": "一般", "de": "Allgemein",
        "es": "General", "fr": "Général",
        "zh-Hans": "常规", "zh-Hant": "一般"
    },
    "settings.nav.snippets": {
        "ko": "스니펫", "en": "Snippets",
        "ja": "スニペット", "de": "Snippets",
        "es": "Fragmentos", "fr": "Extraits",
        "zh-Hans": "片段", "zh-Hant": "片段"
    },

    # === Snippet Settings ===
    "settings.snippet.alert.cancel.button": {
        "ko": "취소", "en": "Cancel",
        "ja": "キャンセル", "de": "Abbrechen",
        "es": "Cancelar", "fr": "Annuler",
        "zh-Hans": "取消", "zh-Hant": "取消"
    },
    "settings.snippet.alert.conflict.button.replace": {
        "ko": "덮어쓰기 (Replace)", "en": "Replace",
        "ja": "上書き", "de": "Ersetzen",
        "es": "Reemplazar", "fr": "Remplacer",
        "zh-Hans": "替换", "zh-Hant": "取代"
    },
    "settings.snippet.alert.conflict.message": {
        "ko": "이 단축어('%1$@')는 이미 다른 스니펫에서 사용 중입니다.\n\n기존 스니펫:\n• 이름: %2$@\n• 파일: %3$@\n\n덮어쓰시겠습니까? 기존 스니펫은 삭제됩니다.",
        "en": "This abbreviation ('%1$@') is already used by another snippet.\n\nExisting snippet:\n• Name: %2$@\n• File: %3$@\n\nDo you want to replace it? The existing snippet will be deleted.",
        "ja": "この略語('%1$@')は既に別のスニペットで使用されています。\n\n既存のスニペット：\n• 名前：%2$@\n• ファイル：%3$@\n\n上書きしますか？既存のスニペットは削除されます。",
        "zh-Hans": "此缩写('%1$@')已被另一个片段使用。\n\n确定要替换吗？"
    },
    "settings.snippet.alert.conflict.title": {
        "ko": "단축어 중복", "en": "Abbreviation Conflict",
        "ja": "略語の衝突", "zh-Hans": "缩写冲突"
    },
    "settings.snippet.alert.delete.button": {
        "ko": "삭제", "en": "Delete",
        "ja": "削除", "de": "Löschen",
        "es": "Eliminar", "fr": "Supprimer",
        "zh-Hans": "删除", "zh-Hant": "刪除"
    },
    "settings.snippet.alert.delete.message": {
        "ko": "이 스니펫을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.",
        "en": "Are you sure you want to delete this snippet?\nThis action cannot be undone.",
        "ja": "このスニペットを削除しますか？\nこの操作は取り消せません。",
        "de": "Möchten Sie dieses Snippet wirklich löschen?\nDiese Aktion kann nicht rückgängig gemacht werden.",
        "es": "¿Está seguro de que desea eliminar este fragmento?\nEsta acción no se puede deshacer.",
        "fr": "Êtes-vous sûr de vouloir supprimer cet extrait ?\nCette action est irréversible.",
        "zh-Hans": "确定要删除此片段吗？\n此操作无法撤销。",
        "zh-Hant": "確定要刪除此片段嗎？\n此操作無法復原。"
    },
    "settings.snippet.alert.delete.title": {
        "ko": "스니펫 삭제", "en": "Delete Snippet",
        "ja": "スニペットを削除", "de": "Snippet löschen",
        "es": "Eliminar fragmento", "fr": "Supprimer l'extrait",
        "zh-Hans": "删除片段", "zh-Hant": "刪除片段"
    },
    "settings.snippet.button.insert_file": {
        "ko": "파일 삽입", "en": "Insert File", "ja": "ファイルを挿入",
        "zh-Hans": "插入文件"
    },
    "settings.snippet.button.reference": {
        "ko": "스니펫 참조", "en": "Snippet Reference", "ja": "スニペット参照",
        "zh-Hans": "片段引用"
    },
    "settings.snippet.help.duplicate": {
        "ko": "이미 존재하는 단축어(Abbreviation)입니다.", "en": "This abbreviation already exists.",
        "ja": "既に存在する略語です。", "zh-Hans": "缩写已存在"
    },
    "settings.snippet.help.insert_file": {
        "ko": "외부 파일 내용을 참조로 삽입합니다 (Issue 549)", 
        "en": "Inserts external file content as a reference (Issue 549)",
        "ja": "外部ファイルの内容を参照として挿入します (Issue 549)"
    },
    "settings.snippet.help.reference": {
        "ko": "다른 스니펫 내용을 참조로 삽입합니다 (Issue 539)",
        "en": "Inserts other snippet content as a reference (Issue 539)",
        "ja": "他のスニペットの内容を参照として挿入します (Issue 539)"
    },
    "settings.snippet.help.save": {
        "ko": "저장 (Cmd+S)", "en": "Save (Cmd+S)", "ja": "保存 (Cmd+S)"
    },
    "settings.snippet.label.content": {
        "ko": "내용", "en": "Content", "ja": "内容", "zh-Hans": "内容"
    },
    "settings.snippet.label.folder": {
        "ko": "저장 폴더", "en": "Storage Folder", "ja": "保存フォルダ",
        "zh-Hans": "保存文件夹"
    },
    "settings.snippet.list.button.add.help": {
        "ko": "새 스니펫 추가", "en": "Add New Snippet",
        "ja": "新しいスニペットを追加", "de": "Neues Snippet hinzufügen",
        "es": "Añadir nuevo fragmento", "fr": "Ajouter un nouvel extrait",
        "zh-Hans": "添加新片段", "zh-Hant": "新增片段"
    },
    "settings.snippet.list.context.delete": {
        "ko": "삭제", "en": "Delete",
        "ja": "削除", "de": "Löschen",
        "es": "Eliminar", "fr": "Supprimer",
        "zh-Hans": "删除", "zh-Hant": "刪除"
    },
    "settings.snippet.list.empty": {
        "ko": "스니펫이 없습니다", "en": "No snippets found",
        "ja": "スニペットがありません", "de": "Keine Snippets gefunden",
        "es": "No se encontraron fragmentos", "fr": "Aucun extrait trouvé",
        "zh-Hans": "没有找到片段", "zh-Hant": "沒有找到片段"
    },
    "settings.snippet.list.header.abbreviation": {
        "ko": "단축어", "en": "Abbreviation",
        "ja": "略語", "de": "Abkürzung",
        "es": "Abreviatura", "fr": "Abréviation",
        "zh-Hans": "缩写", "zh-Hant": "縮寫"
    },
    "settings.snippet.list.header.content": {
        "ko": "내용", "en": "Content",
        "ja": "内容", "de": "Inhalt",
        "es": "Contenido", "fr": "Contenu",
        "zh-Hans": "内容", "zh-Hant": "內容"
    },
    "settings.snippet.list.header.name": {
        "ko": "이름", "en": "Name",
        "ja": "名前", "de": "Name",
        "es": "Nombre", "fr": "Nom",
        "zh-Hans": "名称", "zh-Hant": "名稱"
    },
    "settings.snippet.placeholder.keyword": {
        "ko": "키워드", "en": "Keyword", "ja": "キーワード", "zh-Hans": "关键词"
    },
    "settings.snippet.placeholder.name": {
        "ko": "이름 (설명)", "en": "Name (Description)", "ja": "名前 (説明)",
        "zh-Hans": "名称 (说明)"
    },
    "settings.snippet.placeholder.select_folder": {
        "ko": "폴더를 선택하세요", "en": "Select a folder",
        "ja": "フォルダを選択", "de": "Ordner auswählen",
        "es": "Seleccione una carpeta", "fr": "Sélectionnez un dossier",
        "zh-Hans": "选择文件夹", "zh-Hant": "選擇資料夾"
    },
    "settings.snippet.section.basic": {
        "ko": "기본 정보", "en": "Basic Information", "ja": "基本情報",
        "zh-Hans": "基本信息"
    },
    "settings.snippet.title.edit": {
        "ko": "스니펫 편집", "en": "Edit Snippet", "ja": "スニ펫を編集",
        "zh-Hans": "编辑片段"
    },
    "settings.snippet.title.new": {
        "ko": "새 스니펫", "en": "New Snippet", "ja": "新しいスニペット",
        "zh-Hans": "新片段"
    },
    "settings.snippets.button.open_folder": {
        "ko": "폴더 열기", "en": "Open Folder",
        "ja": "フォルダを開く", "de": "Ordner öffnen",
        "es": "Abrir carpeta", "fr": "Ouvrir le dossier",
        "zh-Hans": "打开文件夹", "zh-Hant": "開啟資料夾"
    },
    "settings.snippets.empty_folder": {
        "ko": "폴더를 선택하세요", "en": "Select a folder",
        "ja": "フォルダを選択してください", "de": "Wählen Sie einen Ordner",
        "es": "Seleccione una carpeta", "fr": "Sélectionnez un dossier",
        "zh-Hans": "请选择文件夹", "zh-Hant": "請選擇資料夾"
    },
    "settings.snippets.header.folder_name": {
        "ko": "폴더명", "en": "Folder Name",
        "ja": "フォルダ名", "de": "Ordnername",
        "es": "Nombre de carpeta", "fr": "Nom du dossier",
        "zh-Hans": "文件夹名", "zh-Hant": "資料夾名稱"
    },
    "settings.snippets.label.no_folders": {
        "ko": "표시할 폴더가 없습니다", "en": "No folders to display",
        "ja": "表示するフォルダがありません", "de": "Keine Ordner zum Anzeigen",
        "es": "No hay carpetas para mostrar", "fr": "Aucun dossier à afficher",
        "zh-Hans": "没有要显示的文件夹", "zh-Hant": "沒有要顯示的資料夾"
    },
    "settings.snippets.placeholder.new_folder": {
        "ko": "새 폴더명", "en": "New Folder Name",
        "ja": "新しいフォルダ名", "de": "Neuer Ordnername",
        "es": "Nuevo nombre de carpeta", "fr": "Nouveau nom de dossier",
        "zh-Hans": "新文件夹名", "zh-Hant": "新資料夾名稱"
    },

    # === Tab Names ===
    "settings.tab.advanced": {
        "ko": "고급", "en": "Advanced",
        "ja": "詳細", "de": "Erweitert",
        "es": "Avanzado", "fr": "Avancé",
        "zh-Hans": "高级", "zh-Hant": "進階"
    },
    "settings.tab.folders": {
        "ko": "폴더", "en": "Folders",
        "ja": "フォルダ", "de": "Ordner",
        "es": "Carpetas", "fr": "Dossiers",
        "zh-Hans": "文件夹", "zh-Hant": "資料夾"
    },
    "settings.tab.general": {
        "ko": "일반", "en": "General",
        "ja": "一般", "de": "Allgemein",
        "es": "General", "fr": "Général",
        "zh-Hans": "常规", "zh-Hant": "一般"
    },
    "settings.tab.history": {
        "ko": "히스토리", "en": "History",
        "ja": "履歴", "de": "Verlauf",
        "es": "Historial", "fr": "Historique",
        "zh-Hans": "历史", "zh-Hant": "歷史"
    },
    "settings.tab.snippets": {
        "ko": "스니펫", "en": "Snippets",
        "ja": "スニペット", "de": "Snippets",
        "es": "Fragmentos", "fr": "Extraits",
        "zh-Hans": "片段", "zh-Hant": "片段"
    },
    "settings.title": {
        "ko": "fSnippet 설정", "en": "fSnippet Settings",
        "ja": "fSnippet 設定", "de": "fSnippet-Einstellungen",
        "es": "Configuración de fSnippet", "fr": "Paramètres de fSnippet",
        "zh-Hans": "fSnippet设置", "zh-Hant": "fSnippet設定"
    },
}

def escape_for_strings(s):
    """strings 파일용 이스케이프"""
    if not s:
        return ""
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\t', '\\t')

def parse_strings_file(filepath):
    """strings 파일 파싱"""
    entries = {}
    if not os.path.exists(filepath):
        return entries

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    pattern = r'"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;'
    for match in re.finditer(pattern, content):
        key = match.group(1).replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\')
        value = match.group(2).replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\')
        entries[key] = value

    return entries

def write_strings_file(filepath, entries, lang):
    """strings 파일 작성"""
    filename = os.path.basename(filepath)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(f'/* {filename} ({lang}) */\n')
        f.write(f'/* Translated for fSnippet */\n\n')

        for key in sorted(entries.keys()):
            value = entries[key]
            escaped_key = escape_for_strings(key)
            escaped_value = escape_for_strings(value)
            f.write(f'"{escaped_key}" = "{escaped_value}";\n')

def translate_settings(lang):
    """Settings.strings 파일 번역"""
    filepath = os.path.join(RESOURCES_DIR, f'{lang}.lproj', 'Settings.strings')

    if not os.path.exists(filepath):
        print(f'  File not found: {filepath}')
        return 0

    entries = parse_strings_file(filepath)
    updated = 0

    for key, translations in SETTINGS_TRANSLATIONS.items():
        if lang in translations:
            new_value = translations[lang]
            if key in entries:
                if entries[key] != new_value:
                    entries[key] = new_value
                    updated += 1
            else:
                entries[key] = new_value
                updated += 1

    write_strings_file(filepath, entries, lang)
    return updated

def main():
    languages = ['en', 'ko', 'ja', 'de', 'es', 'fr', 'zh-Hans', 'zh-Hant', 'ar', 'hi']

    print('=== Translating Settings.strings ===\n')

    total_updated = 0
    for lang in languages:
        updated = translate_settings(lang)
        print(f'{lang}: {updated} entries updated')
        total_updated += updated

    print(f'\n=== Total: {total_updated} entries updated ===')

if __name__ == '__main__':
    main()
