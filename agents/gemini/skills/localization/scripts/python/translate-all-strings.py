#!/usr/bin/env python3
"""
모든 .strings 파일을 완전히 번역하는 스크립트
한국어(ko)를 기준으로 다른 언어로 번역
"""
import os
import re

RESOURCES_DIR = 'fSnippet/fSnippet/Resources'

# 완전한 번역 사전 (키 -> {언어: 번역})
TRANSLATIONS = {
    # === Alert Common ===
    "Cancel": {
        "ko": "취소", "en": "Cancel", "ja": "キャンセル",
        "de": "Abbrechen", "es": "Cancelar", "fr": "Annuler",
        "zh-Hans": "取消", "zh-Hant": "取消",
        "ar": "إلغاء", "hi": "रद्द करें"
    },
    "Paste": {
        "ko": "붙여넣기", "en": "Paste", "ja": "貼り付け",
        "de": "Einfügen", "es": "Pegar", "fr": "Coller",
        "zh-Hans": "粘贴", "zh-Hant": "貼上",
        "ar": "لصق", "hi": "चिपकाएं"
    },
    "100 characters": {
        "ko": "100자", "en": "100 characters", "ja": "100文字",
        "de": "100 Zeichen", "es": "100 caracteres", "fr": "100 caractères",
        "zh-Hans": "100个字符", "zh-Hant": "100個字元"
    },
    "100 entries": {
        "ko": "100개 항목", "en": "100 entries", "ja": "100件",
        "de": "100 Einträge", "es": "100 entradas", "fr": "100 entrées",
        "zh-Hans": "100条", "zh-Hant": "100筆"
    },

    # === Delete/History ===
    "Delete %lld Items": {
        "ko": "%lld개 항목 삭제", "en": "Delete %lld Items", "ja": "%lld件を削除",
        "de": "%lld Elemente löschen", "es": "Eliminar %lld elementos", "fr": "Supprimer %lld éléments",
        "zh-Hans": "删除%lld项", "zh-Hant": "刪除%lld項",
        "ar": "حذف %lld عنصر", "hi": "%lld आइटम हटाएं"
    },
    "Delete all items matching query?": {
        "ko": "검색 결과와 일치하는 모든 항목을 삭제할까요?", "en": "Delete all items matching query?",
        "ja": "検索結果に一致するすべてのアイテムを削除しますか？",
        "de": "Alle übereinstimmenden Elemente löschen?", "es": "¿Eliminar todos los elementos coincidentes?",
        "fr": "Supprimer tous les éléments correspondants ?",
        "zh-Hans": "删除所有匹配的项目？", "zh-Hant": "刪除所有符合的項目？"
    },
    "EDITING": {
        "ko": "편집 중", "en": "EDITING", "ja": "編集中",
        "de": "BEARBEITEN", "es": "EDITANDO", "fr": "ÉDITION",
        "zh-Hans": "编辑中", "zh-Hant": "編輯中",
        "ar": "تحرير", "hi": "संपादन"
    },
    "English": {
        "ko": "English", "en": "English", "ja": "English",
        "de": "English", "es": "English", "fr": "English",
        "zh-Hans": "English", "zh-Hant": "English",
        "ar": "English", "hi": "English"
    },
    "Enhanced Key Rendering Result": {
        "ko": "향상된 키 렌더링 결과", "en": "Enhanced Key Rendering Result", "ja": "拡張キーレンダリング結果",
        "de": "Erweitertes Tastenergebnis", "es": "Resultado de tecla mejorado", "fr": "Résultat de rendu de touche amélioré",
        "zh-Hans": "增强键渲染结果", "zh-Hant": "增強鍵渲染結果"
    },
    "File List": {
        "ko": "파일 목록", "en": "File List", "ja": "ファイルリスト",
        "de": "Dateiliste", "es": "Lista de archivos", "fr": "Liste de fichiers",
        "zh-Hans": "文件列表", "zh-Hant": "檔案清單",
        "ar": "قائمة الملفات", "hi": "फ़ाइल सूची"
    },
    "Hotkey": {
        "ko": "단축키", "en": "Hotkey", "ja": "ホットキー",
        "de": "Hotkey", "es": "Tecla de acceso", "fr": "Raccourci",
        "zh-Hans": "热键", "zh-Hant": "快捷鍵",
        "ar": "مفتاح التشغيل السريع", "hi": "हॉटकी"
    },
    "Image (%@)": {
        "ko": "이미지 (%@)", "en": "Image (%@)", "ja": "画像 (%@)",
        "de": "Bild (%@)", "es": "Imagen (%@)", "fr": "Image (%@)",
        "zh-Hans": "图片 (%@)", "zh-Hant": "圖片 (%@)",
        "ar": "صورة (%@)", "hi": "छवि (%@)"
    },
    "Image load failed": {
        "ko": "이미지 로드 실패", "en": "Image load failed", "ja": "画像の読み込みに失敗",
        "de": "Bild konnte nicht geladen werden", "es": "Error al cargar imagen", "fr": "Échec du chargement de l'image",
        "zh-Hans": "图片加载失败", "zh-Hant": "圖片載入失敗",
        "ar": "فشل تحميل الصورة", "hi": "छवि लोड विफल"
    },
    "Image not found": {
        "ko": "이미지를 찾을 수 없음", "en": "Image not found", "ja": "画像が見つかりません",
        "de": "Bild nicht gefunden", "es": "Imagen no encontrada", "fr": "Image introuvable",
        "zh-Hans": "看不到图片", "zh-Hant": "看不到圖片",
        "ar": "لم يتم العثور على الصورة", "hi": "छवि नहीं मिली"
    },
    "Invalid File List": {
        "ko": "잘못된 파일 목록", "en": "Invalid File List", "ja": "無効なファイルリスト",
        "de": "Ungültige Dateiliste", "es": "Lista de archivos inválida", "fr": "Liste de fichiers invalide",
        "zh-Hans": "无效的文件列表", "zh-Hant": "無效的檔案清單",
        "ar": "قائمة ملفات غير صالحة", "hi": "अमान्य फ़ाइल सूची"
    },
    "No preview available": {
        "ko": "미리보기 없음", "en": "No preview available", "ja": "プレビューなし",
        "de": "Keine Vorschau verfügbar", "es": "Vista previa no disponible", "fr": "Aperçu non disponible",
        "zh-Hans": "无预览", "zh-Hant": "無預覽",
        "ar": "لا توجد معاينة متاحة", "hi": "कोई पूर्वावलोकन उपलब्ध नहीं"
    },
    "Prefix": {
        "ko": "접두사", "en": "Prefix", "ja": "プレフィックス",
        "de": "Präfix", "es": "Prefijo", "fr": "Préfixe",
        "zh-Hans": "前缀", "zh-Hant": "前綴",
        "ar": "بادئة", "hi": "उपसर्ग"
    },
    "Search history...": {
        "ko": "히스토리 검색...", "en": "Search history...", "ja": "履歴を検索...",
        "de": "Verlauf durchsuchen...", "es": "Buscar historial...", "fr": "Rechercher l'historique...",
        "zh-Hans": "搜索历史...", "zh-Hant": "搜尋歷史...",
        "ar": "البحث في السجل...", "hi": "इतिहास खोजें..."
    },
    "Select All": {
        "ko": "모두 선택", "en": "Select All", "ja": "すべて選択",
        "de": "Alle auswählen", "es": "Seleccionar todo", "fr": "Tout sélectionner",
        "zh-Hans": "全选", "zh-Hant": "全選",
        "ar": "تحديد الكل", "hi": "सभी चुनें"
    },
    "Show Keyboard Shortcuts": {
        "ko": "키보드 단축키 표시", "en": "Show Keyboard Shortcuts", "ja": "キーボードショートカットを表示",
        "de": "Tastaturkürzel anzeigen", "es": "Mostrar atajos de teclado", "fr": "Afficher les raccourcis clavier",
        "zh-Hans": "显示键盘快捷键", "zh-Hant": "顯示鍵盤快捷鍵",
        "ar": "عرض اختصارات لوحة المفاتيح", "hi": "कीबोर्ड शॉर्टकट दिखाएं"
    },
    "Suffix": {
        "ko": "접미사", "en": "Suffix", "ja": "サフィックス",
        "de": "Suffix", "es": "Sufijo", "fr": "Suffixe",
        "zh-Hans": "后缀", "zh-Hant": "後綴",
        "ar": "لاحقة", "hi": "प्रत्यय"
    },
    "System Default": {
        "ko": "시스템 기본값", "en": "System Default", "ja": "システムデフォルト",
        "de": "Systemstandard", "es": "Predeterminado del sistema", "fr": "Par défaut du système",
        "zh-Hans": "系统默认", "zh-Hant": "系統預設",
        "ar": "الافتراضي للنظام", "hi": "सिस्टम डिफ़ॉल्ट"
    },
    "Text": {
        "ko": "텍스트", "en": "Text", "ja": "テキスト",
        "de": "Text", "es": "Texto", "fr": "Texte",
        "zh-Hans": "文本", "zh-Hant": "文字",
        "ar": "نص", "hi": "पाठ"
    },
    "Unknown Content": {
        "ko": "알 수 없는 콘텐츠", "en": "Unknown Content", "ja": "不明なコンテンツ",
        "de": "Unbekannter Inhalt", "es": "Contenido desconocido", "fr": "Contenu inconnu",
        "zh-Hans": "未知内容", "zh-Hant": "未知內容",
        "ar": "محتوى غير معروف", "hi": "अज्ञात सामग्री"
    },

    # === Alert keys ===
    "alert.clear_complete.title": {
        "ko": "삭제 완료", "en": "Deletion Complete", "ja": "削除完了",
        "de": "Löschung abgeschlossen", "es": "Eliminación completada", "fr": "Suppression terminée",
        "zh-Hans": "删除完成", "zh-Hant": "刪除完成",
        "ar": "اكتمال الحذف", "hi": "हटाना पूर्ण"
    },

    # === Issue 548: Alert Localization ===
    "alert.shortcut_conflict.title": {
        "ko": "단축키 중복 경고", "en": "Shortcut Conflict Warning",
        "ja": "ショートカット重複警告", "de": "Tastenkombinations-Konflikt-Warnung",
        "es": "Advertencia de conflicto de atajo", "fr": "Avertissement de conflit de raccourci",
        "zh-Hans": "快捷键冲突警告", "zh-Hant": "快捷鍵衝突警告",
        "ar": "تحذير من تعارض الاختصار", "hi": "शॉर्टकट संघर्ष चेतावनी"
    },
    "alert.settings_folder_not_found.title": {
        "ko": "설정 폴더를 찾을 수 없습니다", "en": "Settings Folder Not Found",
        "ja": "設定フォルダが見つかりません", "de": "Einstellungsordner nicht gefunden",
        "es": "No se encontró la carpeta de configuración", "fr": "Dossier de paramètres introuvable",
        "zh-Hans": "未找到设置文件夹", "zh-Hant": "未找到設定資料夾",
        "ar": "مجلد الإعدادات غير موجود", "hi": "सेटिंग्स फ़ोल्डर नहीं मिला"
    },
    "alert.settings_folder_not_found.message": {
        "ko": "기본 설정 폴더가 존재하지 않습니다. 새로운 폴더를 생성하시겠습니까, 아니면 기존 폴더를 선택하시겠습니까?",
        "en": "The default settings folder does not exist. Would you like to create a new folder or select an existing one?",
        "ja": "デフォルトの設定フォルダが存在しません。新しいフォルダを作成しますか、それとも既存のフォルダを選択しますか？",
        "de": "Der Standard-Einstellungsordner existiert nicht. Möchten Sie einen neuen Ordner erstellen oder einen vorhandenen auswählen?",
        "es": "La carpeta de configuración predeterminada no existe. ¿Desea crear una carpeta nueva o seleccionar una existente?",
        "fr": "Le dossier de paramètres par défaut n'existe pas. Voulez-vous créer un nouveau dossier ou en sélectionner un existant ?",
        "zh-Hans": "默认设置文件夹不存在。您要创建新文件夹还是选择现有文件夹？",
        "zh-Hant": "預設設定資料夾不存在。您要建立新資料夾還是選擇現유資料夾？",
        "ar": "مجلد الإعدادات الافتراضي غير موجود. هل ترغب في إنشاء مجلد جديد أو تحديد مجلد موجود؟",
        "hi": "डिफ़ॉल्ट सेटिंग्स फ़ोल्डर मौजूद नहीं है. क्या आप एक नया फ़ोल्डर बनाना चाहेंगे या किसी मौजूदा को चुनना चाहेंगे?"
    },
    "btn.create_folder": {
        "ko": "폴더 생성", "en": "Create Folder", "ja": "フォルダ作成",
        "de": "Ordner erstellen", "es": "Crear carpeta", "fr": "Créer un dossier",
        "zh-Hans": "创建文件夹", "zh-Hant": "建立資料夾",
        "ar": "إنشاء مجلد", "hi": "फ़ोल्डर बनाएं"
    },
    "btn.select_folder": {
        "ko": "폴더 선택", "en": "Select Folder", "ja": "フォルダ選択",
        "de": "Ordner auswählen", "es": "Seleccionar carpeta", "fr": "Sélectionner un dossier",
        "zh-Hans": "选择文件夹", "zh-Hant": "選擇資料夾",
        "ar": "حدد المجلد", "hi": "फ़ोल्डर चुनें"
    },
    "alert.folder_selection_error.title": {
        "ko": "폴더 선택 오류", "en": "Folder Selection Error",
        "ja": "フォルダ選択エラー", "de": "Fehler bei der Ordnerauswahl",
        "es": "Error de selección de carpeta", "fr": "Erreur de sélection de dossier",
        "zh-Hans": "文件夹选择错误", "zh-Hant": "資料夾選擇錯誤",
        "ar": "خطأ في تحديد المجلد", "hi": "फ़ोल्डर चयन त्रुटि"
    },
    "alert.folder_selection_error.message": {
        "ko": "유효하지 않은 폴더입니다. 스니펫 폴더가 맞는지 확인해주세요.",
        "en": "Invalid folder. Please check if it is a valid snippet folder.",
        "ja": "無効なフォルダです. スニペット フォルダであるか確認してください.",
        "de": "Ungültiger Ordner. Bitte prüfen Sie, ob es sich um einen gültigen Snippet-Ordner handelt.",
        "es": "Carpeta no válida. Compruebe si es una carpeta de fragmentos válida.",
        "fr": "Dossier non valide. Veuillez vérifier s'il s'agit d'un dossier d'extraits valide.",
        "zh-Hans": "文件夹无效. 请检查是否为有效的片段文件夹.",
        "zh-Hant": "資料夾無效. 請檢查是否為有效的片段資料夾.",
        "ar": "المجلد غير صالح. يرجى التحقق مما إذا كان مجلد مقتطفات صالحًا.",
        "hi": "अमान्य फ़ोल्डर. कृपया जाँचें कि क्या यह एक वैध स्निपेट फ़ोल्डर है."
    },
    "alert.validation_error": {
        "ko": "유효성 검사 오류:", "en": "Validation Error:", "ja": "検証エラー：",
        "de": "Validierungsfehler:", "es": "Error de validación:", "fr": "Erreur de validation :",
        "zh-Hans": "验证错误：", "zh-Hant": "驗證錯誤：",
        "ar": "خطأ في التحقق:", "hi": "सत्यापन त्रुटि:"
    },

    # === History keys ===
    "history.alert.delete.message": {
        "ko": "이 작업은 되돌릴 수 없습니다.", "en": "This action cannot be undone.", "ja": "この操作は取り消せません。",
        "de": "Diese Aktion kann nicht rückgängig gemacht werden.", "es": "Esta acción no se puede deshacer.", "fr": "Cette action est irréversible.",
        "zh-Hans": "此操作无法撤销。", "zh-Hant": "此操作無法復原。",
        "ar": "لا يمكن التراجع عن هذا الإجراء.", "hi": "यह कार्रवाई पूर्ववत नहीं की जा सकती।"
    },
    "history.alert.delete.title": {
        "ko": "%lld개 항목을 삭제하시겠습니까?", "en": "Delete %lld items?", "ja": "%lld件を削除しますか？",
        "de": "%lld Elemente löschen?", "es": "¿Eliminar %lld elementos?", "fr": "Supprimer %lld éléments ?",
        "zh-Hans": "删除%lld项？", "zh-Hant": "刪除%lld項？",
        "ar": "حذف %lld عنصر؟", "hi": "%lld आइटम हटाएं?"
    },
    "history.alert.delete_matches.message": {
        "ko": "'%2$@'와(과) 일치하는 %1$lld개의 항목이 영구 삭제됩니다...",
        "en": "This will permanently delete %1$lld items that match '%2$@'...",
        "ja": "'%2$@'に一致する%1$lld件のアイテムが完全に削除されます...",
        "de": "%1$lld Elemente, die '%2$@' entsprechen, werden dauerhaft gelöscht...",
        "es": "Se eliminarán permanentemente %1$lld elementos que coinciden con '%2$@'...",
        "fr": "%1$lld éléments correspondant à '%2$@' seront définitivement supprimés...",
        "zh-Hans": "将永久删除与'%2$@'匹配的%1$lld项...",
        "zh-Hant": "將永久刪除與'%2$@'符合的%1$lld項...",
        "ar": "سيتم حذف %1$lld عنصر يطابق '%2$@' بشكل دائم...",
        "hi": "यह '%2$@' से मेल खाने वाले %1$lld आइटमों को स्थायी रूप से हटा देगा..."
    },
    "history.alert.delete_matches.title": {
        "ko": "검색 결과와 일치하는 모든 항목을 삭제할까요?", "en": "Delete all items matching query?",
        "ja": "検索結果に一致するすべてのアイテムを削除しますか？",
        "de": "Alle übereinstimmenden Elemente löschen?", "es": "¿Eliminar todos los elementos coincidentes?",
        "fr": "Supprimer tous les éléments correspondants ?",
        "zh-Hans": "删除所有匹配的项目？", "zh-Hant": "刪除所有符合的項目？",
        "ar": "حذف جميع العناصر المطابقة للاستعلام؟", "hi": "क्वेरी से मेल खाने वाले सभी आइटम हटाएं?"
    },
    "history.button.delete_matches": {
        "ko": "일치 항목 삭제", "en": "Delete Matches", "ja": "一致するものを削除",
        "de": "Übereinstimmungen löschen", "es": "Eliminar coincidencias", "fr": "Supprimer les correspondances",
        "zh-Hans": "删除匹配项", "zh-Hant": "刪除符合項",
        "ar": "حذف التطابقات", "hi": "मेल खाते हटाएं"
    },
    "history.help.title": {
        "ko": "키보드 단축키", "en": "Keyboard Shortcuts", "ja": "キーボードショートカット",
        "de": "Tastaturkürzel", "es": "Atajos de teclado", "fr": "Raccourcis clavier",
        "zh-Hans": "键盘快捷键", "zh-Hant": "鍵盤快捷鍵",
        "ar": "اختصارات لوحة المفاتيح", "hi": "कीबोर्ड शॉर्टकट"
    },
    "history.menu.copy": {
        "ko": "복사", "en": "Copy", "ja": "コピー",
        "de": "Kopieren", "es": "Copiar", "fr": "Copier",
        "zh-Hans": "复制", "zh-Hant": "複製",
        "ar": "نسخ", "hi": "कॉपी"
    },
    "history.menu.delete": {
        "ko": "삭제", "en": "Delete", "ja": "削除",
        "de": "Löschen", "es": "Eliminar", "fr": "Supprimer",
        "zh-Hans": "删除", "zh-Hant": "刪除",
        "ar": "حذف", "hi": "हटाएं"
    },
    "history.menu.register": {
        "ko": "스니펫으로 등록", "en": "Register as Snippet", "ja": "スニペットとして登録",
        "de": "Als Snippet registrieren", "es": "Registrar como fragmento", "fr": "Enregistrer comme extrait",
        "zh-Hans": "注册为片段", "zh-Hant": "註冊為片段",
        "ar": "تسجيل كمقتطف", "hi": "स्निपेट के रूप में पंजीकृत करें"
    },
    "history.status.active": {
        "ko": "활성", "en": "ACTIVE", "ja": "アクティブ",
        "de": "AKTIV", "es": "ACTIVO", "fr": "ACTIF",
        "zh-Hans": "活跃", "zh-Hant": "活躍",
        "ar": "نشط", "hi": "सक्रिय"
    },
    "history.status.items": {
        "ko": "개 항목", "en": "items", "ja": "件",
        "de": "Elemente", "es": "elementos", "fr": "éléments",
        "zh-Hans": "项", "zh-Hant": "項",
        "ar": "عناصر", "hi": "आइटम"
    },
    "history.status.paused": {
        "ko": "일시정지", "en": "PAUSED", "ja": "一時停止",
        "de": "PAUSIERT", "es": "PAUSADO", "fr": "PAUSE",
        "zh-Hans": "暂停", "zh-Hant": "暫停",
        "ar": "متوقف", "hi": "रोका गया"
    },
    "history.status.selected": {
        "ko": "개 선택됨", "en": "selected", "ja": "件選択",
        "de": "ausgewählt", "es": "seleccionados", "fr": "sélectionnés",
        "zh-Hans": "已选择", "zh-Hant": "已選擇",
        "ar": "المحدد", "hi": "चयनित"
    },
    "history.tooltip.delete_matches": {
        "ko": "현재 검색어와 일치하는 모든 항목 삭제", "en": "Delete all items matching the current search query",
        "ja": "現在の検索クエリに一致するすべてのアイテムを削除",
        "de": "Alle Elemente löschen, die der aktuellen Suchanfrage entsprechen",
        "es": "Eliminar todos los elementos que coinciden con la búsqueda actual",
        "fr": "Supprimer tous les éléments correspondant à la recherche actuelle",
        "zh-Hans": "删除所有匹配当前搜索的项目", "zh-Hant": "刪除所有符合目前搜尋的項目",
        "ar": "حذف جميع العناصر المطابقة لاستعلام البحث الحالي", "hi": "वर्तमान खोज क्वेरी से मेल खाने वाले सभी आइटम हटाएं"
    },
    "history.tooltip.delete_selected": {
        "ko": "선택한 항목 삭제", "en": "Delete Selected Items", "ja": "選択したアイテムを削除",
        "de": "Ausgewählte Elemente löschen", "es": "Eliminar elementos seleccionados", "fr": "Supprimer les éléments sélectionnés",
        "zh-Hans": "删除所选项目", "zh-Hant": "刪除所選項目",
        "ar": "حذف العناصر المحددة", "hi": "चयनित आइटम हटाएं"
    },
    "history.tooltip.pause": {
        "ko": "클립보드 수집 일시정지", "en": "Pause Clipboard Collection", "ja": "クリップボード収集を一時停止",
        "de": "Zwischenablage-Erfassung pausieren", "es": "Pausar recopilación del portapapeles", "fr": "Suspendre la collecte du presse-papiers",
        "zh-Hans": "暂停剪贴板收集", "zh-Hant": "暫停剪貼簿收集",
        "ar": "إيقاف مجموعة الحافظة مؤقتًا", "hi": "क्लिपबोर्ड संग्रह रोकें"
    },
    "history.tooltip.resume": {
        "ko": "클립보드 수집 재개", "en": "Resume Clipboard Collection", "ja": "クリップボード収集を再開",
        "de": "Zwischenablage-Erfassung fortsetzen", "es": "Reanudar recopilación del portapapeles", "fr": "Reprendre la collecte du presse-papiers",
        "zh-Hans": "恢复剪贴板收集", "zh-Hant": "恢復剪貼簿收集",
        "ar": "استئناف مجموعة الحافظة", "hi": "क्लिपबोर्ड संग्रह फिर से शुरू करें"
    },

    # === Menu keys (Issue 542) ===
    "menu.settings": {
        "ko": "설정...", "en": "Settings...", "ja": "設定...", "de": "Einstellungen...", "es": "Configuración...", "fr": "Paramètres...", "zh-Hans": "设置...", "zh-Hant": "設定...", "ar": "الإعدادات...", "hi": "से팅्स..."
    },
    "menu.reload_snippets": {
        "ko": "Snippet 다시 로드", "en": "Reload Snippets", "ja": "スニペットを再読み込み", "de": "Snippets neu laden", "es": "Recargar fragmentos", "fr": "Recharger les extraits", "zh-Hans": "重新加载片段", "zh-Hant": "重新載入片段", "ar": "إعادة تحميل المقتطفات", "hi": "स्निपेट पुनः लोड करें"
    },
    "menu.status_info": {
        "ko": "상태 정보", "en": "Status Info", "ja": "ステータス情報", "de": "Statusinformationen", "es": "Información de estado", "fr": "Informations d'état", "zh-Hans": "状态信息", "zh-Hant": "狀態資訊", "ar": "معلومات الحالة", "hi": "स्थिति सूचना"
    },
    "menu.show_popup": {
        "ko": "스니펫 팝업 열기", "en": "Open Snippet Popup", "ja": "スニペットポップアップを開く", "de": "Snippet-Popup öffnen", "es": "Abrir ventana de fragmentos", "fr": "Ouvrir le popup d'extrait", "zh-Hans": "打开片段弹出窗口", "zh-Hant": "開啟片段彈出視窗", "ar": "فتح نافذة المقتطفات المنبثقة", "hi": "स्निपेट पॉपअप खोलें"
    },
    "menu.show_clipboard": {
        "ko": "클립보드 히스토리 열기", "en": "Open Clipboard History", "ja": "クリップボード履歴を開く", "de": "Zwischenablage-Verlauf öffnen", "es": "Abrir historial del portapapeles", "fr": "Ouvrir l'historique du presse-papiers", "zh-Hans": "打开剪贴板历史", "zh-Hant": "開啟剪貼簿歷史", "ar": "فتح سجل الحافظة", "hi": "क्लिपबोर्ड इतिहास खोलें"
    },
    "menu.quit_app": {
        "ko": "fSnippet 종료", "en": "Quit fSnippet", "ja": "fSnippetを終了", "de": "fSnippet beenden", "es": "Salir de fSnippet", "fr": "Quitter fSnippet", "zh-Hans": "退出 fSnippet", "zh-Hant": "退出 fSnippet", "ar": "إغلاق fSnippet", "hi": "fSnippet से बाहर निकलें"
    },
    "menu.edit": {
        "ko": "편집", "en": "Edit", "ja": "編集", "de": "Bearbeiten", "es": "Editar", "fr": "Édition", "zh-Hans": "编辑", "zh-Hant": "編輯", "ar": "تحرير", "hi": "संपादित करें"
    },
    "menu.undo": {
        "ko": "실행 취소", "en": "Undo", "ja": "元に戻す", "de": "Rückgängig machen", "es": "Deshacer", "fr": "Annuler", "zh-Hans": "撤销", "zh-Hant": "復原", "ar": "تراجع", "hi": "पूर्ववत करें"
    },
    "menu.redo": {
        "ko": "다시 실행", "en": "Redo", "ja": "やり直し", "de": "Wiederholen", "es": "Rehacer", "fr": "Rétablir", "zh-Hans": "重做", "zh-Hant": "重做", "ar": "إعادة", "hi": "फिर से करें"
    },
    "menu.cut": {
        "ko": "오려두기", "en": "Cut", "ja": "切り取り", "de": "Ausschneiden", "es": "Cortar", "fr": "Couper", "zh-Hans": "剪切", "zh-Hant": "剪下", "ar": "قص", "hi": "काटें"
    },
    "menu.copy": {
        "ko": "복사", "en": "Copy", "ja": "コピー",
        "de": "Kopieren", "es": "Copiar", "fr": "Copier",
        "zh-Hans": "复制", "zh-Hant": "複製",
        "ar": "نسخ", "hi": "कॉपी"
    },
    "menu.paste": {
        "ko": "붙여넣기", "en": "Paste", "ja": "貼り付け", "de": "Einfügen", "es": "Pegar", "fr": "Coller", "zh-Hans": "粘贴", "zh-Hant": "貼上", "ar": "لصق", "hi": "चिपकाएं"
    },
    "menu.select_all": {
        "ko": "전체 선택", "en": "Select All", "ja": "すべて選択", "de": "Alle auswählen", "es": "Seleccionar todo", "fr": "Tout sélectionner", "zh-Hans": "全选", "zh-Hant": "全選", "ar": "تحديد الكل", "hi": "सभी चुनें"
    },
    "menu.delete": {
        "ko": "삭제", "en": "Delete", "ja": "削除",
        "de": "Löschen", "es": "Eliminar", "fr": "Supprimer",
        "zh-Hans": "删除", "zh-Hant": "刪除",
        "ar": "حذف", "hi": "हटाएं"
    },
    "menu.register": {
        "ko": "스니펫으로 등록", "en": "Register as Snippet", "ja": "スニペットとして登録",
        "de": "Als Snippet registrieren", "es": "Registrar como fragmento", "fr": "Enregistrer comme extrait",
        "zh-Hans": "注册为片段", "zh-Hant": "註冊為片段",
        "ar": "تسجيل كمقتطف", "hi": "स्निपेट के रूप में पंजीकृत करें"
    },

    # === Statusbar keys (Issue 542) ===
    "statusbar.clipboard_history": {
        "ko": "클립보드 히스토리...", "en": "Clipboard History...", "ja": "クリップボード履歴...", "de": "Zwischenablage-Verlauf...", "es": "Historial del portapapeles...", "fr": "Historique du presse-papiers...", "zh-Hans": "剪贴板历史...", "zh-Hant": "剪貼簿歷史...", "ar": "سجل الحافظة...", "hi": "क्लिपबोर्ड इतिहास..."
    },
    "statusbar.pause_clipboard": {
        "ko": "클립보드 수집 일시정지", "en": "Pause Clipboard Collection", "ja": "クリップボード収集を一時停止", "de": "Zwischenablage-Erfassung pausieren", "es": "Pausar recopilación del portapapeles", "fr": "Suspendre la collecte du presse-papiers", "zh-Hans": "暂停剪贴板收集", "zh-Hant": "暫停剪貼簿收集", "ar": "إيقاف مجموعة الحافظة مؤقتًا", "hi": "क्립보드 संग्रह रोकें"
    },
    "statusbar.resume_clipboard": {
        "ko": "클립보드 수집 재개", "en": "Resume Clipboard Collection", "ja": "クリップボード収集を再開", "de": "Zwischenablage-Erfassung fortsetzen", "es": "Reanudar recopilación del portapapeles", "fr": "Reprendre la collecte du presse-papiers", "zh-Hans": "恢复剪贴板收集", "zh-Hant": "恢復剪貼簿收集", "ar": "استئناف مجموعة الحافظة", "hi": "क्लिपबोर्ड संग्रह फिर से शुरू करें"
    },
    "statusbar.clear_logs": {
        "ko": "로그 클리어", "en": "Clear Logs", "ja": "ログをクリア", "de": "Protokolle löschen", "es": "Limpiar registros", "fr": "Effacer les journaux", "zh-Hans": "清除日志", "zh-Hant": "清除記錄", "ar": "مسح السجلات", "hi": "लॉग साफ़ करें"
    },
    "statusbar.quit": {
        "ko": "종료", "en": "Quit", "ja": "終了", "de": "Beenden", "es": "Salir", "fr": "Quitter", "zh-Hans": "退出", "zh-Hant": "退出", "ar": "إغلاق", "hi": "बाहर निकलें"
    },

    # === Notification keys (Issue 542) ===
    "notification.reload_success": {
        "ko": "Snippet이 다시 로드되었습니다.", "en": "Snippets have been reloaded.", "ja": "スニペットが再読み込みされました。", "de": "Snippets wurden neu geladen.", "es": "Se han recargado los fragmentos.", "fr": "Les extraits ont été rechargés.", "zh-Hans": "片段已重新加载。", "zh-Hant": "片段已重新載入。", "ar": "تم إعادة تحميل المقتطفات.", "hi": "स्निपेट पुनः लोड किए गए हैं।"
    },
    "notification.logs_cleared": {
        "ko": "로그가 클리어되었습니다.", "en": "Logs have been cleared.", "ja": "ログがクリアされました。", "de": "Protokolle wurden gelöscht.", "es": "Se han limpiado los registros.", "fr": "Les journaux ont été effacés.", "zh-Hans": "日志已清除。", "zh-Hant": "記錄已清除。", "ar": "تم مسح السجلات.", "hi": "लॉग साफ़ कर दिए गए हैं।"
    },
    "notification.clipboard_paused": {
        "ko": "클립보드 수집이 중단되었습니다.", "en": "Clipboard collection paused.", "ja": "クリップボード収集が一時停止されました。", "de": "Zwischenablage-Erfassung pausiert.", "es": "Recopilación del portapapeles pausada.", "fr": "Collecte du presse-papiers suspendue.", "zh-Hans": "剪贴板收集已暂停。", "zh-Hant": "剪貼簿收集已暫停。", "ar": "تم إيقاف مجموعة الحافظة مؤقتًا.", "hi": "क्लिपबोर्ड संग्रह रोक दिया गया।"
    },
    "notification.clipboard_resumed": {
        "ko": "클립보드 수집이 재개되었습니다.", "en": "Clipboard collection resumed.", "ja": "クリップボード収集が再開されました。", "de": "Zwischenablage-Erfassung fortgesetzt.", "es": "Recopilación del portapapeles reanudada.", "fr": "Collecte du presse-papiers reprise.", "zh-Hans": "剪贴板收集已恢复。", "zh-Hant": "剪貼簿收集已恢復.", "ar": "تم استئناف مجموعة الحافظة.", "hi": "क्लिपबोर्ड संग्रह फिर से शुरू किया गया।"
    },

    # === Toast keys (Issue 542) ===
    "toast.clipboard_paused": {
        "ko": "클립보드 일시정지", "en": "Clipboard Paused", "ja": "クリップボード一時停止", "de": "Zwischenablage pausiert", "es": "Portapapeles pausado", "fr": "Presse-papiers suspendu", "zh-Hans": "剪贴板已暂停", "zh-Hant": "剪貼簿已暫停", "ar": "تم إيقاف الحافظة مؤقتًا", "hi": "क्लिपबोर्ड रोका गया"
    },
    "toast.clipboard_resumed": {
        "ko": "클립보드 재개", "en": "Clipboard Resumed", "ja": "クリップボード再開", "de": "Zwischenablage fortgesetzt", "es": "Portapapeles reanudado", "fr": "Presse-papiers repris", "zh-Hans": "剪贴板已恢复", "zh-Hant": "剪貼簿已恢復", "ar": "تم استئناف الحافظة", "hi": "क्लिपबोर्ड फिर se शुरू"
    },

    # === Status Alert keys (Issue 542) ===
    "alert.status.title": {
        "ko": "fSnippet 상태 정보", "en": "fSnippet Status Info", "ja": "fSnippetステータス情報", "de": "fSnippet Statusinformationen", "es": "fSnippet Información de estado", "fr": "fSnippet Informations d'état", "zh-Hans": "fSnippet 状态信息", "zh-Hant": "fSnippet 狀態資訊", "ar": "معلومات الحالة fSnippet", "hi": "fSnippet स्थिति सूचना"
    },
    "alert.status.folder": {
        "ko": "📁 Snippet 폴더: %@", "en": "📁 Snippet Folder: %@", "ja": "📁 スニペットフォルダ: %@", "de": "📁 Snippet-Ordner: %@", "es": "📁 Carpeta de fragmentos: %@", "fr": "📁 Dossier d'extraits : %@", "zh-Hans": "📁 片段文件夹: %@", "zh-Hant": "📁 片段資料夾: %@", "ar": "📁 مجلد المقتطفات: %@", "hi": "📁 स्निपेट फ़ोल्डर: %@"
    },
    "alert.status.loaded_count": {
        "ko": "📄 로드된 Snippet: %lld개", "en": "📄 Loaded Snippets: %lld", "ja": "📄 ロードされたスニペット: %lld個", "de": "📄 Geladene Snippets: %lld", "es": "📄 Fragmentos cargados: %lld", "fr": "📄 Extraits chargés : %lld", "zh-Hans": "📄 已加载片段: %lld", "zh-Hant": "📄 已載入片段: %lld", "ar": "📄 المقتطفات المحملة: %lld", "hi": "📄 लोड किए गए स्निपेट: %lld"
    },
    "alert.status.index_stats": {
        "ko": "🗂 인덱스 통계:", "en": "🗂 Index Statistics:", "ja": "🗂 インデックス統計:", "de": "🗂 Index-Statistiken:", "es": "🗂 Estadísticas de índice:", "fr": "🗂 Statistiques d'index :", "zh-Hans": "🗂 索引统计:", "zh-Hant": "🗂 索引統計:", "ar": "🗂 إحصائيات الفهرس:", "hi": "🗂 सूचकांक आँकड़े:"
    },
    "alert.status.index_total": {
        "ko": "   - 총 항목: %lld개", "en": "   - Total Items: %lld", "ja": "   - 合計アイテム: %lld個", "de": "   - Gesamtanzahl: %lld", "es": "   - Total de elementos: %lld", "fr": "   - Total des éléments : %lld", "zh-Hans": "   - 总项: %lld", "zh-Hant": "   - 總項: %lld", "ar": "   - إجمالي العناصر: %lld", "hi": "   - कुल आइटम: %lld"
    },
    "alert.status.index_active": {
        "ko": "   - 활성 항목: %lld개", "en": "   - Active Items: %lld", "ja": "   - アクティブアイテム: %lld個", "de": "   - Aktive Elemente: %lld", "es": "   - Elementos activos: %lld", "fr": "   - Éléments actifs : %lld", "zh-Hans": "   - 活跃项: %lld", "zh-Hant": "   - 活躍項: %lld", "ar": "   - العناصر النشطة: %lld", "hi": "   - सक्रिय आइटम: %lld"
    },
    "alert.status.index_cache": {
        "ko": "   - 캐시: %lld/%lld", "en": "   - Cache: %lld/%lld", "ja": "   - キャッシュ: %lld/%lld", "de": "   - Cache: %lld/%lld", "es": "   - Caché: %lld/%lld", "fr": "   - Cache : %lld/%lld", "zh-Hans": "   - 缓存: %lld/%lld", "zh-Hant": "   - 快取: %lld/%lld", "ar": "   - ذاكرة التخزين المؤقت: %lld/%lld", "hi": "   - 캐시: %lld/%lld"
    },

    # === Placeholder keys ===
    "placeholder.help.history": {
        "ko": "클립보드 히스토리 열기 (선택하여 삽입)", "en": "Open Clipboard History (Select to Insert)",
        "ja": "クリップボード履歴を開く（選択して挿入）",
        "de": "Zwischenablage-Verlauf öffnen (zum Einfügen auswählen)",
        "es": "Abrir historial del portapapeles (seleccionar para insertar)",
        "fr": "Ouvrir l'historique du presse-papiers (sélectionner pour insérer)",
        "zh-Hans": "打开剪贴板历史（选择插入）", "zh-Hant": "開啟剪貼簿歷史（選擇插入）",
        "ar": "فتح سجل الحافظة (حدد للإدراج)", "hi": "क्लिपबोर्ड इतिहास खोलें (डालने के लिए चुनें)"
    },
    "placeholder.label.preview": {
        "ko": "미리보기", "en": "Preview", "ja": "プレビュー",
        "de": "Vorschau", "es": "Vista previa", "fr": "Aperçu",
        "zh-Hans": "预览", "zh-Hant": "預覽",
        "ar": "معاينة", "hi": "पूर्वावलोकन"
    },
    "placeholder.window.title": {
        "ko": "플레이스홀더 입력", "en": "Placeholder Input", "ja": "プレースホルダー入力",
        "de": "Platzhalter-Eingabe", "es": "Entrada de marcador", "fr": "Saisie de marqueur",
        "zh-Hans": "占位符输入", "zh-Hant": "佔位符輸入",
        "ar": "إدخال عنصر نائب", "hi": "प्लेसहोल्डर इनपुट"
    },

    # === Popup keys ===
    "popup.button.select_all": {
        "ko": "모두 선택", "en": "Select All", "ja": "すべて選択",
        "de": "Alle auswählen", "es": "Seleccionar todo", "fr": "Tout sélectionner",
        "zh-Hans": "全选", "zh-Hant": "全選",
        "ar": "تحديد الكل", "hi": "सभी चुनें"
    },
    "popup.create.button": {
        "ko": "'%@' 생성", "en": "Create '%@'", "ja": "'%@'を作成",
        "de": "'%@' erstellen", "es": "Crear '%@'", "fr": "Créer '%@'",
        "zh-Hans": "创建'%@'", "zh-Hant": "建立'%@'",
        "ar": "إنشاء '%@'", "hi": "'%@' बनाएं"
    },
    "popup.create.help": {
        "ko": "Enter 또는 클릭하여 생성", "en": "Press Enter or Click to create", "ja": "Enterまたはクリックで作成",
        "de": "Enter drücken oder klicken zum Erstellen", "es": "Presiona Enter o haz clic para crear",
        "fr": "Appuyez sur Entrée ou cliquez pour créer",
        "zh-Hans": "按Enter或点击创建", "zh-Hant": "按Enter或點擊建立",
        "ar": "اضغط على Enter أو انقر للإنشاء", "hi": "बनाने के लिए Enter दबाएं या क्लिक करें"
    },
    "popup.create.prefix": {
        "ko": "생성", "en": "Create", "ja": "作成",
        "de": "Erstellen", "es": "Crear", "fr": "Créer",
        "zh-Hans": "创建", "zh-Hant": "建立",
        "ar": "إنشاء", "hi": "बनाएं"
    },
    "popup.empty.no_results": {
        "ko": "결과 없음", "en": "No Results", "ja": "結果なし",
        "de": "Keine Ergebnisse", "es": "Sin resultados", "fr": "Aucun résultat",
        "zh-Hans": "无结果", "zh-Hant": "無結果",
        "ar": "لا توجد نتائج", "hi": "कोई परिणाम नहीं"
    },
    "popup.search.no_results": {
        "ko": "결과 없음", "en": "No Results", "ja": "結果なし",
        "de": "Keine Ergebnisse", "es": "Sin resultados", "fr": "Aucun résultat",
        "zh-Hans": "无结果", "zh-Hant": "無結果",
        "ar": "لا توجد نتائج", "hi": "कोई परिणाम नहीं"
    },
    "popup.search.placeholder": {
        "ko": "검색...", "en": "Search...", "ja": "検索...",
        "de": "Suchen...", "es": "Buscar...", "fr": "Rechercher...",
        "zh-Hans": "搜索...", "zh-Hant": "搜尋...",
        "ar": "بحث...", "hi": "खोजें..."
    },

    # === Viewer keys ===
    "viewer.action.close": {
        "ko": "창 닫기", "en": "Close Window", "ja": "ウィンドウを閉じる",
        "de": "Fenster schließen", "es": "Cerrar ventana", "fr": "Fermer la fenêtre",
        "zh-Hans": "关闭窗口", "zh-Hant": "關閉視窗",
        "ar": "إغلاق النافذة", "hi": "विंडो बंद करें"
    },
    "viewer.action.copy_paste": {
        "ko": "복사 / 붙여넣기", "en": "Copy / Paste", "ja": "コピー / 貼り付け",
        "de": "Kopieren / Einfügen", "es": "Copiar / Pegar", "fr": "Copier / Coller",
        "zh-Hans": "复制 / 粘贴", "zh-Hant": "複製 / 貼上",
        "ar": "نسخ / لصق", "hi": "कॉपी / पेस्ट"
    },
    "viewer.action.delete": {
        "ko": "항목 삭제", "en": "Delete Item", "ja": "アイテムを削除",
        "de": "Element löschen", "es": "Eliminar elemento", "fr": "Supprimer l'élément",
        "zh-Hans": "删除项目", "zh-Hant": "刪除項目",
        "ar": "حذف العنصر", "hi": "आइटम हटाएं"
    },
    "viewer.action.preview_edit": {
        "ko": "미리보기 / 편집", "en": "Preview / Edit", "ja": "プレビュー / 編集",
        "de": "Vorschau / Bearbeiten", "es": "Vista previa / Editar", "fr": "Aperçu / Modifier",
        "zh-Hans": "预览 / 编辑", "zh-Hant": "預覽 / 編輯",
        "ar": "معاينة / تحرير", "hi": "पूर्वावलोकन / संपादन"
    },
    "viewer.action.quick_select": {
        "ko": "빠른 선택", "en": "Quick Select", "ja": "クイック選択",
        "de": "Schnellauswahl", "es": "Selección rápida", "fr": "Sélection rapide",
        "zh-Hans": "快速选择", "zh-Hant": "快速選擇",
        "ar": "تحديد سريع", "hi": "त्वरित चयन"
    },
    "viewer.action.register": {
        "ko": "스니펫 등록 및 편집", "en": "Register & Edit Snippet", "ja": "スニペット登録・編集",
        "de": "Snippet registrieren & bearbeiten", "es": "Registrar y editar fragmento", "fr": "Enregistrer et modifier l'extrait",
        "zh-Hans": "注册并编辑片段", "zh-Hant": "註冊並編輯片段",
        "ar": "تسجيل وتحرير المقتطف", "hi": "स्निपेट पंजीकृत करें और संपादित करें"
    },
    "viewer.action.toggle_pause": {
        "ko": "일시정지 전환", "en": "Toggle Pause", "ja": "一時停止を切り替え",
        "de": "Pause umschalten", "es": "Alternar pausa", "fr": "Basculer la pause",
        "zh-Hans": "切换暂停", "zh-Hant": "切換暫停",
        "ar": "تبديل الإيقاف المؤقت", "hi": "_रोक टॉगल करें"
    },
    "viewer.button.delete_matches": {
        "ko": "일치 항목 삭제", "en": "Delete Matches", "ja": "一致するものを削除",
        "de": "Übereinstimmungen löschen", "es": "Eliminar coincidencias", "fr": "Supprimer les correspondances",
        "zh-Hans": "删除匹配项", "zh-Hant": "刪除符合項",
        "ar": "حذف التطابقات", "hi": "मेल खाते हटाएं"
    },
    "viewer.footer.items": {
        "ko": "%lld개 항목", "en": "%lld items", "ja": "%lld件",
        "de": "%lld Elemente", "es": "%lld elementos", "fr": "%lld éléments",
        "zh-Hans": "%lld项", "zh-Hant": "%lld項",
        "ar": "%lld عنصر", "hi": "%lld आइटम"
    },
    "viewer.footer.selected": {
        "ko": "%lld개 선택됨", "en": "%lld selected", "ja": "%lld件選択",
        "de": "%lld ausgewählt", "es": "%lld seleccionados", "fr": "%lld sélectionnés",
        "zh-Hans": "已选择%lld项", "zh-Hant": "已選擇%lld項",
        "ar": "تم تحديد %lld", "hi": "%lld चयनित"
    },
    "viewer.help.delete_matches": {
        "ko": "현재 검색어와 일치하는 모든 항목 삭제", "en": "Delete all items matching the current search query",
        "ja": "現在の検索クエリに一致するすべてのアイテムを削除",
        "de": "Alle Elemente löschen, die der aktuellen Suchanfrage entsprechen",
        "es": "Eliminar todos los elementos que coinciden con la búsqueda actual",
        "fr": "Supprimer tous les éléments correspondant à la recherche actuelle",
        "zh-Hans": "删除所有匹配当前搜索的项目", "zh-Hant": "刪除所有符合目前搜尋的項目",
        "ar": "حذف جميع العناصر المطابقة لاستعلام البحث الحالي", "hi": "वर्तमान खोज क्वेरी से मेल खाने वाले सभी आइटम हटाएं"
    },
    "viewer.help.pause": {
        "ko": "클립보드 수집 일시정지", "en": "Pause Clipboard Collection", "ja": "クリップボード収集を一時停止",
        "de": "Zwischenablage-Erfassung pausieren", "es": "Pausar recopilación del portapapeles", "fr": "Suspendre la collecte du presse-papiers",
        "zh-Hans": "暂停剪贴板收集", "zh-Hant": "暫停剪貼簿收集",
        "ar": "إيقاف مجموعة الحافظة مؤقتًا", "hi": "क्लिपबोर्ड संग्रह रोकें"
    },
    "viewer.help.resume": {
        "ko": "클립보드 수집 재개", "en": "Resume Clipboard Collection", "ja": "クリップボード収集を再開",
        "de": "Zwischenablage-Erfassung fortsetzen", "es": "Reanudar recopilación del portapapeles", "fr": "Reprendre la collecte du presse-papiers",
        "zh-Hans": "恢复剪贴板收集", "zh-Hant": "恢復剪貼簿收集",
        "ar": "استئناف مجموعة الحافظة", "hi": "क्लिपबोर्ड संग्रह फिर से शुरू करें"
    },
    "viewer.help.shortcuts": {
        "ko": "키보드 단축키", "en": "Keyboard Shortcuts", "ja": "キーボードショートカット",
        "de": "Tastaturkürzel", "es": "Atajos de teclado", "fr": "Raccourcis clavier",
        "zh-Hans": "键盘快捷键", "zh-Hant": "鍵盤快捷鍵",
        "ar": "اختصارات لوحة المفاتيح", "hi": "कीबोर्ड शॉर्टकट"
    },
    "viewer.key.backspace": {
        "ko": "⌫ (백스페이스)", "en": "⌫ (Backspace)", "ja": "⌫ (バックスペース)",
        "de": "⌫ (Rücktaste)", "es": "⌫ (Retroceso)", "fr": "⌫ (Retour arrière)",
        "zh-Hans": "⌫ (退格)", "zh-Hant": "⌫ (退格)",
        "ar": "⌫ (مسافة للخلف)", "hi": "⌫ (बैकस्पेस)"
    },
    "viewer.key.enter": {
        "ko": "↵ (엔터)", "en": "↵ (Enter)", "ja": "↵ (エンター)",
        "de": "↵ (Eingabe)", "es": "↵ (Intro)", "fr": "↵ (Entrée)",
        "zh-Hans": "↵ (回车)", "zh-Hant": "↵ (Enter)",
        "ar": "↵ (إدخال)", "hi": "↵ (दर्ज करें)"
    },
    "viewer.key.esc": {
        "ko": "Esc", "en": "Esc", "ja": "Esc",
        "de": "Esc", "es": "Esc", "fr": "Échap",
        "zh-Hans": "Esc", "zh-Hant": "Esc",
        "ar": "Esc", "hi": "Esc"
    },
    "viewer.key.tab": {
        "ko": "Tab", "en": "Tab", "ja": "Tab",
        "de": "Tab", "es": "Tab", "fr": "Tab",
        "zh-Hans": "Tab", "zh-Hant": "Tab",
        "ar": "Tab", "hi": "Tab"
    },
    "viewer.status.active": {
        "ko": "활성", "en": "ACTIVE", "ja": "アクティブ",
        "de": "AKTIV", "es": "ACTIVO", "fr": "ACTIF",
        "zh-Hans": "活跃", "zh-Hant": "活躍",
        "ar": "نشط", "hi": "सक्रिय"
    },
    "viewer.status.paused": {
        "ko": "일시정지", "en": "PAUSED", "ja": "一時停止",
        "de": "PAUSIERT", "es": "PAUSADO", "fr": "PAUSE",
        "zh-Hans": "暂停", "zh-Hant": "暫停",
        "ar": "متوقف", "hi": "रोका गया"
    },

    # === Korean UI texts - need translation ===
    "폴더명은 최소 하나 이상의 대문자가 포함되거나 _(언더바)로 시작해야 합니다.": {
        "ko": "폴더명은 최소 하나 이상의 대문자가 포함되거나 _(언더바)로 시작해야 합니다.",
        "en": "Folder name must contain at least one uppercase letter or start with an underscore (_).",
        "ja": "フォルダ名には、少なくとも1つの大文字が含まれているか、アンダースコア（_）で始まる必要があります。",
        "de": "Der Ordnername muss mindestens einen Großbuchstaben enthalten oder mit einem Unterstrich (_) beginnen.",
        "es": "El nombre de la carpeta debe contener al menos una letra mayúscula o comenzar con un guion bajo (_).",
        "fr": "Le nom du dossier doit contenir au moins une lettre majuscule ou commencer par un trait de soulignement (_).",
        "zh-Hans": "文件夹名称必须包含至少一个大写字母或以下划线（_）开头。",
        "zh-Hant": "資料夾名稱必須包含至少一個大寫字母或以下劃線（_）開頭。",
        "ar": "يجب أن يحتوي اسم المجلد على حرف كبير واحد على الأقل أو يبدأ بشرطة سفلية (_).",
        "hi": "फ़ोल्डर के नाम में कम से कम एक बड़ा अक्षर होना चाहिए या अंडरस्कोर (_) से शुरू होना चाहिए।"
    },
    "폴더 약어(대문자 조합)가 기존 폴더 '%@'와 중복됩니다.": {
        "ko": "폴더 약어(대문자 조합)가 기존 폴더 '%@'와 중복됩니다.",
        "en": "Folder abbreviation (uppercase combination) conflicts with existing folder '%@'.",
        "ja": "フォルダの略語（大文字の組み合わせ）が既存のフォルダ '%@' と重複しています。",
        "de": "Ordner-Abkürzung (Großbuchstaben-Kombination) steht in Konflikt mit dem vorhandenen Ordner '%@'.",
        "es": "La abreviatura de la carpeta (combinación de mayúsculas) entra en conflicto con la carpeta existente '%@'.",
        "fr": "L'abréviation du dossier (combinaison de majuscules) est en conflit avec le dossier existant '%@'.",
        "zh-Hans": "文件夹缩写（大写字母组合）与现有文件夹'%@'冲突。",
        "zh-Hant": "資料夾縮寫（大寫字母組合）與現有資料夾'%@'衝突。",
        "ar": "يتعارض اختصار المجلد (مجموعة الأحرف الكبيرة) مع المجلد الموجود '%@'.",
        "hi": "फ़ोल्डर का संक्षिप्त रूप (अपरकेस संयोजन) मौजूदा फ़ोल्डर '%@' के साथ स्वरूपित होता है।"
    },
    "Bias 값: %lld": {
        "ko": "Bias 값: %lld", "en": "Bias value: %lld", "ja": "Bias値: %lld",
        "de": "Bias-Wert: %lld", "es": "Valor de sesgo: %lld", "fr": "Valeur de biais: %lld",
        "zh-Hans": "Bias值: %lld", "zh-Hant": "Bias值: %lld",
        "ar": "قيمة التحيز: %lld", "hi": "पूर्वाग्रह मान: %lld"
    },
    "Tip: '_'로 시작하는 폴더는 대문자 자동 추출 규칙에서 제외됩니다.": {
        "ko": "Tip: '_'로 시작하는 폴더는 대문자 자동 추출 규칙에서 제외됩니다.",
        "en": "Tip: Folders starting with '_' are excluded from auto-uppercase extraction rules.",
        "ja": "ヒント：'_'で始まるフォルダは自動大文字抽出ルールから除外されます。",
        "de": "Tipp: Ordner, die mit '_' beginnen, werden von der automatischen Großbuchstabenregel ausgenommen.",
        "es": "Consejo: Las carpetas que empiezan con '_' se excluyen de las reglas de extracción automática.",
        "fr": "Astuce : Les dossiers commençant par '_' sont exclus des règles d'extraction automatique.",
        "zh-Hans": "提示：以'_'开头的文件夹不受自动大写提取规则影响。",
        "zh-Hant": "提示：以'_'開頭的資料夾不受自動大寫擷取規則影響。",
        "ar": "تلميح: المجلدات التي تبدأ بـ '_' مستبعدة من قواعد الاستخراج التلقائي للأحرف الكبيرة.",
        "hi": "टिप: '_' से शुरू होने वाले फ़ोल्डर स्वतः अपरकेस निष्कर्षण नियमों से बाहर रखे गए हैं।"
    },
    "Trigger Bias 사용자 지정": {
        "ko": "Trigger Bias 사용자 지정", "en": "Custom Trigger Bias", "ja": "トリガーバイアスのカスタマイズ",
        "de": "Benutzerdefinierter Trigger-Bias", "es": "Sesgo de activación personalizado", "fr": "Biais de déclenchement personnalisé",
        "zh-Hans": "自定义触发偏差", "zh-Hant": "自訂觸發偏差",
        "ar": "تحيز التشغيل المخصص", "hi": "कस्टम ट्रिगर पूर्वाग्रह"
    },

    # === Common Korean words ===
    "삭제": {
        "ko": "삭제", "en": "Delete", "ja": "削除",
        "de": "Löschen", "es": "Eliminar", "fr": "Supprimer",
        "zh-Hans": "删除", "zh-Hant": "刪除",
        "ar": "حذف", "hi": "हटाएं"
    },
    "취소": {
        "ko": "취소", "en": "Cancel", "ja": "キャンセル",
        "de": "Abbrechen", "es": "Cancelar", "fr": "Annuler",
        "zh-Hans": "取消", "zh-Hant": "取消",
        "ar": "إلغاء", "hi": "रद्द करें"
    },
    "확인": {
        "ko": "확인", "en": "Confirm", "ja": "確認",
        "de": "Bestätigen", "es": "Confirmar", "fr": "Confirmer",
        "zh-Hans": "确认", "zh-Hant": "確認",
        "ar": "تأكيد", "hi": "पुष्टि करें",
        "ar": "تأكيد", "hi": "पुष्टि करें"
    },
    "저장": {
        "ko": "저장", "en": "Save", "ja": "保存",
        "de": "Speichern", "es": "Guardar", "fr": "Enregistrer",
        "zh-Hans": "保存", "zh-Hant": "儲存",
        "ar": "حفظ", "hi": "सहेजें"
    },
    "닫기": {
        "ko": "닫기", "en": "Close", "ja": "閉じる",
        "de": "Schließen", "es": "Cerrar", "fr": "Fermer",
        "zh-Hans": "关闭", "zh-Hant": "關閉",
        "ar": "إغلاق", "hi": "बंद करें"
    },
    "추가": {
        "ko": "추가", "en": "Add", "ja": "追加",
        "de": "Hinzufügen", "es": "Añadir", "fr": "Ajouter",
        "zh-Hans": "添加", "zh-Hant": "新增",
        "ar": "إضافة", "hi": "जोड़ें"
    },
    "편집": {
        "ko": "편집", "en": "Edit", "ja": "編集",
        "de": "Bearbeiten", "es": "Editar", "fr": "Modifier",
        "zh-Hans": "编辑", "zh-Hant": "編輯",
        "ar": "تحرير", "hi": "संपादित करें"
    },
    "모두 선택": {
        "ko": "모두 선택", "en": "Select All", "ja": "すべて選択",
        "de": "Alle auswählen", "es": "Seleccionar todo", "fr": "Tout sélectionner",
        "zh-Hans": "全选", "zh-Hant": "全選"
    },
    "모두 해제": {
        "ko": "모두 해제", "en": "Deselect All", "ja": "すべて選択解除",
        "de": "Alle abwählen", "es": "Deseleccionar todo", "fr": "Tout désélectionner",
        "zh-Hans": "全部取消", "zh-Hant": "全部取消",
        "ar": "إلغاء تحديد الكل", "hi": "सभी अचयनित करें"
    },
    "새 스니펫": {
        "ko": "새 스니펫", "en": "New Snippet", "ja": "新規スニペット",
        "de": "Neues Snippet", "es": "Nuevo fragmento", "fr": "Nouvel extrait",
        "zh-Hans": "新建片段", "zh-Hant": "新建片段",
        "ar": "مقتطف جديد", "hi": "नया स्निपेट"
    },
    "키워드": {
        "ko": "키워드", "en": "Keyword", "ja": "キーワード",
        "de": "Schlüsselwort", "es": "Palabra clave", "fr": "Mot-clé",
        "zh-Hans": "关键词", "zh-Hant": "關鍵字",
        "ar": "كلمة رئيسية", "hi": "कीवर्ड"
    },
    "내용": {
        "ko": "내용", "en": "Content", "ja": "内容",
        "de": "Inhalt", "es": "Contenido", "fr": "Contenu",
        "zh-Hans": "内容", "zh-Hant": "內容",
        "ar": "محتوى", "hi": "सामग्री"
    },
    "기본": {
        "ko": "기본", "en": "Default", "ja": "デフォルト",
        "de": "Standard", "es": "Predeterminado", "fr": "Par défaut",
        "zh-Hans": "默认", "zh-Hant": "預設",
        "ar": "افتراضي", "hi": "डिफ़ॉल्ट"
    },
    "기본 정보": {
        "ko": "기본 정보", "en": "Basic Info", "ja": "基本情報",
        "de": "Basisinformationen", "es": "Información básica", "fr": "Informations de base",
        "zh-Hans": "基本信息", "zh-Hant": "基本資訊",
        "ar": "معلومات أساسية", "hi": "बुनियादी जानकारी"
    },
    "저장 폴더": {
        "ko": "저장 폴더", "en": "Save Folder", "ja": "保存フォルダ",
        "de": "Speicherordner", "es": "Carpeta de guardado", "fr": "Dossier d'enregistrement",
        "zh-Hans": "保存文件夹", "zh-Hant": "儲存資料夾",
        "ar": "مجلد الحفظ", "hi": "सहेजें फ़ोल्डर"
    },
    "이름:": {
        "ko": "이름:", "en": "Name:", "ja": "名前：",
        "de": "Name:", "es": "Nombre:", "fr": "Nom :",
        "zh-Hans": "名称：", "zh-Hant": "名稱：",
        "ar": "الاسم:", "hi": "नाम:"
    },
    "이름 (설명)": {
        "ko": "이름 (설명)", "en": "Name (Description)", "ja": "名前（説明）",
        "de": "Name (Beschreibung)", "es": "Nombre (Descripción)", "fr": "Nom (Description)",
        "zh-Hans": "名称（说明）", "zh-Hant": "名稱（說明）",
        "ar": "الاسم (الوصف)", "hi": "नाम (विवरण)"
    },
    "설명 (Description)": {
        "ko": "설명", "en": "Description", "ja": "説明",
        "de": "Beschreibung", "es": "Descripción", "fr": "Description",
        "zh-Hans": "说明", "zh-Hant": "說明",
        "ar": "الوصف", "hi": "विवरण"
    },
    "설정 초기화": {
        "ko": "설정 초기화", "en": "Reset Settings", "ja": "設定をリセット",
        "de": "Einstellungen zurücksetzen", "es": "Restablecer configuración", "fr": "Réinitialiser les paramètres",
        "zh-Hans": "重置设置", "zh-Hant": "重置設定",
        "ar": "إعادة تعيين الإعدادات", "hi": "सेटिंग्स रीसेट करें"
    },
    "스니펫 편집": {
        "ko": "스니펫 편집", "en": "Edit Snippet", "ja": "スニペットを編集",
        "de": "Snippet bearbeiten", "es": "Editar fragmento", "fr": "Modifier l'extrait",
        "zh-Hans": "编辑片段", "zh-Hant": "編輯片段",
        "ar": "تحرير المقتطف", "hi": "स्निपेट संपादित करें"
    },
    "스니펫 삭제": {
        "ko": "스니펫 삭제", "en": "Delete Snippet", "ja": "スニペットを削除",
        "de": "Snippet löschen", "es": "Eliminar fragmento", "fr": "Supprimer l'extrait",
        "zh-Hans": "删除片段", "zh-Hant": "刪除片段",
        "ar": "حذف المقتطف", "hi": "स्निपेट हटाएं"
    },
    "파일명 입력": {
        "ko": "파일명 입력", "en": "Enter filename", "ja": "ファイル名を入力",
        "de": "Dateiname eingeben", "es": "Ingrese nombre de archivo", "fr": "Entrez le nom du fichier",
        "zh-Hans": "输入文件名", "zh-Hant": "輸入檔案名稱",
        "ar": "أدخل اسم الملف", "hi": "फ़ाइल का नाम दर्ज करें"
    },
    "폴더 삭제 확인": {
        "ko": "폴더 삭제 확인", "en": "Confirm Folder Deletion", "ja": "フォルダ削除の確認",
        "de": "Ordner löschen bestätigen", "es": "Confirmar eliminación de carpeta", "fr": "Confirmer la suppression du dossier",
        "zh-Hans": "确认删除文件夹", "zh-Hant": "確認刪除資料夾",
        "ar": "تأكيد حذف المجلد", "hi": "फ़ोल्डर हटाने की पुष्टि करें"
    },
    "폴더 생성 실패": {
        "ko": "폴더 생성 실패", "en": "Folder Creation Failed", "ja": "フォルダ作成に失敗",
        "de": "Ordner konnte nicht erstellt werden", "es": "Error al crear carpeta", "fr": "Échec de la création du dossier",
        "zh-Hans": "创建文件夹失败", "zh-Hant": "建立資料夾失敗",
        "ar": "فشل إنشاء المجلد", "hi": "फ़ोल्डर निर्माण विफल"
    },
    "한국어 (Korean)": {
        "ko": "한국어 (Korean)", "en": "한국어 (Korean)", "ja": "한국어 (Korean)",
        "de": "한국어 (Korean)", "es": "한국어 (Korean)", "fr": "한국어 (Korean)",
        "zh-Hans": "한국어 (Korean)", "zh-Hant": "한국어 (Korean)"
    },
    "스니펫 루트 폴더를 Finder에서 열기": {
        "ko": "스니펫 루트 폴더를 Finder에서 열기", "en": "Open Snippet Root Folder in Finder",
        "ja": "Finderでスニペットルートフォルダを開く",
        "de": "Snippet-Stammordner im Finder öffnen", "es": "Abrir carpeta raíz de fragmentos en Finder",
        "fr": "Ouvrir le dossier racine des extraits dans le Finder",
        "zh-Hans": "在Finder中打开片段根文件夹", "zh-Hant": "在Finder中開啟片段根資料夾",
        "ar": "فتح مجلد جذر المقتطف في Finder", "hi": "Finder में स्निपेट रूट फ़ोल्डर खोलें"
    },
    "스니펫 확장을 위한 트리거 문자들을 선택하세요": {
        "ko": "스니펫 확장을 위한 트리거 문자들을 선택하세요",
        "en": "Select trigger characters for snippet expansion",
        "ja": "スニペット展開用のトリガー文字を選択してください",
        "de": "Wählen Sie Trigger-Zeichen für die Snippet-Erweiterung",
        "es": "Seleccione caracteres de activación para la expansión de fragmentos",
        "fr": "Sélectionnez les caractères déclencheurs pour l'expansion des extraits",
        "zh-Hans": "选择用于片段扩展的触发字符",
        "zh-Hant": "選擇用於片段展開的觸發字元",
        "ar": "حدد أحرف التشغيل لتوسيع المقتطف",
        "hi": "स्निपेट विस्तार के लिए ट्रिगर वर्ण चुनें"
    },
    "활성 트리거키": {
        "ko": "활성 트리거키", "en": "Active Trigger Keys", "ja": "アクティブなトリガーキー",
        "de": "Aktive Trigger-Tasten", "es": "Teclas de activación activas", "fr": "Touches de déclenchement actives",
        "zh-Hans": "活动触发键", "zh-Hant": "活躍觸發鍵",
        "ar": "مفاتيح التشغيل النشطة", "hi": "सक्रिय ट्रिगर कुंजी"
    },
    "활성: %lld개": {
        "ko": "활성: %lld개", "en": "Active: %lld", "ja": "アクティブ: %lld個",
        "de": "Aktiv: %lld", "es": "Activos: %lld", "fr": "Actifs : %lld",
        "zh-Hans": "活动: %lld个", "zh-Hant": "活躍: %lld個",
        "ar": "نشط: %lld", "hi": "सक्रिय: %lld"
    },
    "총 %lld개": {
        "ko": "총 %lld개", "en": "Total: %lld", "ja": "合計: %lld件",
        "de": "Gesamt: %lld", "es": "Total: %lld", "fr": "Total : %lld",
        "zh-Hans": "共%lld个", "zh-Hant": "共%lld個",
        "ar": "الإجمالي: %lld", "hi": "कुल: %lld"
    },
    "트리거키 생성": {
        "ko": "트리거키 생성", "en": "Create Trigger Key", "ja": "トリガーキーを作成",
        "de": "Trigger-Taste erstellen", "es": "Crear tecla de activación", "fr": "Créer une touche de déclenchement",
        "zh-Hans": "创建触发键", "zh-Hant": "建立觸發鍵",
        "ar": "إنشاء مفتاح تشغيل", "hi": "ट्रिगर कुंजी बनाएं"
    },
    "트리거키 이름": {
        "ko": "트리거키 이름", "en": "Trigger Key Name", "ja": "トリガーキー名",
        "de": "Name der Trigger-Taste", "es": "Nombre de tecla de activación", "fr": "Nom de la touche de déclenchement",
        "zh-Hans": "触发键名称", "zh-Hant": "觸發鍵名稱",
        "ar": "اسم مفتاح التشغيل", "hi": "ट्रिगर कुंजी नाम"
    },
    "트리거키 추가": {
        "ko": "트리거키 추가", "en": "Add Trigger Key", "ja": "トリガーキーを追加",
        "de": "Trigger-Taste hinzufügen", "es": "Añadir tecla de activación", "fr": "Ajouter une touche de déclenchement",
        "zh-Hans": "添加触发键", "zh-Hant": "新增觸發鍵",
        "ar": "إضافة مفتاح تشغيل", "hi": "ट्रिगर कुंजी जोड़ें"
    },
    "선택하여\\n트리거키 생성": {
        "ko": "선택하여\n트리거키 생성", "en": "Select to\nCreate Trigger Key", "ja": "選択して\nトリガーキーを作成",
        "de": "Auswählen für\nTrigger-Taste", "es": "Seleccionar para\ncrear tecla", "fr": "Sélectionner pour\ncréer déclencheur",
        "zh-Hans": "选择以\n创建触发键", "zh-Hant": "選擇以\n建立觸發鍵",
        "ar": "حدد للإنشاء\nمفتاح تشغيل", "hi": "ट्रिगर कुंजी\nबनाने के लिए चुनें"
    },
    "규칙 이름": {
        "ko": "규칙 이름", "en": "Rule Name", "ja": "ルール名",
        "de": "Regelname", "es": "Nombre de regla", "fr": "Nom de la règle",
        "zh-Hans": "规则名称", "zh-Hant": "規則名稱",
        "ar": "اسم القاعدة", "hi": "नियम का नाम"
    },
    "규칙 이름 (폴더명)": {
        "ko": "규칙 이름 (폴더명)", "en": "Rule Name (Folder Name)", "ja": "ルール名（フォルダ名）",
        "de": "Regelname (Ordnername)", "es": "Nombre de regla (nombre de carpeta)", "fr": "Nom de règle (nom du dossier)",
        "zh-Hans": "规则名称（文件夹名）", "zh-Hant": "規則名稱（資料夾名）",
        "ar": "اسم القاعدة (اسم المجلد)", "hi": "नियम का नाम (फ़ोल्डर नाम)"
    },
    "규칙에 대한 설명": {
        "ko": "규칙에 대한 설명", "en": "Description of the rule", "ja": "ルールの説明",
        "de": "Beschreibung der Regel", "es": "Descripción de la regla", "fr": "Description de la règle",
        "zh-Hans": "规则说明", "zh-Hant": "規則說明",
        "ar": "وصف القاعدة", "hi": "नियम का विवरण"
    },
    "규칙 상세 편집": {
        "ko": "규칙 상세 편집", "en": "Edit Rule Details", "ja": "ルール詳細を編集",
        "de": "Regeldetails bearbeiten", "es": "Editar detalles de regla", "fr": "Modifier les détails de la règle",
        "zh-Hans": "编辑规则详情", "zh-Hant": "編輯規則詳情",
        "ar": "تحرير تفاصيل القاعدة", "hi": "नियम विवरण संपादित करें"
    },
    "아이콘 변경...": {
        "ko": "아이콘 변경...", "en": "Change Icon...", "ja": "アイコンを変更...",
        "de": "Symbol ändern...", "es": "Cambiar icono...", "fr": "Changer l'icône...",
        "zh-Hans": "更改图标...", "zh-Hant": "更改圖示...",
        "ar": "تغيير الرمز...", "hi": "आइकन बदलें..."
    },
    "아이콘 복사": {
        "ko": "아이콘 복사", "en": "Copy Icon", "ja": "アイコンをコピー",
        "de": "Symbol kopieren", "es": "Copiar icono", "fr": "Copier l'icône",
        "zh-Hans": "复制图标", "zh-Hant": "複製圖示",
        "ar": "نسخ الرمز", "hi": "आइकन कॉपी करें"
    },
    "아이콘 붙여넣기": {
        "ko": "아이콘 붙여넣기", "en": "Paste Icon", "ja": "アイコンを貼り付け",
        "de": "Symbol einfügen", "es": "Pegar icono", "fr": "Coller l'icône",
        "zh-Hans": "粘贴图标", "zh-Hant": "貼上圖示",
        "ar": "لصق الرمز", "hi": "आइकन पेस्ट करें"
    },
    "아이콘 제거": {
        "ko": "아이콘 제거", "en": "Remove Icon", "ja": "アイコンを削除",
        "de": "Symbol entfernen", "es": "Eliminar icono", "fr": "Supprimer l'icône",
        "zh-Hans": "移除图标", "zh-Hant": "移除圖示",
        "ar": "إزالة الرمز", "hi": "आइकन हटाएं"
    },
    "클릭하여 아이콘 복사": {
        "ko": "클릭하여 아이콘 복사", "en": "Click to copy icon", "ja": "クリックしてアイコンをコピー",
        "de": "Klicken, um Symbol zu kopieren", "es": "Haz clic para copiar icono", "fr": "Cliquer pour copier l'icône",
        "zh-Hans": "点击复制图标", "zh-Hant": "點擊複製圖示",
        "ar": "انقر لنسخ الرمز", "hi": "आइकन कॉपी करने के लिए क्लिक करें"
    },
    "출력:": {
        "ko": "출력:", "en": "Output:", "ja": "出力：",
        "de": "Ausgabe:", "es": "Salida:", "fr": "Sortie :",
        "zh-Hans": "输出：", "zh-Hant": "輸出：",
        "ar": "الإخراج:", "hi": "आउटपुट:"
    },
    "출력: '%@'": {
        "ko": "출력: '%@'", "en": "Output: '%@'", "ja": "出力: '%@'",
        "de": "Ausgabe: '%@'", "es": "Salida: '%@'", "fr": "Sortie : '%@'",
        "zh-Hans": "输出：'%@'", "zh-Hant": "輸出：'%@'",
        "ar": "الإخراج: '%@'", "hi": "आउटपुट: '%@'"
    },
    "조합키:": {
        "ko": "조합키:", "en": "Modifier:", "ja": "修飾キー：",
        "de": "Modifizierer:", "es": "Modificador:", "fr": "Modificateur :",
        "zh-Hans": "修饰键：", "zh-Hant": "修飾鍵：",
        "ar": "المغير:", "hi": "संशोधक:"
    },
    "키 조합:": {
        "ko": "키 조합:", "en": "Key Combination:", "ja": "キーの組み合わせ：",
        "de": "Tastenkombination:", "es": "Combinación de teclas:", "fr": "Combinaison de touches :",
        "zh-Hans": "键组合：", "zh-Hant": "鍵組合：",
        "ar": "مجموعة المفاتيح:", "hi": "कुंजी संयोजन:"
    },
    "모니터링 시작": {
        "ko": "모니터링 시작", "en": "Start Monitoring", "ja": "モニタリング開始",
        "de": "Überwachung starten", "es": "Iniciar monitoreo", "fr": "Démarrer la surveillance",
        "zh-Hans": "开始监控", "zh-Hant": "開始監控",
        "ar": "بدء المراقبة", "hi": "निगरानी शुरू करें"
    },
    "모니터링 중지": {
        "ko": "모니터링 중지", "en": "Stop Monitoring", "ja": "モニタリング停止",
        "de": "Überwachung beenden", "es": "Detener monitoreo", "fr": "Arrêter la surveillance",
        "zh-Hans": "停止监控", "zh-Hant": "停止監控",
        "ar": "إيقاف المراقبة", "hi": "निगरानी रोकें"
    },
    "감지 기록 지우기": {
        "ko": "감지 기록 지우기", "en": "Clear Detection History", "ja": "検出履歴をクリア",
        "de": "Erkennungsverlauf löschen", "es": "Borrar historial de detección", "fr": "Effacer l'historique de détection",
        "zh-Hans": "清除检测记录", "zh-Hant": "清除偵測記錄",
        "ar": "مسح سجل الكشف", "hi": "पहचान इतिहास साफ़ करें"
    },
    "감지된 문자:": {
        "ko": "감지된 문자:", "en": "Detected Character:", "ja": "検出された文字：",
        "de": "Erkanntes Zeichen:", "es": "Carácter detectado:", "fr": "Caractère détecté :",
        "zh-Hans": "检测到的字符：", "zh-Hant": "偵測到的字元：",
        "ar": "الحرف المكتشف:", "hi": "पता चला वर्ण:"
    },
    "감지된 키 입력": {
        "ko": "감지된 키 입력", "en": "Detected Key Input", "ja": "検出されたキー入力",
        "de": "Erkannte Tasteneingabe", "es": "Entrada de tecla detectada", "fr": "Entrée de touche détectée",
        "zh-Hans": "检测到的按键输入", "zh-Hant": "偵測到的按鍵輸入",
        "ar": "إدخال المفتاح المكتشف", "hi": "पता चला कुंजी इनपुट"
    },
    "키보드 입력을 모니터링하여 새로운 트리거키를 추가할 수 있습니다": {
        "ko": "키보드 입력을 모니터링하여 새로운 트리거키를 추가할 수 있습니다",
        "en": "Monitor keyboard input to add new trigger keys",
        "ja": "キーボード入力を監視して新しいトリガーキーを追加できます",
        "de": "Tastatureingaben überwachen, um neue Trigger-Tasten hinzuzufügen",
        "es": "Monitorear entrada de teclado para añadir nuevas teclas de activación",
        "fr": "Surveiller la saisie clavier pour ajouter de nouvelles touches de déclenchement",
        "zh-Hans": "监控键盘输入以添加新的触发键",
        "zh-Hant": "監控鍵盤輸入以新增觸發鍵",
        "ar": "مراقبة إدخال لوحة المفاتيح لإضافة مفاتيح تشغيل جديدة",
        "hi": "नई ट्रिगर कुंजी जोड़ने के लिए कीबोर्ड इनपुट की निगरानी करें"
    },
    "키 입력을 모니터링 중입니다. 특수 문자나 조합키를 눌러보세요.": {
        "ko": "키 입력을 모니터링 중입니다. 특수 문자나 조합키를 눌러보세요.",
        "en": "Monitoring key input. Try pressing special characters or modifier keys.",
        "ja": "キー入力を監視中です。特殊文字や修飾キーを押してみてください。",
        "de": "Tastatureingaben werden überwacht. Versuchen Sie Sonderzeichen oder Modifizierer.",
        "es": "Monitoreando entrada de teclas. Intente presionar caracteres especiales o teclas modificadoras.",
        "fr": "Surveillance de la saisie. Essayez les caractères spéciaux ou les touches modificatrices.",
        "zh-Hans": "正在监控按键输入。请尝试按特殊字符或修饰键。",
        "zh-Hant": "正在監控按鍵輸入。請嘗試按特殊字元或修飾鍵。",
        "ar": "جاري مراقبة إدخال المفتاح. جرب الضغط على أحرف خاصة أو مفاتيح تعديل.",
        "hi": "कुंजी इनपुट की निगरानी की जा रही है। विशेष वर्ण या संशोधक कुंजी दबाने का प्रयास करें।"
    },
    "테스트용 강제 붙여넣기 (Cmd+V)": {
        "ko": "테스트용 강제 붙여넣기 (Cmd+V)", "en": "Force Paste for Testing (Cmd+V)",
        "ja": "テスト用強制貼り付け（Cmd+V）",
        "de": "Test-Einfügen erzwingen (Cmd+V)", "es": "Forzar pegado para pruebas (Cmd+V)",
        "fr": "Collage forcé pour test (Cmd+V)",
        "zh-Hans": "测试用强制粘贴 (Cmd+V)", "zh-Hant": "測試用強制貼上 (Cmd+V)",
        "ar": "فرض اللصق (Cmd+V) للاختبار", "hi": "परीक्षण के लिए पेस्ट बाध्य करें (Cmd+V)"
    },
    "⚠️ 이름 변경 시 실제 폴더 이름도 변경됩니다.": {
        "ko": "⚠️ 이름 변경 시 실제 폴더 이름도 변경됩니다.",
        "en": "⚠️ Renaming will also change the actual folder name.",
        "ja": "⚠️ 名前を変更すると実際のフォルダ名も変更されます。",
        "de": "⚠️ Beim Umbenennen wird auch der tatsächliche Ordnername geändert.",
        "es": "⚠️ Renombrar también cambiará el nombre real de la carpeta.",
        "fr": "⚠️ Le renommage changera également le nom réel du dossier.",
        "zh-Hans": "⚠️ 重命名时实际文件夹名称也会更改。",
        "zh-Hant": "⚠️ 重新命名時實際資料夾名稱也會更改。",
        "ar": "⚠️ إعادة التسمية ستغير اسم المجلد الفعلي أيضًا.",
        "hi": "⚠️ नाम बदलने से वास्तविक फ़ोल्डर नाम भी बदल जाएगा।"
    },
    "이 스니펫을 삭제하시겠습니까?\\n이 작업은 되돌릴 수 없습니다.": {
        "ko": "이 스니펫을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.",
        "en": "Delete this snippet?\nThis action cannot be undone.",
        "ja": "このスニペットを削除しますか？\nこの操作は取り消せません。",
        "de": "Dieses Snippet löschen?\nDiese Aktion kann nicht rückgängig gemacht werden.",
        "es": "¿Eliminar este fragmento?\nEsta acción no se puede deshacer.",
        "fr": "Supprimer cet extrait ?\nCette action est irréversible.",
        "zh-Hans": "删除此片段？\n此操作无法撤销。",
        "zh-Hant": "刪除此片段？\n此操作無法復原。",
        "ar": "حذف هذا المقتطف؟\nلا يمكن التراجع عن هذا الإجراء.",
        "hi": "क्या इस स्निपेट को हटाएं?\nयह कार्रवाई पूर्ववत नहीं की जा सकती।"
    },
    "정말로 '%@' 폴더와 그 안의 모든 스니펫을 삭제하시겠습니까?\\n이 작업은 되돌릴 수 없습니다.": {
        "ko": "정말로 '%@' 폴더와 그 안의 모든 스니펫을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.",
        "en": "Delete folder '%@' and all its snippets?\nThis action cannot be undone.",
        "ja": "'%@'フォルダとすべてのスニペットを削除しますか？\nこの操作は取り消せません。",
        "de": "Ordner '%@' und alle Snippets löschen?\nDiese Aktion kann nicht rückgängig gemacht werden.",
        "es": "¿Eliminar carpeta '%@' y todos sus fragmentos?\nEsta acción no se puede deshacer.",
        "fr": "Supprimer le dossier '%@' et tous ses extraits ?\nCette action est irréversible.",
        "zh-Hans": "删除'%@'文件夹及其所有片段？\n此操作无法撤销。",
        "zh-Hant": "刪除'%@'資料夾及其所有片段？\n此操作無法復原。",
        "ar": "حذف المجلد '%@' وجميع مقتطفاته؟\nلا يمكن التراجع عن هذا الإجراء.",
        "hi": "क्या फ़ोल्डर '%@' और उसके सभी स्निपेट हटाएं?\nयह कार्रवाई पूर्ववत नहीं की जा सकती।"
    },
    "• 기본: %@": {
        "ko": "• 기본: %@", "en": "• Default: %@", "ja": "• デフォルト: %@",
        "de": "• Standard: %@", "es": "• Predeterminado: %@", "fr": "• Par défaut : %@",
        "zh-Hans": "• 默认：%@", "zh-Hant": "• 預設：%@",
        "ar": "• الافتراضي: %@", "hi": "• डिफ़ॉल्ट: %@"
    },
    "• 양수(+): 글자를 더 많이 삭제\\n• 음수(-): 글자를 덜 삭제": {
        "ko": "• 양수(+): 글자를 더 많이 삭제\n• 음수(-): 글자를 덜 삭제",
        "en": "• Positive (+): Delete more characters\n• Negative (-): Delete fewer characters",
        "ja": "• 正の値(+): より多くの文字を削除\n• 負の値(-): より少ない文字を削除",
        "de": "• Positiv (+): Mehr Zeichen löschen\n• Negativ (-): Weniger Zeichen löschen",
        "es": "• Positivo (+): Eliminar más caracteres\n• Negativo (-): Eliminar menos caracteres",
        "fr": "• Positif (+) : Supprimer plus de caractères\n• Négatif (-) : Supprimer moins de caractères",
        "zh-Hans": "• 正数(+)：删除更多字符\n• 负数(-)：删除更少字符",
        "zh-Hant": "• 正數(+)：刪除更多字元\n• 負數(-)：刪除更少字元",
        "ar": "• موجب (+): حذف المزيد من الأحرف\n• سالب (-): حذف أحرف أقل",
        "hi": "• सकारात्मक (+): अधिक वर्ण हटाएं\n• नकारात्मक (-): कम वर्ण हटाएं"
    },
    "💡 특수문자나 조합키를 눌러서 KeyLogger 데이터를 확인하세요": {
        "ko": "💡 특수문자나 조합키를 눌러서 KeyLogger 데이터를 확인하세요",
        "en": "💡 Press special characters or modifier keys to check KeyLogger data",
        "ja": "💡 特殊文字や修飾キーを押してKeyLoggerデータを確認してください",
        "de": "💡 Drücken Sie Sonderzeichen oder Modifizierer, um KeyLogger-Daten zu prüfen",
        "es": "💡 Presione caracteres especiales o teclas modificadoras para verificar datos de KeyLogger",
        "fr": "💡 Appuyez sur des caractères spéciaux ou des touches modificatrices pour vérifier les données KeyLogger",
        "zh-Hans": "💡 按特殊字符或修饰键以检查KeyLogger数据",
        "zh-Hant": "💡 按特殊字元或修飾鍵以檢查KeyLogger數據",
        "ar": "💡 اضغط على أحرف خاصة أو مفاتيح تعديل للتحقق من بيانات KeyLogger",
        "hi": "💡 KeyLogger डेटा की जांच के लिए विशेष वर्ण या संशोधक कुंजी दबाएं"
    },
    "📋 실제 트리거: '%@' 문자 입력 → KeyLogger 값으로 정확한 매칭": {
        "ko": "📋 실제 트리거: '%@' 문자 입력 → KeyLogger 값으로 정확한 매칭",
        "en": "📋 Actual trigger: Input '%@' → Exact match with KeyLogger value",
        "ja": "📋 実際のトリガー: '%@'文字入力 → KeyLogger値で正確にマッチング",
        "de": "📋 Tatsächlicher Trigger: '%@' eingeben → Exakte Übereinstimmung mit KeyLogger-Wert",
        "es": "📋 Trigger real: Ingrese '%@' → Coincidencia exacta con valor de KeyLogger",
        "fr": "📋 Déclencheur réel : Saisir '%@' → Correspondance exacte avec la valeur KeyLogger",
        "zh-Hans": "📋 实际触发：输入'%@' → 与KeyLogger值精确匹配",
        "zh-Hant": "📋 實際觸發：輸入'%@' → 與KeyLogger值精確匹配",
        "ar": "📋 المشغل الفعلي: إدخال '%@' ← تطابق تام مع قيمة KeyLogger",
        "hi": "📋 वास्तविक ट्रिगर: इनपुट '%@' → KeyLogger मान के साथ सटीक मिलान"
    },
    "KeyLogger 메타데이터": {
        "ko": "KeyLogger 메타데이터", "en": "KeyLogger Metadata", "ja": "KeyLoggerメタデータ",
        "de": "KeyLogger-Metadaten", "es": "Metadatos de KeyLogger", "fr": "Métadonnées KeyLogger",
        "zh-Hans": "KeyLogger元数据", "zh-Hant": "KeyLogger元數據",
        "ar": "بيانات KeyLogger الوصفية", "hi": "KeyLogger मेटाडेटा"
    },
    "KeyLogger 모니터": {
        "ko": "KeyLogger 모니터", "en": "KeyLogger Monitor", "ja": "KeyLoggerモニター",
        "de": "KeyLogger-Monitor", "es": "Monitor de KeyLogger", "fr": "Moniteur KeyLogger",
        "zh-Hans": "KeyLogger监视器", "zh-Hant": "KeyLogger監視器",
        "ar": "مراقب KeyLogger", "hi": "KeyLogger मॉनिटर"
    },
    "KeyLogger 형식: %@": {
        "ko": "KeyLogger 형식: %@", "en": "KeyLogger Format: %@", "ja": "KeyLogger形式: %@",
        "de": "KeyLogger-Format: %@", "es": "Formato de KeyLogger: %@", "fr": "Format KeyLogger : %@",
        "zh-Hans": "KeyLogger格式：%@", "zh-Hant": "KeyLogger格式：%@",
        "ar": "تنسيق KeyLogger: %@", "hi": "KeyLogger प्रारूप: %@"
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

    # "key" = "value"; 패턴 매칭
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

def translate_file(lang, filename):
    """특정 언어의 strings 파일 번역 및 누락된 키 추가"""
    filepath = os.path.join(RESOURCES_DIR, f'{lang}.lproj', filename)

    if not os.path.exists(filepath):
        print(f'  File not found: {filepath}')
        # 파일이 없으면 빈 상태로 시작하여 새로 생성 유도
        entries = {}
    else:
        entries = parse_strings_file(filepath)

    updated = 0
    added = 0

    # 1. 기존 키 번역 업데이트
    for key in list(entries.keys()):
        if key in TRANSLATIONS and lang in TRANSLATIONS[key]:
            new_value = TRANSLATIONS[key][lang]
            if entries[key] != new_value:
                entries[key] = new_value
                updated += 1
    
    # 2. 누락된 키 추가 (Localizable.strings만)
    if filename == 'Localizable.strings':
        for key in TRANSLATIONS.keys():
            if key not in entries and lang in TRANSLATIONS[key]:
                entries[key] = TRANSLATIONS[key][lang]
                added += 1

    write_strings_file(filepath, entries, lang)
    return updated, added

def main():
    languages = ['en', 'ko', 'ja', 'de', 'es', 'fr', 'zh-Hans', 'zh-Hant', 'ar', 'hi']
    files = ['Localizable.strings', 'Settings.strings']

    print('=== Starting Translation ===\n')

    total_updated = 0
    total_added = 0
    for lang in languages:
        print(f'{lang}:')
        for filename in files:
            updated, added = translate_file(lang, filename)
            print(f'  {filename}: {updated} entries updated, {added} entries added')
            total_updated += updated
            total_added += added
        print()

    print(f'=== Total: {total_updated} entries updated, {total_added} entries added ===')


# === Forced update for Issue 548 (Avoid matching issues) ===
TRANSLATIONS.update({
    "alert.settings_folder_not_found.message": {
        "ko": "기본 설정 폴더가 존재하지 않습니다.\n경로: %@\n\n새로운 폴더를 생성하시겠습니까, 아니면 기존 폴더를 선택하시겠습니까?",
        "en": "The default settings folder does not exist.\nPath: %@\n\nWould you like to create a new folder or select an existing one?",
        "ja": "デフォルトの設定フォルダが存在しません。\nパス: %@\n\n新しいフォルダを作成しますか、それとも既存のフォルダを選択합니다까？",
        "de": "Der Standard-Einstellungsordner existiert nicht.\nPfad: %@\n\nMöchten Sie einen neuen Ordner erstellen oder einen vorhandenen auswählen?",
        "es": "La carpeta de configuración predeterminada no existe.\nRuta: %@\n\n¿Desea crear una carpeta nueva o seleccionar una existente?",
        "fr": "Le dossier de paramètres par défaut n'existe pas.\nChemin : %@\n\nVoulez-vous créer un nouveau dossier ou en sélectionner un existant ?",
        "zh-Hans": "默认设置文件夹不存在。\n路径: %@\n\n您要创建新文件夹还是选择现有文件夹？",
        "zh-Hant": "預設設定資料夾不存在。\n路徑: %@\n\n您要建立新資料夾還是選擇現유資料夾？",
        "ar": "مجلد الإعدادات الافتراضي غير موجود.\nالمسار: %@\n\nهل ترغب في إنشاء مجلد جديد أو تحديد مجلد موجود؟",
        "hi": "डिफ़ॉल्ट सेटिंग्स फ़ोल्डर मौजूद नहीं है.\nपथ: %@\n\nक्या आप एक नया फ़ोल्डर बनाना चाहेंगे 또는 개선의 को चुनना चाहेंगे?"
    },
    "settings.error.shortcut_conflict": {
        "ko": "단축키 확인: '%@'은(는)\n이미 '%@'에서 사용 중입니다.",
        "en": "Shortcut Conflict: '%@' is\nalready in use by '%@'.",
        "ja": "ショートカットの衝突: '%@' は\nすでに '%@' で使用されています。",
        "de": "Tastenkombinations-Konflikt: '%@' wird\nbereits von '%@' verwendet.",
        "es": "Conflicto de atajo: '%@' ya\nestá en uso por '%@'.",
        "fr": "Conflit de raccourci : '%@' est\ndéjà utilisé par '%@'.",
        "zh-Hans": "快捷键冲突：'%@'\n已由 '%@' 使用。",
        "zh-Hant": "快捷鍵衝突：'%@'\n已由 '%@' 使用。",
        "ar": "تعارض الاختصار: '%@' قيد\nالاستخدام بالفعل بواسطة '%@'.",
        "hi": "शॉर्ट컷 संघर्ष: '%@' पहले से ही\n'%@' द्वारा उपयोग में है।"
    }
})

if __name__ == '__main__':
    main()
