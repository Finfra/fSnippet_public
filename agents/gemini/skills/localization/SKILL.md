---
name: SKILL
description: 다국어 지원(Localization) 작업(문자열 추출, 번역)을 수행합니다.
---

# Localization Skill (다국어 지원 스킬)

이 스킬은 fSnippet의 다국어 지원 프로세스를 자동화합니다. `xcstrings` 파일에서 `.strings` 파일을 추출하거나, AI 번역을 일괄 수행하는 기능을 제공합니다.

## 필수 조건 (Prerequisites)
- Python 3 설치 필요.
- `fSnippet/Resources` 내에 `Localizable.xcstrings` 또는 `Settings.xcstrings` 파일 존재.

## 사용법 (Usage)

`scripts` 디렉토리의 `localize.sh`를 실행하여 다양한 작업을 수행할 수 있습니다.

```bash
# 도움말 표시
sh .agent/skills/localization/scripts/localize.sh help

# 1. xcstrings -> strings 변환 (추출)
sh .agent/skills/localization/scripts/localize.sh extract

# 2. 일반 UI 문자열 번역
sh .agent/skills/localization/scripts/localize.sh translate

# 3. 설정(Settings) UI 문자열 번역
sh .agent/skills/localization/scripts/localize.sh translate-settings
```

## 기능 (Features)
- **Extract**: `xcstrings` 파일을 `lproj/*.strings` 형식으로 변환.
- **Translate**: 정의된 사전을 기반으로 한국어 -> 다국어 자동 번역 수행.
