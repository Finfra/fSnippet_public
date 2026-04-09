---
name: git
description: "Git 작업 수행 (status, add, commit, push 또는 일괄 처리)"
---

**사용법**: `/git [command] [options]`
*   `/git`: (기본값) 전체 흐름 진행 (Status -> Add -> Commit -> Push)
*   `/git status`: 상태 확인
*   `/git add`: 변경사항 스테이징 (기본: `git add .`)
*   `/git commit`: 커밋 (메시지 필요)

*   `/git pull`: 원격 풀 (Pull)
*   `/git push`: 원격 푸시 (Safe Point 확인 포함)

---

1. **스킬 실행 (Execute Skill)**:
    - `.agent/skills/git/scripts/git-wrapper.sh`를 사용하여 Git 작업을 수행합니다.

    **Case: `status`**
    ```bash
    sh .agent/skills/git/scripts/git-wrapper.sh status
    ```

    **Case: `add`**
    ```bash
    sh .agent/skills/git/scripts/git-wrapper.sh add
    # 또는 특정 파일
    # sh .agent/skills/git/scripts/git-wrapper.sh add [filename]
    ```

    **Case: `commit`**
    ```bash
    sh .agent/skills/git/scripts/git-wrapper.sh commit "[메시지]"
    ```

    **Case: `push`**
    ```bash
    # 내부적으로 Save Point(Issue.md)를 검증합니다.
    sh .agent/skills/git/scripts/git-wrapper.sh push
    ```

    **Case: `pull`**
    ```bash
    sh .agent/skills/git/scripts/git-wrapper.sh pull
    ```

    **Case: `Auto` (파라미터 없음 / 전체 진행 or 부분 선택) or `All`**
    ```bash
    sh .agent/skills/git/scripts/git-wrapper.sh auto "[메시지]" [파일경로]
    # 또는
    sh .agent/skills/git/scripts/git-wrapper.sh all "[메시지]"
    ```

3. **검증 (Verify)**:
    - 각 단계의 Exit Code가 0인지 확인합니다.
