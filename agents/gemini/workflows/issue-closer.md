---
name: issue-closer
description: "이슈 종결 및 문서 업데이트 (Hash 확보 -> 완료 이동 -> Doc 커밋)"
---

# 이슈 종결 워크플로우

**역할**: 해결된 이슈를 `Issue.md`에서 '완료' 상태로 변경하고, **Commit Hash**를 기록하여 추적 가능성을 보장합니다.

> [! 주의] 에이전트 실행 제한
**DO NOT** 이 워크플로를 자동으로 실행하거나 명시적인 사용자 허가 없이 실행하지 마십시오.
이 워크플로는 사용자의 환경을 방해하는 장기 실행되는 배치 테스트와 UI 상호작용을 포함합니다.
`@[/qa-type-mgr]`를 실행하기 전에 항상 필요성을 설명하고 사용자에게 확인을 요청하십시오.

1.  **커밋 해시 확보 (Retrieve Commit Hash)**:
    - 터미널에서 `git log -1 --format="%h"` 명령을 실행하여 방금 해결(구현)한 커밋의 Hash를 가져옵니다.
    - **중요**: 이 Hash는 이슈 해결의 증거이므로 반드시 정확해야 합니다.

2.  **이슈 내용 업데이트 (Update Issue Details)**:
    - **중요**: 이슈 해결 과정에서 새롭게 알게 된 사실, 변경된 범위, 또는 기술적 세부 사항을 `Issue.md`의 해당 이슈 섹션에 추가합니다.
    - **포맷**: 이슈 번호는 반드시 **붙여쓰기(IssueXXX)** 형식을 사용합니다. (예: `## Issue603: ...`)
    - **필수 섹션**: 해결된 이슈는 반드시 `* 구현 명세` (또는 `* 구현`) 섹션을 포함하여 변경된 로직을 상세히 기술해야 합니다.
    - **주의**: 커밋 해시는 `issue-manager`가 자동으로 **제목**에 추가하므로, 본문에 `**Commit**: ...` 와 같이 중복 기록하지 마십시오.
    - 예시:
        - 원인: "초기 예상과 달리 `XYZManager`의 로직 오류가 원인이었음."
        - 구현 명세: "A 방식 대신 B 방식을 사용하여 `KeyEventProcessor` 로직을 개선함."
        - 추가: "관련된 `ABC.swift` 파일도 함께 리팩토링됨."

3.  **HWM 동기화 (Pre-Check)**:
    - `python3 agents/gemini/skills/issue-hwm/scripts/issue-hwm.py sync --file "Issue.md"`

4.  **이슈 종결 처리 (Close Issue via Skill)**:
    - **Issue Manager Skill**을 사용하여 이슈를 '**✅ 완료**' 섹션으로 이동시키고, 해시를 기록하여 종결 처리합니다.
    ```bash
    python3 agents/gemini/skills/issue-manager/scripts/issue-manager.py close \
      --id "Issue[번호]" \
      --hash "[Hash]" \
      --file "Issue.md"
    ```


5.  **Save Point 업데이트 (Update Save Point)**:
    - 이슈 종결 시점을 Save Point로 기록합니다.
    ```bash
    python3 agents/gemini/skills/issue-manager/scripts/issue-manager.py savepoint \
      --hash "[Hash]" \
      --msg "Close Issue[번호]" \
      --file "Issue.md"
    ```

6.  **문서 변경 사항 저장 (Commit Documentation via /git)**:
    - `agents/gemini/skills/git/scripts/git-wrapper.sh commit "Docs: Close Issue[번호] (Hash: [Hash])"`
