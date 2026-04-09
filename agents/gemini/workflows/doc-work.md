---
name: doc-work
description: "코드 분석을 통한 _doc_work 폴더 내 작업/가이드 문서 업데이트"
---

1. **대상 문서 확인 (Identify Target)**:
   - 사용자가 요청한 `_doc_work/` 폴더 내의 파일을 확인합니다.
   - **주요 관리 대상 (전체 목록)**:
     - `debug_TECH.md` / `debug_HISTORY.md`: 분야별 디버깅 가이드 및 이력을 모아둔 허브(Hub) 문서
     - `debug/debug_*.md`: 분야별(CORE, UI, DATA, SYSTEM) 실제 디버깅 이력 및 기술 해결책 문서
     - `work_COMPLETE_FEATURES.md`: 완성된 기능 목록
     - `work_SNIPPETS.md`: 스니펫 관련 작업 기록
     - `.agent/rules/issue_rules.md`: 이슈 관리 규칙 (구 `issue_RULE.md`)
     - `reference_COMMANDS.md`: 개발 및 운영 명령어
     - `work_BUILD_TEST.md`: 빌드 및 테스트 가이드
     - `work_CAPTURE.md`: 캡처/디버깅 워크플로우
     - `work_DEPLOY.md`: 배포 가이드
     - `work_GIT.md`: Git 워크플로우 가이드
     - `work_MANUAL.md`: 수동 작업 가이드
     - `work_ShortcutMgr.md`: 단축키 관리자 문서 (완료 시 `_doc_design`으로 이동)
     - `Issue_*.md`: 이슈 관련 문서
     - `guide_CONTEXT7.md`: Context7 MCP 가이드

   - **폴더 정리 규칙 (Folder Organization)**:
     - **`issue_OLD.md`는 언제나 `_doc_work`에 그대로 유지합니다.** (절대 이동/삭제 금지)
     - **`noteForHuman*.md` 파일은 절대 이동하거나 삭제하지 않습니다.** (이 파일들은 사람이 직접 작성/관리하는 노트입니다)
     - **설계/아키텍처/스펙 성격**으로 발전한 작업 문서는 `_done`으로 옮기지 말고 **`_doc_design` 폴더로 이동**시킵니다.
     - 다음에 동일한 실수가 발생하지 않도록 이 규칙을 엄수합니다.

2. **작업 내용 분석 (Analyze Work/Code)**:
   - **이슈 해결 시**: 해결된 이슈의 원인과 해결 방법을 코드에서 분석합니다. (`debug_*.md` 업데이트용)
   - **기능 구현 시**: 새로 추가되거나 변경된 기능을 코드에서 확인합니다. (`work_COMPLETE_FEATURES.md` 업데이트용)
   - **스니펫 작업 시**: `snippets.alfdb` 또는 스니펫 파일 변경 사항을 확인합니다.
   - **운영 절차 변경 시**: `work_*.md` (Git, Deploy, Build 등) 파일을 확인하고 업데이트합니다.
   - **Context7 활용 시**: `guide_CONTEXT7.md`를 참고하여 올바른 사용법을 확인합니다.
   - **검증 스크립트 확인**: `_tool/verify/` 폴더에 관련 테스트 스크립트가 있다면 문서에 참조를 추가합니다.

3. **문서 업데이트 (Update Document)**:
   - 분석된 내용을 바탕으로 문서를 최신 상태로 업데이트합니다.
   - **디버깅 문서**: 문제 현상 -> 원인 -> 해결 방법(Code Snippet 포함) 구조로 작성합니다.
   - **기능 목록**: 기능의 목적과 사용법을 명확히 기술합니다.
   - 모든 내용은 한국어로 작성합니다.

4. **검증 (Verify)**:
   - 업데이트된 내용이 실제 코드 및 시스템 동작과 일치하는지 확인합니다.
