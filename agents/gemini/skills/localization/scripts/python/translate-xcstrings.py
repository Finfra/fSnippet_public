import json
import os

FILE_PATH = 'fSnippet/fSnippet/Resources/Localizable.xcstrings'

# Dictionary format: Key -> { lang_code: translation }
TRANSLATIONS = {
    "Cancel": {"ja": "キャンセル", "de": "Abbrechen", "fr": "Annuler", "es": "Cancelar", "zh-Hant": "取消", "zh-Hans": "取消"},
    "Confirm": {"ja": "確認", "de": "Bestätigen", "fr": "Confirmer", "es": "Confirmar", "zh-Hant": "確認", "zh-Hans": "确认"},
    "Delete": {"ja": "削除", "de": "Löschen", "fr": "Supprimer", "es": "Eliminar", "zh-Hant": "刪除", "zh-Hans": "删除"},
    "Edit": {"ja": "編集", "de": "Bearbeiten", "fr": "Modifier", "es": "Editar", "zh-Hant": "編輯", "zh-Hans": "编辑"},
    "Add": {"ja": "追加", "de": "Hinzufügen", "fr": "Ajouter", "es": "Añadir", "zh-Hant": "新增", "zh-Hans": "添加"},
    "Remove": {"ja": "削除", "de": "Entfernen", "fr": "Supprimer", "es": "Eliminar", "zh-Hant": "移除", "zh-Hans": "移除"},
    "Save": {"ja": "保存", "de": "Speichern", "fr": "Enregistrer", "es": "Guardar", "zh-Hant": "儲存", "zh-Hans": "保存"},
    "Close": {"ja": "閉じる", "de": "Schließen", "fr": "Fermer", "es": "Cerrar", "zh-Hant": "關閉", "zh-Hans": "关闭"},
    "Warning": {"ja": "警告", "de": "Warnung", "fr": "Avertissement", "es": "Advertencia", "zh-Hant": "警告", "zh-Hans": "警告"},
    "Error": {"ja": "エラー", "de": "Fehler", "fr": "Erreur", "es": "Error", "zh-Hant": "錯誤", "zh-Hans": "错误"},
    "Info": {"ja": "情報", "de": "Info", "fr": "Info", "es": "Info", "zh-Hant": "資訊", "zh-Hans": "信息"},
    
    # Settings Sections
    "settings.general.title": {"ja": "一般設定", "de": "Allgemeine Einstellungen", "fr": "Paramètres généraux", "es": "Configuración general", "zh-Hant": "一般設定", "zh-Hans": "通用设置"},
    "settings.general.section.basic": {"ja": "基本設定", "de": "Grundeinstellungen", "fr": "Paramètres de base", "es": "Ajustes básicos", "zh-Hant": "基本設定", "zh-Hans": "基本设置"},
    "settings.general.section.popup": {"ja": "ポップアップ設定", "de": "Popup-Einstellungen", "fr": "Paramètres contextuels", "es": "Configuración emergente", "zh-Hant": "彈出視窗設定", "zh-Hans": "弹窗设置"},
    "settings.general.section.app_behavior": {"ja": "アプリの動作", "de": "App-Verhalten", "fr": "Comportement de l'application", "es": "Comportamiento de la aplicación", "zh-Hant": "應用程式行為", "zh-Hans": "应用行为"},
    
    # Settings Labels
    "settings.general.language": {"ja": "言語", "de": "Sprache", "fr": "Langue", "es": "Idioma", "zh-Hant": "語言", "zh-Hans": "语言"},
    "settings.general.settings_folder": {"ja": "設定フォルダーの場所:", "de": "Speicherort des Einstellungsordners:", "fr": "Emplacement du dossier des paramètres:", "es": "Ubicación de la carpeta de configuración:", "zh-Hant": "設定資料夾位置：", "zh-Hans": "设置文件夹位置："},
    "settings.general.snippet_folder": {"ja": "スニペットフォルダーの場所:", "de": "Speicherort des Snippet-Ordners:", "fr": "Emplacement du dossier des extraits:", "es": "Ubicación de la carpeta de fragmentos:", "zh-Hant": "Snippet 資料夾位置：", "zh-Hans": "Snippet 文件夹位置："},
    "settings.general.popup_key": {"ja": "ポップアップホットキー", "de": "Popup-Hotkey", "fr": "Raccourci popup", "es": "Tecla de acceso rápido emergente", "zh-Hant": "彈出視窗快速鍵", "zh-Hans": "弹窗快捷键"},
    "settings.general.trigger_key": {"ja": "トリガーキー", "de": "Auslösetaste", "fr": "Touche de déclenchement", "es": "Tecla de activación", "zh-Hant": "觸發鍵", "zh-Hans": "触发键"},
    "settings.general.trigger_bias": {"ja": "トリガーバイアス:", "de": "Trigger-Bias:", "fr": "Biais de déclenchement:", "es": "Sesgo de activación:", "zh-Hant": "觸發偏差：", "zh-Hans": "触发偏差："},
    "settings.general.popup_rows": {"ja": "ポップアップ行数", "de": "Popup-Zeilen", "fr": "Lignes popup", "es": "Filas emergentes", "zh-Hant": "彈出視窗列數", "zh-Hans": "弹窗行数"},
    "settings.general.quick_select": {"ja": "クイック選択修飾キー", "de": "Schnellwahl-Modifikator", "fr": "Modificateur de sélection rapide", "es": "Modificador de selección rápida", "zh-Hant": "快速選擇修飾鍵", "zh-Hans": "快速选择修饰键"},
    "settings.general.search_scope": {"ja": "検索範囲", "de": "Suchbereich", "fr": "Portée de la recherche", "es": "Ámbito de búsqueda", "zh-Hant": "搜尋範圍", "zh-Hans": "搜索范围"},
    
    # Settings Toggles
    "settings.general.toggle.auto_start": {"ja": "ログイン時に起動", "de": "Beim Login starten", "fr": "Lancer à la connexion", "es": "Iniciar al iniciar sesión", "zh-Hant": "登入時啟動", "zh-Hans": "登录时启动"},
    "settings.general.toggle.hide_menubar": {"ja": "メニューバーアイコンを隠す", "de": "Menüleistensymbol ausblenden", "fr": "Masquer l'icône de la barre de menus", "es": "Ocultar icono de la barra de menús", "zh-Hant": "隱藏選單列圖示", "zh-Hans": "隐藏菜单栏图标"},
    "settings.general.toggle.notifications": {"ja": "通知を表示", "de": "Benachrichtigungen anzeigen", "fr": "Afficher les notifications", "es": "Mostrar notificaciones", "zh-Hant": "顯示通知", "zh-Hans": "显示通知"},
    "settings.general.toggle.ready_sound": {"ja": "準備完了時に音を鳴らす (Ding-Dong)", "de": "Ton bei Bereitschaft abspielen (Ding-Dong)", "fr": "Jouer un son quand prêt (Ding-Dong)", "es": "Reproducir sonido al estar listo (Ding-Dong)", "zh-Hant": "準備就緒時播放音效 (Ding-Dong)", "zh-Hans": "准备就绪时播放音效 (Ding-Dong)"},
    
    # Tabs
    "settings.tab.general": {"ja": "一般", "de": "Allgemein", "fr": "Général", "es": "General", "zh-Hant": "一般", "zh-Hans": "常规"},
    "settings.tab.snippets": {"ja": "スニペット", "de": "Snippets", "fr": "Extraits", "es": "Fragmentos", "zh-Hant": "Snippet", "zh-Hans": "Snippet"},
    "settings.tab.folders": {"ja": "フォルダー", "de": "Ordner", "fr": "Dossiers", "es": "Carpetas", "zh-Hant": "資料夾", "zh-Hans": "文件夹"},
    "settings.tab.advanced": {"ja": "詳細", "de": "Erweitert", "fr": "Avancé", "es": "Avanzado", "zh-Hant": "進階", "zh-Hans": "高级"},
    "settings.tab.history": {"ja": "履歴", "de": "Verlauf", "fr": "Historique", "es": "Historial", "zh-Hant": "歷史", "zh-Hans": "历史"},
    
    # Snippet Settings
    "settings.snippets.header.folder_name": {"ja": "フォルダー名", "de": "Ordnername", "fr": "Nom du dossier", "es": "Nombre de carpeta", "zh-Hant": "資料夾名稱", "zh-Hans": "文件夹名称"},
    "settings.snippet.list.header.name": {"ja": "名前", "de": "Name", "fr": "Nom", "es": "Nombre", "zh-Hant": "名稱", "zh-Hans": "名称"},
    "settings.snippet.list.header.abbreviation": {"ja": "短縮語", "de": "Abkürzung", "fr": "Abréviation", "es": "Abreviatura", "zh-Hant": "縮寫", "zh-Hans": "缩写"},
    "settings.snippet.list.header.content": {"ja": "内容", "de": "Inhalt", "fr": "Contenu", "es": "Contenido", "zh-Hant": "內容", "zh-Hans": "内容"},
    "settings.snippets.button.open_folder": {"ja": "フォルダーを開く", "de": "Ordner öffnen", "fr": "Ouvrir le dossier", "es": "Abrir carpeta", "zh-Hant": "開啟資料夾", "zh-Hans": "打开文件夹"},
    
    # History Settings
    "settings.history.title": {"ja": "クリップボード履歴", "de": "Zwischenablage-Verlauf", "fr": "Historique du presse-papiers", "es": "Historial del portapapeles", "zh-Hant": "剪貼簿歷史", "zh-Hans": "剪贴板历史"},
    "settings.history.section.data": {"ja": "データ管理", "de": "Datenverwaltung", "fr": "Gestion des données", "es": "Gestión de datos", "zh-Hant": "資料管理", "zh-Hans": "数据管理"},
    "settings.history.section.retention": {"ja": "保持制限", "de": "Aufbewahrungsfrist", "fr": "Limite de conservation", "es": "Límite de retención", "zh-Hant": "保留限制", "zh-Hans": "保留限制"},
    "settings.history.label.keep": {"ja": "保持:", "de": "Behalten:", "fr": "Garder:", "es": "Guardar:", "zh-Hant": "保留：", "zh-Hans": "保留："},
    "settings.history.unit.days": {"ja": "日", "de": "Tage", "fr": "jours", "es": "días", "zh-Hant": "天", "zh-Hans": "天"},
    
    # Advanced Settings
    "settings.advanced.section.debug": {"ja": "デバッグ", "de": "Debuggen", "fr": "Débogage", "es": "Depurar", "zh-Hant": "除錯", "zh-Hans": "调试"},
    "settings.advanced.toggle.debug_log": {"ja": "デバッグログ", "de": "Debug-Protokollierung", "fr": "Journalisation de débogage", "es": "Registro de depuración", "zh-Hant": "除錯紀錄", "zh-Hans": "调试日志"},
    "settings.advanced.label.log_level": {"ja": "ログレベル:", "de": "Protokollierungsstufe:", "fr": "Niveau de journalisation:", "es": "Nivel de registro:", "zh-Hant": "紀錄層級：", "zh-Hans": "日志级别："},
    
    # Popup
    "popup.search.placeholder": {"ja": "検索...", "de": "Suchen...", "fr": "Rechercher...", "es": "Buscar...", "zh-Hant": "搜尋...", "zh-Hans": "搜索..."},
    "popup.search.no_results": {"ja": "結果なし", "de": "Keine Ergebnisse", "fr": "Aucun résultat", "es": "Sin resultados", "zh-Hant": "無結果", "zh-Hans": "无结果"},
    "popup.create.button": {"ja": "'%@' を作成", "de": "'%@' erstellen", "fr": "Créer '%@'", "es": "Crear '%@'", "zh-Hant": "建立 '%@'", "zh-Hans": "创建 '%@'"},
    
    # Alert
    "alert.common.confirm": {"ja": "確認", "de": "Bestätigen", "fr": "Confirmer", "es": "Confirmar", "zh-Hant": "確認", "zh-Hans": "确认"},
    "alert.common.cancel": {"ja": "キャンセル", "de": "Abbrechen", "fr": "Annuler", "es": "Cancelar", "zh-Hant": "取消", "zh-Hans": "取消"},
    "alert.reset.title": {"ja": "設定をリセット", "de": "Einstellungen zurücksetzen", "fr": "Réinitialiser les paramètres", "es": "Restablecer configuración", "zh-Hant": "重置設定", "zh-Hans": "重置设置"},
    "alert.restart.title": {"ja": "再起動が必要", "de": "Neustart erforderlich", "fr": "Redémarrage requis", "es": "Reinicio necesario", "zh-Hant": "需要重新啟動", "zh-Hans": "需要重启"},
    
    # Viewer
    "viewer.status.active": {"ja": "アクティブ", "de": "AKTIV", "fr": "ACTIF", "es": "ACTIVO", "zh-Hant": "活躍", "zh-Hans": "活跃"},
    "viewer.status.paused": {"ja": "一時停止", "de": "PAUSIERT", "fr": "PAUSE", "es": "PAUSADO", "zh-Hant": "暫停", "zh-Hans": "暂停"},
}

