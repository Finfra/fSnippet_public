---
name: SKILL
description: 이슈 파일의 HWM(High Water Mark)을 검사하고 실제 데이터와 동기화(Self-Healing)합니다.
---

# Issue HWM Manager Skill (이슈 HWM 관리 스킬)

`Issue.md`의 HWM(최고 이슈 번호)이 실제 이슈 내역과 일치하지 않는 문제를 해결합니다.
이 스킬은 **Self-Healing** 메커니즘을 통해 모든 이슈 번호를 스캔하고, 헤더의 HWM 값이 실제보다 낮으면 자동으로 업데이트합니다.

## 필수 조건 (Prerequisites)
- Python 3 설치 필요.

## 사용법 (Usage)

`scripts/issue-hwm.py`를 실행합니다.

```bash
# 동기화 실행 (기본 Issue.md 대상)
python3 .agent/skills/issue-hwm/scripts/issue-hwm.py sync


```

## 워크플로우 통합 (Workflow Integration)
주로 `/issue-reg`와 같이 새 ID 발급이 필요한 워크플로우의 **Pre-flight Check** 단계에서 사용됩니다.

```markdown
1. **HWM 동기화 (Pre-flight Sync)**:
   - `python3 .agent/skills/issue-hwm/scripts/issue-hwm.py sync --file "Issue.md"`
```
