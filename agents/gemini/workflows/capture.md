---
name: capture
description: "설정창 UI 캡처 워크플로우 (스크린샷 -> 문서화/검증)"
---

1. **앱 실행 (Run App)**:
   - `/run` 워크플로우를 통해 앱을 실행합니다. (빌드 에러 확인 가능)

2. **UI 준비 (Prepare Target UI)**:
   - 캡처할 대상 창을 엽니다.

   **A. 설정창 (Settings Window)**
   ```bash
   # 1. Build & Run
   sh _tool/run.sh
   
   # 2. Open Settings (Cmd+,)
   sleep 3
   osascript -e 'tell application "System Events" to tell process "fSnippet" to keystroke "," using command down'
   ```

   **B. 스니펫 팝업 / 클립보드 창 (Popup / Clipboard)**
   ```bash
   # Build & Run and Click Popup Menu
   # (메뉴바 항목 클릭 로직은 run.sh에 없으므로 별도 실행 필요할 수 있으나, run.md 참조)
   sh _tool/run.sh
   sleep 2
   osascript -e 'tell application "System Events" to tell process "fSnippet" to click menu item "스니펫 팝업 열기" of menu "fSnippet" of menu bar 1'
   
   # 또는 클립보드 히스토리
   # sh _tool/run.sh
   # sleep 2
   # osascript -e 'tell application "System Events" to tell process "fSnippet" to click menu item "클립보드 히스토리 열기" of menu "fSnippet" of menu bar 1'
   ```

3. **캡처 대상 확인 (Identify Target)**:
   - **다중 캡처 가능**: `1,2,snippet,clipboard regist` 처럼 쉼표로 연결 가능
   - **탭 이름 (설정창인 경우)**:
     - `1` 또는 `settings_general`: 일반
     - `2` 또는 `settings_snippets`: 스니펫
     - `3` 또는 `settings_folders`: 폴더
     - `4` 또는 `settings_history`: 히스토리
     - `5` 또는 `settings_advanced_info`: 고급 (정보)
   - **창 이름 (팝업/클립보드인 경우)**:
     - `snippet` 또는 `pop_all`: 스니펫 팝업 + 프리뷰 (Union)
     - `snippet edit` 또는 `popup_edit`: 스니펫 편집창 (Cmd+e)
     - `popup_preview`: 스니펫 프리뷰 (단독)
     - `clipboard` 또는 `clipboard_all`: 클립보드 히스토리 + 프리뷰 (Union)
     - `clipboard regist` / `snippet regist` / `clipboard_regist`: 클립보드 창에서 등록 화면 열기 (Cmd+s)
     - `clipboard_preview`: 클립보드 프리뷰 (단독)
     - `popup` / `clipboard` (과거방식): 각 리스트 창 (단독)
   - *참고: `_doc_work/work_CAPTURE.md` 확인*

4. **캡처 실행 (Execute Capture)**:
   - `.agent/skills/capture/scripts/capture.sh` 통합 스크립트를 사용합니다.
   // turbo
   ```bash
   # 사용법: sh .agent/skills/capture/scripts/capture.sh [대상]
   # 대상: 1, 2, 3, 4, 5, all, settings_..., clipboard, popup, popup_edit, clipboard_all, clipboard_regist...
   
   # 예: 고급(Advanced) 탭 캡처
   sh .agent/skills/capture/scripts/capture.sh 5
   
   # 예: 설정창 1번~3번 연속 캡처 (User Request)
   sh .agent/skills/capture/scripts/capture.sh 1,2,3

   # 예: 스니펫 팝업 + 프리뷰 캡처
   sh .agent/skills/capture/scripts/capture.sh snippet

   # 예: 편집창 / 스니펫 등록창 캡처
   sh .agent/skills/capture/scripts/capture.sh "snippet edit"
   sh .agent/skills/capture/scripts/capture.sh "clipboard regist"

   # 일괄 캡처 (모든 항목) - 권장
   sh .agent/skills/capture/scripts/capture.sh all
   ```

5. **결과 확인 (Check Result)**:
   - 캡처된 이미지는 `capture/` 폴더에 저장됩니다. (예: `screen_4_rect.png`)
   // turbo
   ```bash
   open capture/
   ```

6. **활용 (Usage)**:
   - 캡처된 이미지를 `walkthrough`나 이슈 문서(`Issue.md`)에 첨부하여 증거 자료로 활용합니다.
