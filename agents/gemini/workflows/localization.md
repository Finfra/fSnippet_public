---
name: localization
description: "다국어 지원(Localization) 작업 워크플로우 (문자열 추출, 번역, 검증)"
---

1. **작업 준비 (Preparation)**:
   - `Resources/` 폴더 내의 `.xcstrings` 또는 `.strings` 파일을 확인합니다.
   - 새로운 UI 텍스트가 추가되었는지 확인합니다.

2. **문자열 추출 및 변환 (Extract & Convert)**:
   - `Localizable.xcstrings`가 Source of Truth인 경우, 이를 `lproj` 폴더 구조로 변환합니다.
   // turbo
   ```bash
   sh .agent/skills/localization/scripts/localize.sh extract
   ```

3. **번역 스크립트 실행 (Translate)**:
   - 새로운 텍스트에 대한 자동 번역을 수행합니다.
   - **일반 UI**:
     // turbo
     ```bash
     sh .agent/skills/localization/scripts/localize.sh translate
     ```
   - **설정(Settings) UI**:
     // turbo
     ```bash
     sh .agent/skills/localization/scripts/localize.sh translate-settings
     ```

4. **누락 및 검증 (Verify)**:
   - (필요 시) `_tool/verify/` 폴더 내의 관련 검증 스크립트를 확인하거나 실행합니다.

5. **UI 확인 (UI Check)**:
   - 앱을 실행하여 언어 설정 변경 시 텍스트가 올바르게 표시되는지, 레이아웃 깨짐은 없는지 확인합니다.
