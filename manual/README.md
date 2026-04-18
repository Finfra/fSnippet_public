---
title: fSnippet 매뉴얼 개요 (Manual Structure Overview)
description: fSnippet 사용자/개발자 매뉴얼 상위 구조 및 작성 가이드
date: 2026-03-26
---

본 문서는 fSnippet 사용자/개발자 매뉴얼의 상위 구조와 작성 가이드를 정의합니다. 실제 세부 문서는 본 구조에 따라 하위 파일로 확장합니다.

# 목적과 범위
* 대상: 일반 사용자(설치/사용), 파워유저(고급 기능), 개발자(빌드/디버깅)
* 범위: 설치 → 빠른 시작 → 사용자 가이드 → 규칙/고급 기능 → 디버깅/레퍼런스 → FAQ/릴리스/부록
* 규칙: 모든 링크는 리포지토리 루트 기준 상대 경로 사용, 한국어 우선

# 디렉토리 구조(제안)
* 01_Overview/
  - Introduction.md: 제품 개요, 주요 기능, 기본 개념(트리거/스니펫/컬렉션)
  - Architecture.md: 아키텍처 요약 및 다이어그램 링크
    - 참조: `_doc_design/ARCHITECTURE.md`, `_doc_design/diagram_COMPONENT.mermaid`, `_doc_design/diagram_CLASS.mermaid`, `_doc_design/diagram_SEQUENCE.mermaid`
* 02_Install/
  - Install_macOS.md: 요구사항, 설치 방법, 첫 실행 체크리스트
  - Permissions.md: 접근성/자동화 권한 설정 가이드(스크린샷/검증 절차)
* 03_QuickStart/
  - QuickStart.md: 표준 5단계 흐름(빌드 → 테스트보드 초기화 → 실행 → 테스트보드 열기 → 실시간 로그)
    - 참조: `_doc_work/reference_COMMANDS.md`, `_doc_work/work_BUILD_TEST.md`
* 04_UserGuide/
  - UsingSnippets.md: 스니펫 입력/확장, 팝업 사용법, 기본 트리거키
  - Triggers.md: 트리거키/Prefix/Suffix 동작, 컬렉션 규칙 적용
  - Settings.md: 일반/스니펫/고급 탭 사용법 및 주요 옵션
* 05_SnippetRules/
  - Rules.md: 스니펫 파일 규칙, 컬렉션 규칙, `_rule.yml` 개요
    - 참조: `.agent/rules/snippet_rules.md`, `.agent/rules/import_rules.md`, `.agent/rules/placeholder_rules.md`
* 06_Advanced/
  - Placeholders.md: 동적 플레이스홀더/마커, 커서 이동, 입력 상호작용
  - Integrations.md: Alfred 호환, Karabiner 매핑(`karabiner_mappings`) 개요
  - REST_API.md: REST API 서버 활성화, 보안(CIDR), 엔드포인트 레퍼런스, 사용 예제
    - 참조: `api/openapi_v1.yaml`, `api/openapi_v2.yaml`, `_doc_design/RestAPI.md`
  - Claude_Skill.md: Claude Code Skill 플러그인 설치 및 사용 가이드
    - 참조: `agents/claude/`
  - MCP_Server.md: MCP (Model Context Protocol) 서버 연동 가이드
    - 참조: `mcp/`
* 07_Debugging/
  - Logs.md: 로그 위치/레벨/형식, 실시간 모니터링, 트리아지 팁
    - 개발/비샌드박스 예: `/tmp/fSnippet.log`
    - 샌드박스 배포 예: `~/Library/Containers/com.nowage.fSnippet/Data/tmp/fSnippet.log`
    - 참조: `_doc_work/debug_*.md` (Tech 및 History Hub), `_doc_work/work_CAPTURE.md`
  - Troubleshooting.md: 자주 발생 이슈와 해결(권한, 입력기, 키 이벤트, Karabiner)
* 08_Reference/
  - Shortcuts.md: 전역/앱 내 단축키, 팝업 키
  - Commands.md: CLI/빌드/테스트 명령 모음(링크 포함)
    - 참조: `_doc_work/reference_COMMANDS.md`
  - REST_API_Reference.md: REST API 엔드포인트 상세, 요청/응답 형식, OpenAPI 스펙 링크
    - 참조: `_doc_design/RestAPI.md`, `api/openapi_v1.yaml`, `api/openapi_v2.yaml`
