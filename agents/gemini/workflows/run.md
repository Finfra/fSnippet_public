---
name: run
description: "애플리케이션 빌드 및 실행 (옵션: 설정창 열기)"
---

# 앱 빌드 및 실행 워크플로우

0. **디버그 로깅 활성화 (Optional)**:
   - 상세한 로그를 확인하려면 아래 명령어를 실행하여 디버그 로깅을 활성화합니다.(처음 한번만 유저가 실행하면 작동)
   ```bash
   defaults write com.nowage.fSnippet debug_logging -bool true
   ```

1. **옵션 선택**:
   - 사용자에게 실행 모드를 확인합니다.

2. **스크립트 실행**:
   
   **옵션 A: 일반 빌드 및 실행 (Build & Run)**
   ```bash
   bash _tool/run.sh
   ```

   **옵션 B: 빌드 및 실행 후 설정창 열기 (Settings)**
   - 탭 지정 가능: `Cmd+1`(General) ~ `Cmd+5`(Advanced)
   ```bash
   # 1. Build & Run
   sh _tool/run.sh
   
   # 2. Open Settings (Cmd+,)
   echo "⏳ Waiting for app launch..."
   sleep 3
   # 설정창 열기 (Cmd+,)
   osascript -e 'tell application "System Events" to tell process "fSnippet" to keystroke "," using command down'
   
   # (선택) 특정 탭으로 이동 (예: Advanced 탭 = Cmd+5)
   # osascript -e 'tell application "System Events" to tell process "fSnippet" to keystroke "5" using command down'
   echo "✅ App Running with Settings Window"
   ```

   **옵션 C: 스니펫 팝업 열기 (Popup)**
   ```bash
   # 1. Build & Run
   sh _tool/run.sh
   sleep 3
   osascript -e 'tell application "System Events" to tell process "fSnippet" to click menu item "스니펫 팝업 열기" of menu "fSnippet" of menu bar 1'
   ```

   **옵션 D: 클립보드 히스토리 열기 (Clipboard)**
   ```bash
   # 1. Build & Run
   sh _tool/run.sh
   sleep 3
   osascript -e 'tell application "System Events" to tell process "fSnippet" to click menu item "클립보드 히스토리 열기" of menu "fSnippet" of menu bar 1'
   ```

3. **실행 대기**:
   - 앱이 실행되고 원하는 창이 뜰 때까지 기다립니다.

4. **성공 여부 확인 (Verify Success)**:
   - 앱이 실행된 후 **런타임 에러(Crash)** 없이 동작하는지 확인이 필요합니다.
   - **`/log-monitor` 워크플로우를 사용**하여 초기 구동 로그를 점검하는 것을 권장합니다.

## 문제 해결 (Troubleshooting)
빌드가 실패하거나 앱이 실행되지 않을 경우 **Build Doctor Skill**을 참고하세요.
- **스킬 경로**: `agents/gemini/skills/build-doctor/SKILL.md`
- **빠른 복구**: `DerivedData` 삭제 및 `Clean Build` 시도
  ```bash
  rm -rf ~/Library/Developer/Xcode/DerivedData/fSnippet-*
  xcodebuild -scheme fSnippet -configuration Debug clean
  ```
