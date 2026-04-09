---
name: SKILL
description: 프로젝트 규칙(.agent/rules)을 관리, 등록, 동기화하는 스킬
---

# Rule Manager Skill

이 스킬은 `fSnippet` 프로젝트의 규칙 파일들(`.agent/rules/*`)을 체계적으로 관리하기 위한 도구입니다. 
규칙 파일의 등록, 업데이트, 유효성 검사, 그리고 프로젝트 문서 내 참조 동기화를 자동화합니다.

## 기능 (Capabilities)

### 1. 규칙 등록 (Register)
새로운 마크다운 규칙 파일을 `.agent/rules` 디렉토리에 등록하고, `README.md` 목록을 업데이트합니다.

*   **스크립트**: `.agent/skills/rule-manager/scripts/register-rule.sh`
*   **사용법**: `./register-rule.sh [소스파일경로] [규칙명]`
*   **예시**: `./register-rule.sh _doc/new_rule.md my_new_rule`

### 2. 규칙 동기화 (Sync)
프로젝트 내 문서(`*.md`)들을 스캔하여, 과거의 규칙 파일 경로(예: `.agent/rules/issue_rules.md`)를 새로운 `.agent/rules` 경로로 일괄 업데이트합니다.

*   **스크립트**: `.agent/skills/rule-manager/scripts/sync-rules.py`
*   **사용법**: `python3 sync-rules.py`
*   **대상**: `.md` 파일들 (제외: `.git`, `build` 등)

## 사용 규칙 (Rules)

1.  **Source of Truth**: 모든 규칙은 `.agent/rules`에 위치해야 합니다.
2.  **Naming**: 규칙 파일명은 `[topic]_rules.md` 형식을 권장합니다. (예: `logging_rules.md`)
3.  **Cross-Reference**: 규칙 파일 내에서 다른 규칙을 참조할 때는 반드시 `[name](name.md)`와 같이 상대 경로를 사용합니다.

## 관련 워크플로우

*   `/rule-mgr`: 규칙 관리 통합 워크플로우
*   `/snippet-rules`: 스니펫 규칙 특화 워크플로우
