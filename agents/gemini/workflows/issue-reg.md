---
name: issue-reg
description: "이슈 등록 (HWM 확인 -> ID 발급 -> 파일 업데이트)"
---

# 이슈 등록 워크플로우

**역할**: 새로운 이슈를 `Issue.md`에 등록합니다.

> [!IMPORTANT]
> **등록 및 계획 전담 원칙**: 이 워크플로우는 이슈를 정식 ID로 등록하고 **계획(Planning)**을 수립하는 작업까지만 수행합니다. 
> 1. 사용자가 명시적으로 해결(Fix) 또는 구현(Implement)을 요청하기 전까지는 **절대로 `EXECUTION` 모드로 진입하지 않습니다.**
> 2. `PLANNING` 모드에서 `implementation_plan.md`를 승인받았더라도, 다음 단계인 구현으로 넘어가기 전 반드시 사용자의 확인을 한 번 더 받습니다.


## 📋 워크플로우 단계

0. **분석 및 계획 (Analysis & Planning) (필수)**
    - **Context Discovery (자산 탐색) (Critical)**:
        - **기존 자산 확인**: 관련 폴더나 파일이 이미 존재하는지 확인합니다 (`ls -R`, `find` 등).
        - **설정 확인**: `_rule.yml` 등의 설정 파일이 있다면 내용을 먼저 확인합니다 (`cat`).
        - **규칙 대조**: `snippet-rules.md` 등 프로젝트 규칙과 상충되지 않는지 확인합니다.
        - **가정 금지**: "이중 텍스트 prefix" 등 모호한 표현은 추측하지 말고, 확인된 사실(Fact) 기반으로 계획을 세웁니다.
    - `Issue.md`의 `## 🌱 이슈후보` 섹션과 사용자 입력을 분석합니다.
    - `task.md`에 다음 계획을 수립합니다:
        - **구체적 설계 포함 (필수)**: "기능 추가"와 같은 모호한 표현 금지.
            - **Bad**: "로직 수정", "버그 픽스", "리팩토링"
            - **Good**: "`AbbreviationMatcher.swift`의 `match()` 함수 내 접미사 처리 루프 수정", "`EventTapManager`의 `callback` 예외 처리 추가"
        - Main Issue와 Sub-issue의 계층 구조 정의
        - Main Issue와 Sub-issue의 계층 구조 정의
        - **이슈 후보 검색 및 삭제 (Rule 5)**: `Issue.md`의 `## 🌱 이슈후보` 섹션에 유사한 항목이 있다면 등록 전 반드시 삭제합니다.

1. **프로세스 규칙 검증 (Verify Process Rules)**:
    - **언어 준수 (Rule 1)**: 제목과 상세 내용은 반드시 **한국어**로 작성해야 합니다.
    - **포맷 준수**: 목적(Purpose)과 상세(Details) 섹션을 포함해야 합니다.
    - **레이아웃 준수**: 상세(Details) 필드의 서브 불렛(2차 불렛)은 반드시 **4칸 들여쓰기**를 사용해야 합니다.

4. **HWM 동기화 (Sync HWM)**:
    - 이슈 등록 전 HWM을 동기화하여 ID 충돌을 방지합니다.
    - `python3 agents/gemini/skills/issue-hwm/scripts/issue-hwm.py sync --file "Issue.md"`

5. **이슈 등록 (Register Issue via Skill)**:
    - **Issue Manager Skill**을 사용하여 이슈를 파일에 등록하고 ID를 발급받습니다.
    - **중요**: 이슈 등록 시 빈 껍데기만 만들지 말고, 반드시 **목적(Purpose)**과 **상세 계획(Detail)**을 포함해야 합니다.
    - **🚨 중복 방지**: 동일한 제목으로 재실행하면 스크립트가 Abort됩니다. 실패 시 제목을 변경하거나 기존 ID를 확인하십시오.
    
    **Type (`--type`) 옵션**:
    - `critical` (📕 중요): 즉시 해결이 필요한 버그나 핵심 기능
    - `normal` (📙 일반): 일반적인 기능 개선이나 버그 수정 (Default)
    - `optional` (📗 선택): 나중에 해도 되는 개선 사항이나 아이디어
    - **주의**: `candidate` (이슈후보)는 더 이상 사용하지 마십시오.

    ```bash
    python3 agents/gemini/skills/issue-manager/scripts/issue-manager.py register \
      --title "[이슈 제목]" \
      --type normal \
      --file "Issue.md" \
      --purpose "이슈의 목적을 한 줄로 요약" \
      --detail "    - 상세 구현 계획 1\n    - 상세 구현 계획 2"
    ```
    - **서브 이슈 등록 (Sub-issue)**:
        - 부모 이슈가 **진행 중**이면: 해당 부모 이슈 아래에 들여쓰기(`###`)로 등록됩니다.
        - 부모 이슈가 **완료(Closed)**되면: 새로운 독립 이슈(`##`)로 `📙 일반` 섹션에 등록됩니다. (ID는 `Parent_Child` 유지)
    ```bash
    python3 agents/gemini/skills/issue-manager/scripts/issue-manager.py register \
      --title "[서브 이슈 제목]" \
      --type normal \
      --parent-id "Issue392" \
      --purpose "서브 이슈 목적" \
      --detail "- 세부 사항"
    ```

6. **등록 확인 (Confirm Registration)**:
    - 이슈 등록이 완료되면 `Issue.md`에 정상적으로 반영되었는지 확인합니다.
    - **절대 금지**: 등록 과정에서 코드를 수정하거나 이슈를 종결(`Close`)하지 않습니다. 이미 구현된 기능이라도 반드시 계획 수립 후 사용자의 최종 컨펌을 거칩니다.

7. **후보 정리 (Cleanup Candidates)**:
    - `Issue.md`의 `## 🌱 이슈후보` 섹션에서 등록된 항목을 삭제합니다. (이중 등록 방지)

8. **Git 저장 (Commit matches)**:
    - `git add Issue.md`
    - `agents/gemini/skills/git/scripts/git-wrapper.sh commit "Docs: Register Issue[번호] and Cleanup Candidates"`

9. **TOC 검증 (Verify TOC)**:
    - 등록 후 `Issue.md`의 목차가 깨지지 않았는지(특히 헤더 아이콘 및 레벨) 확인합니다.
    - `📘 선택` 등 사용자 지정 헤더가 유지되는지 확인합니다.

10. **종료 및 보고 (Finalize & Report)**:
    - **🚨 작업 중단**: 이슈 등록이 완료되었습니다. 여기서 작업을 **즉시 종료**하십시오.
    - **자동 진행 금지**: 절대로 `/issue-fix`로 넘어가거나 코드를 수정하지 마십시오.
    - 사용자에게 "이슈 [ID]가 등록되었습니다."라고만 보고하고 대화를 마치십시오.
