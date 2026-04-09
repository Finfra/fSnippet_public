---
name: SKILL
description: "UI 검증을 위해 애플리케이션의 특정 화면을 캡처하고 저장합니다."
---

# Capture Skill (UI 캡처 스킬)

이 스킬은 fSnippet 애플리케이션의 UI 변경 사항을 검증하기 위해 스크린샷을 자동으로 캡처합니다.

## 필수 조건 (Prerequisites)
- fSnippet 앱이 실행 가능해야 함 (실행 중이 아니면 자동 실행 시도)
- `screencapture` 명령어가 사용 가능한 macOS 환경

## 사용법 (Usage)

`scripts` 디렉토리의 `capture.sh`를 실행하여 캡처를 수행합니다.

### 명령어
```bash
/bin/bash .agent/skills/capture/scripts/capture.sh [target]
```

### Target 옵션
- `all`: 모든 타겟 캡처
- `settings_general`: 설정 > 일반 탭
- `settings_snippets`: 설정 > 스니펫 탭
- `settings_folders`: 설정 > 폴더 탭
- `settings_history`: 설정 > 히스토리 탭
- `settings_advanced_info`: 설정 > 고급 > 정보
- `settings_advanced_debug`: 설정 > 고급 > 디버그
- `clipboard`: 클립보드 히스토리 창
- `popup`: 스니펫 팝업 창
- `pop_all`: 스니펫 팝업 + 프리뷰 창
- `popup_preview`: 스니펫 프리뷰 창만
- `clipboard_all`: 클립보드 히스토리 + 프리뷰 창
- `clipboard_preview`: 클립보드 프리뷰 창만
- `xcode`: Xcode 창

## 출력 (Output)
캡처된 이미지는 프로젝트 루트의 `capture/` 디렉토리에 저장됩니다.
