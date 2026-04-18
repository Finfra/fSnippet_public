---
name: issue-fix
description: "이슈 해결 및 완료 처리 (Fix -> Verify -> Doc -> Close) 워크플로우"
---

# 이슈 해결 워크플로우

1.  **문제 분석 및 재현 (Analyze & Reproduce)**:
    - 이슈의 원인을 분석합니다. (`_doc_work/debug_HISTORY.md` 허브 및 `debug_*.md` 참조)
    - **UI 이슈인 경우**: `/capture` 워크플로우를 실행하여 **'Before' 상태(문제 화면)**를 캡처해 둡니다.
    - 가능하다면 `_tool/verify/` 폴더에 재현 스크립트를 작성하거나 기존 스크립트를 활용합니다.

2.  **구현 (Implement Fix)**:
    - 코드를 수정합니다.
    - **커밋 메시지 규칙**: `Fix: Issue[번호] [제목]` 형식으로 작성합니다.

3.  **검증 (Verify)**:
    - **빌드 및 동작 확인**: `/run` 워크플로우를 실행합니다.
    - **UI 검증 (필수)**: `/capture` 워크플로우를 실행하여 **'After' 상태(해결 화면)**를 캡처합니다.
        - 캡처된 이미지 파일명(`screen_...png`)을 확인하고 `design_ui.md` 가이드를 준수하는지 점검합니다.
    - **기능 검증**: 작성한 재현 스크립트나 `TestBoard.txt`와 `/qa-type-do`를 통해 로직이 정상 동작하는지 확인합니다.

4.  **문서화 (Document)**:
    - **필수**: 성격에 맞는 분야별 디버깅 문서(`_doc_work/debug/debug_*.md`)에 해결 과정을 기록합니다.
        - 내용: 증상, 원인, 해결 방법
        - **증거 자료**: 캡처한 이미지 파일명을 함께 기록합니다.
    - **선택 (설계 변경 시)**: 아키텍처나 클래스 구조가 변경되었다면 즉시 실행합니다.
        ```bash
        @[/doc-design]
        ```
    - **선택**: 기술적으로 중요한 내용이면 성격에 맞는 `_doc_work/debug/debug_*.md`의 Tech 섹션에도 기록합니다.

5.  **이슈 종결 (Close Issue)**:
    - **`/issue-closer` 워크플로우를 실행합니다.**
