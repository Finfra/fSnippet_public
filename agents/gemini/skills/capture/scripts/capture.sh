# _tool/capture.sh migrated to .agent/skills/capture/scripts/capture.sh
# Usage: sh .agent/skills/capture/scripts/capture.sh [target]

TARGET=$1
# Capture directory at project root
PROJECT_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
CAPTURE_DIR="${PROJECT_ROOT}/capture"
UTILS_DIR="$(dirname "$0")/utils"
TOOL_DIR="${PROJECT_ROOT}/_tool"

mkdir -p "$CAPTURE_DIR"

# --- Helper Functions ---

ensure_app_running() {
    PID=$(pgrep -f "MacOS/fSnippet")
    if [ -z "$PID" ]; then
        echo "App not running. Launching..."
        sh "${TOOL_DIR}/run.sh" &
        # Process launch wait
        count=0
        while [ -z "$(pgrep -f "MacOS/fSnippet")" ] && [ $count -lt 40 ]; do
             sleep 0.5
             count=$((count+1))
        done
        sleep 2
    fi
    # Activate App
    osascript -e 'tell application "fSnippet" to activate'
    sleep 0.5
}

close_settings_window() {
    echo "Closing any open Settings windows..."
    osascript -e '
    tell application "System Events"
        if exists process "fSnippet" then
            set proc to process "fSnippet"
            try
                set wins to every window of proc
                repeat with w in wins
                    try
                        set t to title of w
                        if t contains "설정" or t contains "Preferences" or t contains "Settings" then
                            click button 1 of w -- Close button
                        end if
                    end try
                end repeat
            end try
        end if
    end tell'
    sleep 0.5
}

capture_rect() {
    BOUNDS=$1
    NAME=$2
    OUTPUT_FILE="${CAPTURE_DIR}/screen_${NAME}.png"
    
    if [[ "$BOUNDS" == *"ERROR"* ]] || [[ -z "$BOUNDS" ]]; then
        echo "⚠️ Capture Failed for $NAME: $BOUNDS"
        # Don't exit, just return
        return 1
    else
        echo "Capturing $NAME with bounds: $BOUNDS"
        # Delay slightly to ensure UI is ready
        sleep 0.8
        screencapture -R"$BOUNDS" -x "$OUTPUT_FILE"
        
        if [ -s "$OUTPUT_FILE" ]; then
            echo "✅ Captured to $OUTPUT_FILE"
        else
            echo "❌ Capture failed (empty file): $OUTPUT_FILE"
        fi
    fi
}

