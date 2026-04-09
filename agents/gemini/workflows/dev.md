---
name: dev
description: "전체 개발 주기 통합 워크플로우 (인수 지원: 자동 또는 특정 후보 즉시 착수)"
---

**역할**: 개발 주기를 관리합니다. 인자가 없으면 자동 우선순위(`issue`)를 따르고, 인자가 있으면 특정 후보를 즉시 착수합니다.

> [!WARNING] 필수 규칙 (CRITICAL)
> **어떠한 코드 작업(기능 추가, 버그 수정 등)을 진행하기 전에도 반드시 `Issue.md`에 새로운 이슈를 생성(발급)하고 `# 🚧 진행중` 상태로 등록해야 합니다.** 
> **이슈 생성(Issue ID 발급 및 Issue.md 업데이트) 없이 로직을 먼저 수정하거나 작업을 진행하는 것은 엄격히 금지됩니다.**

## 사용법
- `/dev`: 자동 모드 (기존 `/issue` 로직)
- `/dev [N]`: `Issue.md`의 후보 [N]번을 즉시 등록 및 진행


---

## 1. 작업 대상 결정 (Determine Target)

### Case A: 인자가 있는 경우 (Specific Target Mode)
*예: `/dev 2`*

1.  **대상 식별**:
    - `# 🌱 이슈후보` 섹션에서 해당 번호(`N. ...`)로 시작하는 항목을 찾습니다.

2.  **즉시 등록 (Register as In-Progress)**:
    - `/issue-reg` 워크플로우의 **"0. 분석 및 계획 (Analysis & Planning)"**을 반드시 수행합니다.
    - **필수**: 이슈 등록 시 **`--purpose`와 `--detail` 인자를 반드시 작성**하여 내용이 비어있는 이슈가 생성되지 않도록 합니다. (분석 내용 기반)
    - **중요**: 단순히 등록하는 것이 아니라, `task.md`를 통해 **구체적인 구현 로직(파일, 함수, 변경 내역)**을 설계한 후 등록해야 합니다.
    - **중요**: 생성된 이슈를 즉시 **`# 🚧 진행중`** 섹션에 등록합니다. (우선순위/후보 섹션 건너뜀)
    - 기존 후보 항목(`N. ...`)은 삭제합니다.

3.  **해결 진행 (Fix)**:
    - 방금 등록한 이슈에 대해 `/issue-fix` 워크플로우를 실행합니다.

### Case B: 인자가 없는 경우 (Auto Mode)
*예: `/dev`*

1.  **작업 계획 및 이슈 생성 (Mandatory)**:
    - 사용자가 요청한 작업 내역을 바탕으로 해결 방안을 분석합니다.
    - **실제 코드를 수정하기 전에**, `/issue-reg` 워크플로우를 실행하여 `Issue.md`에 새 이슈를 정식 등록합니다.
    - **필수**: 이슈 등록 시 **`--purpose`와 `--detail` 인자를 반드시 작성**하여 내용이 비어있는 이슈가 생성되지 않도록 합니다. (분석 내용 기반)
    - **중요**: 단순히 등록하는 것이 아니라, `task.md`를 통해 **구체적인 구현 로직(파일, 함수, 변경 내역)**을 설계한 후 등록해야 합니다.
    - 등록된 이슈를 **`# 🚧 진행중`** 섹션으로 이동합니다. (또는 기존에 등록된 이슈를 `# 🚧 진행중`으로 이동)

2.  **해결 진행 (Fix)**:
    - `Issue.md`에 이슈가 정상적으로 생성된 것을 확인한 후, 비로소 코드를 수정하고 작업을 진행합니다 (`/issue-fix` 워크플로우 참조).

## 2. 추가 검증 (Additional Verification)
- 앱을 실행해 최종 확인이 필요한 경우 `/run`을 사용합니다.
- **UI 변경이 포함된 경우**: `/capture` 워크플로우를 실행하여 스크린샷을 남깁니다.

## 3. 작업 결과 등록 (Update Artifacts)
- **Walkthrough 등록**: `walkthrough.md`가 생성/갱신되면 아래 명령으로 이슈에 연결합니다.
    ```bash
    python3 .agent/skills/issue-manager/scripts/issue-manager.py link --id "Issue[번호]" --url "walkthrough.md" --title "Walkthrough"
    ```

## 4. 이슈 종결 및 동기화 (Close & Push)
> [!WARNING] 완료 선언 프로토콜 (CRITICAL)
> 작업을 마치기 전에 **반드시** 아래 절차(Rule)를 순서대로 모두 완수해야 합니다! 
> 1. **Code Commit**: 수정한 로직 코드를 커밋합니다 (`git commit -m "Fix: IssueXXX ..."`).
> 2. **Get Hash**: 직전 코드 커밋의 Hash를 가져옵니다 (`git log -1 --format="%h"`).
> 3. **Update Issue.md**: `/issue-closer` 워크플로우를 실행하여 `Issue.md`에 이슈를 종결 처리하고, 해당 커밋 해시를 본문과 Save Point에 기록합니다. (스크립트 혹은 수동 편집)
> 4. **Doc Commit**: 갱신된 `Issue.md` 파일을 `Docs: Close IssueXXX (Hash: ...)` 메시지와 함께 커밋합니다.
> 5. **say 'Complished'**: 터미널에서 `say 'Complished'`를 실행합니다. **이 명령어는 반드시 이슈 관리(1~4번)가 모두 끝난 "가장 마지막"에 호출해야 합니다.**

- `/issue-closer` 과정을 마친 후, `/git` 워크플로우를 실행하여 원격 저장소에 Push 합니다.
- 위 `say 'Complished'` 명령어 호출을 끝으로 최종적으로 `/dev` 워크플로우를 종료합니다.
