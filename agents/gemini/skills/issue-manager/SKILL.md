---
name: SKILL
description: 이슈 등록, ID 생성, 이동 및 종결 처리를 자동화합니다.
---

# Issue Manager Skill (이슈 관리 스킬)

이 스킬은 `Issue.md` 파일을 파싱하여 이슈의 수명 주기를 관리합니다. 수동으로 마크다운 파일을 수정하는 번거로움과 오류를 줄여줍니다.

## 필수 조건 (Prerequisites)
- Python 3 설치 필요.
- 프로젝트 루트에 `Issue.md` 존재.

## 사용법 (Usage)

`scripts` 디렉토리의 `issue-manager.py`를 실행합니다.

```bash
# 도움말 표시
python3 .agent/skills/issue-manager/scripts/issue-manager.py --help

# 1. 이슈 등록 (Register)
# 자동으로 HWM을 증가시키고 ID를 발급합니다.
# --type: general (일반), candidate (후보), important (중요)
# 🚨 중복 방지: 동일한 제목이 존재하면 경고 메시지와 함께 중단됩니다.
# ⚠️ 후보 삭제: 등록 전 `🌱 이슈후보` 섹션에 해당 내용이 있다면 반드시 수동으로 삭제하세요. (Rule 5)
# 🇰🇷 언어 준수: 제목과 내용은 반드시 한국어로 작성해야 합니다. (Rule 1)
python3 .agent/skills/issue-manager/scripts/issue-manager.py register \
  --title "새로운 기능 추가" \
  --type candidate \
  --file "Issue.md" 

# 서브 이슈 등록 (Sub-issue)
# --parent-id 지정 시 HWM 증가 없이 "Issue392_1" 형태로 생성
python3 .agent/skills/issue-manager/scripts/issue-manager.py register \
  --title "세부 구현 사항" \
  --type general \
  --parent-id "Issue392" 



# 2. 이슈 종결 (Close)
# 해당 이슈를 찾아 '완료' 섹션으로 이동시키고 해시를 기록합니다.
python3 .agent/skills/issue-manager/scripts/issue-manager.py close \
  --id "Issue387" \
  --hash "a1b2c3d" \
  --file "Issue.md"
```

## 기능 (Features)
- **HWM 관리 (Self-Healing)**: 파일 상단의 `Issue HWM`과 실제 이슈 ID를 비교하여, 불일치 시 자동으로 HWM을 보정하고 ID를 발급합니다.
- **섹션 관리**: 지정된 타입(`seed`, `general` 등)의 섹션에 이슈 추가.
- **종결 처리 (Smart Close)**:
  - **서브 이슈**: 제자리에서 `✅ 완료` 상태로 변경 (이동하지 않음).
  - **부모 이슈**: 하위 서브 이슈를 포함한 전체 블록을 `✅ 완료` 섹션으로 이동.