def translate_xcstrings():
    if not os.path.exists(FILE_PATH):
        print(f"Error: File not found at {FILE_PATH}")
        return

    try:
        with open(FILE_PATH, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Error reading JSON: {e}")
        return

    strings = data.get('strings', {})
    count = 0

    for key, entry in strings.items():
        localizations = entry.get('localizations', {})
        
        # Check if we have a translation for this key
        # Handle specific keys and also fallback to key name if it matches (e.g. "Cancel")
        translation_map = TRANSLATIONS.get(key)
        
        if translation_map:
            for lang, trans_text in translation_map.items():
                if lang in localizations:
                    # Update existing new entry
                    if localizations[lang]['stringUnit']['state'] == 'new':
                        localizations[lang]['stringUnit']['value'] = trans_text
                        localizations[lang]['stringUnit']['state'] = 'translated'
                        count += 1
                else:
                    # Create if missing (though previous script should have added them)
                    localizations[lang] = {
                        "stringUnit": {
                            "state": "translated",
                            "value": trans_text
                        }
                    }
                    count += 1
        
        entry['localizations'] = localizations

    data['strings'] = strings

    try:
        with open(FILE_PATH, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"Successfully applied translations to {count} entries in {FILE_PATH}")
    except Exception as e:
        print(f"Error writing JSON: {e}")

if __name__ == "__main__":
    translate_xcstrings()
