---
name: skill-mgr
description: "스킬 관리 및 개선 (생성/수정 -> 표준화)"
---

# Skill Management Workflow

`/skill-mgr` 명령어를 사용하여 에이전트 스킬(`.agent/skills/`)을 관리합니다.

## 1. 스킬 니즈 분석 (Analyze Needs)
- 새로운 기능이 필요하거나 기존 스킬의 개선이 필요한지 분석합니다.
- 복잡한 로직이나 외부 스크립트 실행이 필요한 작업을 식별합니다.

## 2. 스킬 생성/수정 (Create or Modify)
1.  **디렉토리 생성**: `.agent/skills/[스킬명]/`
2.  **문서 작성**: `SKILL.md` (필수, 한국어 작성)
    - 기능(Capabilities), 사용법(Usage), 관련 파일(Dependencies) 정의
3.  **스크립트 구현**: `scripts/` 서브디렉토리에 필요한 스크립트(`*.sh`, `*.py`) 구현

## 3. 검증 (Verify)
- 스킬이 의도대로 동작하는지 테스트합니다.
- `workflow`에서 해당 스킬을 호출하여 통합 테스트를 수행합니다.

## 4. 참조 문서 업데이트
- `AGENTS.md`의 스킬 목록을 업데이트합니다.