capture_window() {
    WINDOW_TITLE_KEY=$1
    NAME=$2
    
    BOUNDS=$(osascript -e "
        tell application \"System Events\"
            if exists process \"fSnippet\" then
                set proc to process \"fSnippet\"
                try
                    -- 지원: 설정 (KR), Settings (EN)
                    set w to first window of proc whose (title contains \"$WINDOW_TITLE_KEY\" or title contains \"Settings\" or title contains \"설정\")
                    set p to position of w
                    set s to size of w
                    return (item 1 of p) & \",\" & (item 2 of p) & \",\" & (item 1 of s) & \",\" & (item 2 of s) as string
                on error
                    return \"ERROR: Window with '$WINDOW_TITLE_KEY' or 'Settings' or '설정' not found\"
                end try
            else
                return \"ERROR: Process not found\"
            end if
        end tell
    ")
    
    capture_rect "$BOUNDS" "$NAME"
}

# --- Main Logic ---

if [ -z "$TARGET" ]; then
    echo "Usage: $0 [target]"
    echo "Targets: 1, 2, 3, 4, 5, all, settings_..., clipboard, popup, popup_preview, popup_edit, clipboard_all, clipboard_preview, clipboard_regist, xcode"
    echo "Multiple targets can be separated by commas (e.g., 1,2,snippet,clipboard regist)"
    exit 1
fi

# 쉼표 기준 분리
IFS=',' read -ra ADDR <<< "$TARGET"
for raw_arg in "${ADDR[@]}"; do
    # Trim 공백 제거
    arg=$(echo "$raw_arg" | xargs)
    
    # 단축어 매핑
    case "$arg" in
        "1") CURRENT_TARGET="settings_general" ;;
        "2") CURRENT_TARGET="settings_snippets" ;;
        "3") CURRENT_TARGET="settings_folders" ;;
        "4") CURRENT_TARGET="settings_history" ;;
        "5") CURRENT_TARGET="settings_advanced_info" ;;
        "snippet") CURRENT_TARGET="pop_all" ;;
        "snippet edit"|"snippet_edit") CURRENT_TARGET="popup_edit" ;;
        "clipboard") CURRENT_TARGET="clipboard_all" ;;
        "clipboard regist"|"clipboard_regist"|"snippet regist") CURRENT_TARGET="clipboard_regist" ;;
        *) CURRENT_TARGET="$arg" ;;
    esac

    echo "▶️ Processing target: $CURRENT_TARGET"

    case "$CURRENT_TARGET" in
        "all")
            echo "📸 Running ALL captures..."
            sh $0 settings_general
            sh $0 settings_snippets
            sh $0 settings_folders
            sh $0 settings_history
            sh $0 settings_advanced_info
            sh $0 clipboard_all
            sh $0 popup
            sh $0 pop_all
            sh $0 popup_preview
            sh $0 popup_edit
            sh $0 clipboard_preview
            sh $0 clipboard_regist
            sh $0 xcode
            echo "🏁 All captures completed."
            ;;
        "settings_general")
            ensure_app_running
            echo "Switching to General Tab (Tab 0)..."
            swift "${UTILS_DIR}/switch-tab.swift" 0
            sleep 1.0
            capture_window "설정" "settings_general"
            ;;
            
        "settings_snippets")
            ensure_app_running
            echo "Switching to Snippets Tab (Tab 1)..."
            swift "${UTILS_DIR}/switch-tab.swift" 1
            sleep 1.0
            capture_window "설정" "settings_snippets"
            ;;
            
        "settings_folders")
            ensure_app_running
            echo "Switching to Folders Tab (Tab 2)..."
            swift "${UTILS_DIR}/switch-tab.swift" 2
            sleep 1.5 # Increased delay for reliability
            capture_window "설정" "settings_folders"
            ;;
            
        "settings_history")
            ensure_app_running
            echo "Switching to History Tab (Tab 3)..."
            swift "${UTILS_DIR}/switch-tab.swift" 3
            sleep 1.5
            capture_window "설정" "settings_history"
            ;;
            
        "settings_advanced_info")
            ensure_app_running
            echo "Switching to Advanced Tab (Tab 4) for Info..."
            swift "${UTILS_DIR}/switch-tab.swift" 4
            sleep 1.0
            # Scroll to top just in case
            osascript -e 'tell application "System Events" to key code 115' # Home key
            sleep 0.5
            capture_window "설정" "settings_advanced_info"
            ;;
            
        "settings_advanced_debug")
            ensure_app_running
            echo "Switching to Advanced Tab (Tab 4) for Debug..."
            swift "${UTILS_DIR}/switch-tab.swift" 4
            sleep 1.0
            # Scroll to bottom to show debug section
            osascript -e 'tell application "System Events" to key code 119' # End key
            sleep 0.5
            capture_window "설정" "settings_advanced_debug"
            ;;
            
        "clipboard")
            ensure_app_running
            close_settings_window
            
            # 1. Trigger Clipboard (Cmd + ;)
            echo "Triggering Clipboard (⌘;)..."
            osascript -e 'tell application "System Events" to keystroke ";" using command down'
            sleep 1.0 # Wait for animation
            
            # 2. Find Window with title "Clipboard History"
            BOUNDS=$(osascript -e '
            tell application "System Events"
                set proc to first process whose name is "fSnippet"
                try
                    set w to first window of proc whose title contains "Clipboard History"
                    set p to position of w
                    set s to size of w
                    return (item 1 of p) & "," & (item 2 of p) & "," & (item 1 of s) & "," & (item 2 of s) as string
                on error
                    return "ERROR: Clipboard window not found"
                end try
            end tell
            ')
            capture_rect "$BOUNDS" "clipboard"
            ;;
            
        "popup")
            ensure_app_running
            close_settings_window
            
            # 2. Trigger Popup (Notification based)
            echo "Triggering Popup via Notification..."
            swift "${UTILS_DIR}/trigger-popup-via-notification.swift"
            sleep 1.5
            sleep 1.5 # Wait a bit longer for animation
            
            # 3. Capture "SnippetPopupWindow" using new Title
            capture_window "SnippetPopupWindow" "popup"
            ;;

        "pop_all")
            ensure_app_running
            close_settings_window
            
            # 1. Trigger Popup (Notification based)
            echo "Triggering Popup via Notification..."
            swift "${UTILS_DIR}/trigger-popup-via-notification.swift"
            sleep 1.0
            
            # 2. Select First Item (Down Arrow) to trigger Preview
            echo "Selecting item to trigger preview..."
            osascript -e 'tell application "System Events" to key code 125'
            sleep 1.0
            
            # 3. Capture Union of "SnippetPopupWindow" and "SnippetPreviewWindow"
            echo "Calculating Union Bounds..."
            BOUNDS=$(swift "${UTILS_DIR}/get-union-bounds.swift" "SnippetPopupWindow" "SnippetPreviewWindow")
            capture_rect "$BOUNDS" "pop_all"
            ;;

        "popup_preview")
            ensure_app_running
            close_settings_window
            
            # 1. Trigger Popup (Notification based)
            echo "Triggering Popup via Notification..."
            swift "${UTILS_DIR}/trigger-popup-via-notification.swift"
            sleep 1.0
            
            # 2. Select First Item (Down Arrow) to trigger Preview
            echo "Selecting item to trigger preview..."
            osascript -e 'tell application "System Events" to key code 125'
            sleep 1.0
            
            # 3. Capture ONLY the Preview Window
            capture_window "SnippetPreviewWindow" "popup_preview"
            ;;
            
        "popup_edit")
            ensure_app_running
            close_settings_window
            
            # 1. Trigger Popup (Notification based)
            echo "Triggering Popup via Notification..."
            swift "${UTILS_DIR}/trigger-popup-via-notification.swift"
            sleep 1.0
            
            # 2. Select Item (Down Arrow) to enable Edit shortcut
            echo "Selecting item for edit..."
            osascript -e 'tell application "System Events" to key code 125'
            sleep 0.5
            
            # 3. Trigger Edit (Cmd+e)
            echo "Triggering Edit (⌘e)..."
            swift "${UTILS_DIR}/trigger-edit.swift"
            sleep 1.5 # Wait for editor to open
            
            # 4. Capture SnippetEditorWindow (Title: Edit Snippet)
            capture_window "Edit Snippet" "popup_edit"
            ;;

        "clipboard_all")
            ensure_app_running
            close_settings_window
            
            # 1. Check if Clipboard History is ALREADY open
            IS_OPEN=$(osascript -e 'tell application "System Events" to tell process "fSnippet" to exists (first window whose title is "Clipboard History")')
            
            if [ "$IS_OPEN" = "false" ]; then
                echo "Triggering Clipboard (⌘;)..."
                osascript -e 'tell application "System Events" to keystroke ";" using command down'
                sleep 1.0
            else
                echo "Clipboard History already open. Skipping trigger."
            fi
            
            # 2. Select Item (Down Arrow) just in case
            osascript -e 'tell application "System Events" to key code 125'
            sleep 0.5
            
            # 3. Capture Union of "Clipboard History" and "HistoryPreviewWindow"
            # We use a swift helper to get the union bounds
            echo "Calculating Union Bounds..."
            BOUNDS=$(swift "${UTILS_DIR}/get-union-bounds.swift" "Clipboard History" "HistoryPreviewWindow")
            capture_rect "$BOUNDS" "clipboard_all"
            ;;

        "clipboard_preview")
            ensure_app_running
            close_settings_window
            
            # 1. Trigger Clipboard if needed (Similar logic to preview_clipboard)
            IS_OPEN=$(osascript -e 'tell application "System Events" to tell process "fSnippet" to exists (first window whose title is "Clipboard History")')
            if [ "$IS_OPEN" = "false" ]; then
                echo "Triggering Clipboard (⌘;)..."
                osascript -e 'tell application "System Events" to keystroke ";" using command down'
                sleep 1.0
            fi
            
            # 2. Select Item to ensure Preview Window is visible
            osascript -e 'tell application "System Events" to key code 125'
            sleep 0.8
            
            # 3. Capture ONLY the Right Window
            capture_window "HistoryPreviewWindow" "clipboard_preview"
            ;;
            
        "clipboard_regist")
            ensure_app_running
            close_settings_window
            
            # 1. Trigger Clipboard if needed
            IS_OPEN=$(osascript -e 'tell application "System Events" to tell process "fSnippet" to exists (first window whose title is "Clipboard History")')
            if [ "$IS_OPEN" = "false" ]; then
                echo "Triggering Clipboard (⌘;)..."
                osascript -e 'tell application "System Events" to keystroke ";" using command down'
                sleep 1.0
            fi
            
            # 2. Select Item for regist
            echo "Selecting item for regist..."
            osascript -e 'tell application "System Events" to key code 125'
            sleep 0.5
            
            # 3. Trigger Regist (Cmd+s)
            echo "Triggering Regist (⌘s)..."
            swift "${UTILS_DIR}/trigger-regist.swift"
            sleep 1.5 # Wait for regist window to open
            
            # 4. Capture Regist Window (Title: Create New Snippet)
            capture_window "Create New Snippet" "clipboard_regist"
            ;;
            
        "xcode")
            OUTPUT_FILE="${CAPTURE_DIR}/xcode_capture.png"
            echo "Mode: Capture Xcode"
            osascript -e 'tell application "Xcode" to activate'
            sleep 0.5
            BOUNDS=$(osascript -e '
                tell application "System Events"
                    if exists process "Xcode" then
                        set proc to process "Xcode"
                        set w to window 1 of proc
                        set p to position of w
                        set s to size of w
                        return (item 1 of p) & "," & (item 2 of p) & "," & (item 1 of s) & "," & (item 2 of s) as string
                    else
                        return "ERROR: Xcode not found"
                    end if
                end tell
            ')
            capture_rect "$BOUNDS" "xcode_capture"
            ;;
            
        *)
            echo "Unknown mode: $CURRENT_TARGET"
            echo "Available modes: settings_..., clipboard, popup, pop_all, popup_preview, popup_edit, clipboard_all, clipboard_preview, clipboard_regist, xcode"
            ;;
    esac
done