* 09_FAQ/
  - FAQ.md: 자주 묻는 질문(설치/로그/트리거/Alfred/Karabiner/한글 입력)
* 10_Release/
  - Changelog.md: 버전별 변경 요약(사용자 관점), 릴리스 노트 링크
  - UpgradeGuide.md: 버전 업그레이드 시 주의사항
* 99_Appendix/
  - Glossary.md: 용어 사전(프로젝트 용어 통일)
    - 참조: `_doc_design/info_GLOSSARY.md`
  - Templates.md: 이슈/버그리포트/재현 로그/스크린샷 가이드 템플릿

# 작성 가이드
* 파일/제목 규칙: 폴더별 주제 중심, 명사형 제목 사용(예: UsingSnippets, Logs)
* 링크 정책: 문서 간 교차 참조는 상대 경로 사용(예: `.agent/rules/snippet_rules.md`)
* 코드/명령 표기: 백틱(`)으로 감싸 명확히 표기(예: `tail -f /tmp/fSnippet.log`)
* 스크린샷/캡처: `_doc_work/work_CAPTURE.md` 방식 준수, 파일명 규칙 유지
* 버전/변경 이력: 10_Release/ 하위에 사용자 관점 요약 정리

# 빠른 시작(요약)
* 빌드(디버그): `pkill -f MacOS/fSnippet && xcodebuild -scheme fSnippet -configuration Debug build`
* 표준 5단계: 빌드 → `: > _tool/testBoard.txt` → 실행 → `open -a TextEdit _tool/testBoard.txt` → `tail -f /tmp/fSnippet.log`
* 설정 조회: `defaults read com.nowage.fSnippet`
* 문제 시: `rm -rf ~/Library/Developer/Xcode/DerivedData/fSnippet-*`

# 향후 작성 일정(To‑Do)
* [ ] 01_Overview/Introduction.md 초안
* [ ] 02_Install/Permissions.md(스크린샷 포함)
* [ ] 04_UserGuide/Settings.md(각 탭별 옵션 표)
* [ ] 05_SnippetRules/Rules.md(예제 파일명/확장 데모)
* [v] 06_Advanced/REST_API.md(서버 활성화, CIDR 보안, 엔드포인트 가이드) — FunctionalSpecification.md 섹션 4에 통합
* [v] 06_Advanced/Claude_Skill.md(Skill 플러그인 설치 및 사용) — FunctionalSpecification.md 섹션 5에 통합
* [v] 06_Advanced/MCP_Server.md(MCP 서버 연동 가이드) — FunctionalSpecification.md 섹션 6에 통합
* [ ] 07_Debugging/Logs.md(샌드박스/비샌드박스 경로 구분)
* [ ] 08_Reference/Shortcuts.md(키보드 매핑 표)
* [v] 08_Reference/REST_API_Reference.md(엔드포인트 상세, 응답 형식, OpenAPI 스펙) — FunctionalSpecification.md 섹션 4.5~4.7에 통합
* [ ] 09_FAQ/FAQ.md(Top 15 질문)

# 관련 문서(핵심 링크)
* 설계: `.agent/rules/snippet_rules.md`, `_doc_design/ARCHITECTURE.md`
* 규칙: `.agent/rules/placeholder_rules.md`, `.agent/rules/import_rules.md`
* REST API: `_doc_design/RestAPI.md`, `api/openapi_v1.yaml`, `api/openapi_v2.yaml`
* Claude Skill: `agents/claude/` (플러그인 매니페스트 + Skill 정의)
* MCP 서버: `mcp/` (MCP 프로토콜 어댑터)
* 디버깅: `_doc_work/debug_TECH.md` (Hub), `_doc_work/debug_HISTORY.md` (Hub), `_doc_work/work_CAPTURE.md`
* 명령: `_doc_work/reference_COMMANDS.md`, `_doc_work/work_BUILD_TEST.md`
* 이슈: `Issue.md`
* 캡처: `https://finfra.kr/product/fSnippet/{LANG}/` (en, kr)

---
본 README는 매뉴얼의 “맵” 역할을 합니다. 각 섹션 작성 시 본 구조를 기준으로 문서를 추가하고, 완료 후 본 리스트의 To‑Do를 체크하세요.
