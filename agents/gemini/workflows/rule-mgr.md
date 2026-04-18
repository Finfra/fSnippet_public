---
name: rule-mgr
description: "프로젝트 규칙 관리 통합 워크플로우 (등록, 동기화, 업데이트)"
---

# Rule Management Workflow

`/rule-mgr` 명령어를 사용하여 프로젝트 규칙을 관리합니다.

## 1. 규칙 동기화 (Sync)
문서 내의 규칙 참조가 깨졌거나 업데이트가 필요할 때 실행합니다.

```bash
python3 agents/gemini/skills/rule-manager/scripts/sync-rules.py
```

## 2. 새 규칙 등록 (Register)
새로운 규칙 파일을 생성하고 등록할 때 사용합니다.

1.  규칙 파일 초안 작성
2.  등록 스크립트 실행:
    ```bash
    sh agents/gemini/skills/rule-manager/scripts/register-rule.sh [소스파일] [규칙명]
    ```
    (예: `sh agents/gemini/skills/rule-manager/scripts/register-rule.sh _doc_design/new_design.md new_rules`)

## 3. 규칙 업데이트 (Update)
기존 규칙을 수정할 때는 해당 파일을 직접 편집한 후, 필요한 경우 동기화를 다시 수행합니다.

1.  `.claude/rules/[규칙명].md` 파일 수정
2.  변경 내역 커밋
