---
title: fSnippet 사용자 매뉴얼 참조 (Reference Agenda)
description: fSnippet 매뉴얼 참조 목차 및 구조
date: 2026-03-26
---

# 1. 스니펫 파일 및 구분자 규칙 (Snippet File System)
## 1-1. 파일명 기본 형식 (Filename Format)
## 1-2. 키워드 없는 파일 (Keyword-less Snippets)
## 1-3. 특수문자 파일명 치환 (Special Character Replacement)

# 2. Abbreviation 및 트리거 생성 (Abbreviation & Trigger)
## 2-1. 폴더별 접두사 생성 규칙 (Folder Prefix)
## 2-2. 특수 폴더 및 규칙 (_rule.yml)
## 2-3. 트리거 키 동작 원리 (Trigger Keys)

# 3. 동적 플레이스홀더 문법 (Dynamic Placeholders)
## 3-1. 클립보드 및 히스토리 (Clipboard & History)
## 3-2. 날짜 및 시간 포맷 (Date & Time)
## 3-3. 커서 위치 지정 (Cursor Positioning)
## 3-4. 입력 폼 플레이스홀더 (Input Forms)
## 3-5. 기타 고급 매크로 (Random UUID, Nesting)

# 4. 고급 기능 및 설정 (Advanced Features)
## 4-1. Alfred 워크플로우 호환성 (Alfred Compatibility)
## 4-2. 스크립트 실행 및 확장 (Script Execution)
## 4-3. 설정 파일 직접 수정 (_config.yml)

# 5. REST API (External Integration)

> **참조 문서**: [REST API 문서](../api/) | [OpenAPI 스펙](../api/openapi.yaml) | [한국어 README](../api/README_kr.md) | [테스트 스크립트](../api/test-api.sh)

## 5-1. 서버 활성화 및 보안 설정
- NWListener 기반 내장 HTTP 서버 개요
- 활성화 방법: 설정 > 고급(Advanced) > REST API 섹션에서 Enable 체크
- `api_enabled`, `api_port`, `api_allow_external`, `api_allowed_cidr` 설정 항목
- CIDR 기반 접근 제어 및 localhost 전용 바인딩 원리
## 5-2. 엔드포인트 레퍼런스
- 13개 엔드포인트 상세 (스니펫 검색/조회, 클립보드 히스토리, 폴더, 통계, 트리거)
- 요청 파라미터(query string, path variable) 설명
- 페이지네이션(`limit`, `offset`) 및 필터링(`folder`, `kind`, `app`, `pinned`, `from`, `to`)
## 5-3. 응답 형식 및 에러 처리
- JSON 응답 구조 (성공/에러 공통 형식)
- HTTP 상태 코드 (200, 400, 404, 500 등)
- Health Check(`/`) 응답 필드 설명
## 5-4. OpenAPI 스펙 참조
- `api/openapi.yaml` 파일 위치 및 활용
- Swagger UI 연동 및 코드 제너레이터 사용 가이드
- `_doc_design/RestAPI.md` 설계 문서 참조

# 6. Claude Code Skill 연동 (AI Agent Integration)

> **참조 문서**: [Claude Code Skill README](../agents/claude/README.md) | [한국어 README](../agents/claude/README_kr.md) | [플러그인 매니페스트](../agents/claude/.claude-plugin/)

## 6-1. Skill 개요
- Claude Code Slash Command 기반 fSnippet REST API 연동
- 대화 흐름 내 스니펫 검색, 확장, 클립보드 조회 지원
## 6-2. 설치 방법
- 수동 복사: `agents/claude/` 디렉토리 복사
- Symbolic Link 방식
- 플러그인 매니페스트: `.claude-plugin/plugin.json`
## 6-3. 플러그인 구조
- `.claude-plugin/plugin.json`: 플러그인 메타데이터 (name, description, version)
- `skills/fsnippet/`: Skill 정의 파일
## 6-4. 사전 조건 및 사용 예시
- fSnippet REST API 서버 실행 필수 (`http://localhost:3015`)
- 자연어 요청을 통한 스니펫 검색/확장/폴더 조회

# 7. MCP 서버 연동 (Model Context Protocol)

> **참조 문서**: [MCP 서버 README](../mcp/README.md) | [한국어 README](../mcp/README_kr.md) | [npm 패키지](../mcp/package.json)

## 7-1. MCP 개요
- fSnippet REST API를 MCP 프로토콜로 감싸는 경량 어댑터
- Claude Code, Claude Desktop 등 AI 에이전트에서 활용
- 아키텍처: AI Agent -> MCP (stdio) -> fsnippet-mcp -> HTTP -> fSnippet.app
## 7-2. 설치 및 설정
- 글로벌 설치: `npm install -g fsnippet-mcp`
- npx 방식 (설치 불필요): `npx -y fsnippet-mcp`
- 소스 직접 실행: `node mcp/index.js`
- `~/.claude/settings.json` 또는 `claude_desktop_config.json`에 등록
- 서버 주소 변경 옵션: `--server=http://localhost:<PORT>`
## 7-3. 제공 도구 (Tools)
- `health_check`: 서버 상태 확인
- `search_snippets`: 스니펫 키워드 검색 (query, limit, folder 파라미터)
- `expand_snippet`: 약어 기반 스니펫 확장 (abbreviation 파라미터)
- `get_clipboard_history`: 클립보드 히스토리 조회 (limit, kind 파라미터)
- `list_folders`: 폴더 목록 및 스니펫 수 조회
## 7-4. 디버깅
- MCP Inspector: `npx @modelcontextprotocol/inspector npx fsnippet-mcp`
- REST API 서버 연결 확인: `curl -s http://localhost:3015/`

# 8. 설정 화면 참조 (Settings Reference)
## 8-1. 설정 탭 구성
- 일반 (General): 기본 동작 설정, 트리거 키, 앱 표시 옵션
- 스니펫 (Snippets): 스니펫 폴더 경로, 가져오기/내보내기
- 폴더 (Folders): 폴더별 규칙, Prefix/Suffix, Trigger Bias
- 히스토리 (History): 클립보드 히스토리 보관 기간, 수집 대상
- 고급 (Advanced): REST API 서버 설정, 디버그 옵션, Alfred 가져오기
## 8-2. UI 스크린샷 참조
- 캡처 이미지 URL: `https://finfra.kr/product/fSnippet/{LANG}/screen_*.png`
- 지원 언어: `en/` (영어), `kr/` (한국어)
