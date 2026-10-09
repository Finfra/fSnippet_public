---
title: fSnippetCli 매뉴얼
description: fSnippetCli(무료 엔진) 사용자 매뉴얼 목차 · 구조 · 작성 원칙 — fSnippet(유료 GUI 앱)은 fSnippetCli 의 GUI 래퍼다
date: 2026.10.09
---
# fSnippetCli 매뉴얼

> **이 매뉴얼은 fSnippetCli 의 매뉴얼이다.**
> fSnippetCli 는 키 입력 감시·스니펫 확장·스니펫 팝업·클립보드 히스토리·REST API 를 수행하는 **엔진**이며 단독으로 동작한다.
> **fSnippet**(유료 GUI 앱)은 fSnippetCli 의 **GUI 래퍼**다 — 이 엔진 위에서 설정·관리 화면만 제공하며, fSnippetCli 없이는 동작하지 않는다. fSnippet 은 별도 프로젝트이고 매뉴얼도 따로 있다.
>
> **This is the fSnippetCli manual.** fSnippetCli is the **engine** that watches keystrokes and handles snippet expansion, the snippet popup, clipboard history and the REST API, and it runs on its own. **fSnippet** (a paid GUI app) is a **GUI wrapper** for fSnippetCli — it only adds settings and management screens on top of this engine and cannot run without it. See the **[fSnippet product page](https://finfra.kr/product/fSnippet/en/index.html)**.

# 제품 구성

| 항목      | fSnippetCli (이 매뉴얼)                             | fSnippet                                                                                                  |
| :-------- | :-------------------------------------------------- | :-------------------------------------------------------------------------------------------------------- |
| 위상      | 엔진 (단독 실행 가능)                               | **fSnippetCli 의 GUI 래퍼**                                                                               |
| 하는 일   | 키 감시·스니펫 확장·팝업·클립보드 히스토리·REST API | 설정 창·스니펫 관리 화면 (모든 값은 REST 로 fSnippetCli 에 저장)                                          |
| 배포      | Homebrew `finfra/tap/fsnippet-cli` (무료)           | Mac App Store (유료)                                                                                      |
| Bundle ID | `kr.finfra.fSnippetCli`                             | `kr.finfra.fSnippet`                                                                                      |
| 소스      | 이 저장소 [cli/](../cli/)                           | 비공개                                                                                                    |
| 매뉴얼    | 이 문서                                             | fSnippet 프로젝트 `manual/` · 공개 안내는 [제품 페이지](https://finfra.kr/product/fSnippet/kr/index.html) |

# 목차

| #   | 한국어                                        | English                                       | 내용                                                           |
| :-- | :-------------------------------------------- | :-------------------------------------------- | :------------------------------------------------------------- |
| 01  | [개요](kr/01_Overview.md)                     | [Overview](en/01_Overview.md)                 | fSnippetCli 와 fSnippet(GUI 래퍼)의 관계 · 기능 · 데이터 위치  |
| 02  | [설치](kr/02_Install.md)                      | [Installation](en/02_Install.md)              | Homebrew · 소스 빌드 · 손쉬운 사용 권한 · REST 확인            |
| 03  | [빠른 시작](kr/03_QuickStart.md)              | [Quick Start](en/03_QuickStart.md)            | 첫 스니펫 → 확장 → 팝업 → REST 4단계                           |
| 04  | [스니펫 사용법](kr/04_Snippet_Usage.md)       | [Snippet Usage](en/04_Snippet_Usage.md)       | 파일명 규칙 · 트리거 키 · `_rule.yml` · 팝업 · Alfred 가져오기 |
| 05  | [클립보드 히스토리](kr/05_Clipboard_Usage.md) | [Clipboard History](en/05_Clipboard_Usage.md) | 히스토리 창 · 키 조작 · 일시 정지 · 보존 기간                  |
| 06  | [메뉴바 사용법](kr/06_MenuBar_Usage.md)       | [Menu Bar Usage](en/06_MenuBar_Usage.md)      | 메뉴 · 전역 단축키 · `_config.yml` · 명령행                    |
| 07  | [REST API](kr/07_API_Usage.md)                | [REST API](en/07_API_Usage.md)                | v2 엔드포인트 · 응답 형식 · 보안                               |
| 08  | [Skill](kr/08_Skill_Usage.md)                 | [Skill](en/08_Skill_Usage.md)                 | Claude Code Skill                                              |
| 09  | [MCP](kr/09_MCP_Usage.md)                     | [MCP](en/09_MCP_Usage.md)                     | MCP 서버 `fsnippet-mcp`                                        |
| 10  | [FAQ](kr/10_FAQ.md)                           | [FAQ](en/10_FAQ.md)                           | 자주 묻는 질문                                                 |

공통 문서: [기능 명세](FunctionalSpecification.md) · [플레이스홀더 가이드](Placeholder.md) · [용어 사전](Glossary.md)(10개 언어) · [참조 목록](ReferenceAgenda.md)

# 디렉토리 구조

```
manual/
├── README.md                    # 본 파일 (목차·구조)
├── FunctionalSpecification.md   # 기능 명세서
├── Placeholder.md               # 플레이스홀더 문법
├── Glossary.md                  # 용어 사전
├── ReferenceAgenda.md           # 참조 목록
├── kr/                          # 한국어
│   ├── 01_Overview.md
│   ├── 02_Install.md
│   ├── 03_QuickStart.md
│   ├── 04_Snippet_Usage.md
│   ├── 05_Clipboard_Usage.md
│   ├── 06_MenuBar_Usage.md
│   ├── 07_API_Usage.md
│   ├── 08_Skill_Usage.md
│   ├── 09_MCP_Usage.md
│   └── 10_FAQ.md
└── en/                          # English (같은 구성)
```

# 빠른 시작 (요약)

| 작업          | 방법                                                                        |
| :------------ | :-------------------------------------------------------------------------- |
| 설치          | `brew install finfra/tap/fsnippet-cli` → `brew services start fsnippet-cli` |
| 권한          | 시스템 설정 › 개인정보 보호 및 보안 › 손쉬운 사용 › fSnippetCli 켜기        |
| 스니펫 만들기 | `snippets/Demo/hi===Greeting.txt` 파일 저장 (내용 = 확장될 텍스트)          |
| 확장          | 아무 앱에서 `dhi` + 오른쪽 ⌘                                                |
| 팝업          | ⌥⇧Space → 검색 → Enter                                                      |
| 클립보드      | ⌘; → 고르고 Enter                                                           |
| API 상태      | `curl -s http://localhost:3015/api/v2/status` (v1 은 `410 Gone`)            |
| API 검색      | `curl -s "http://localhost:3015/api/v2/snippets/search?q=docker"`           |
| Skill         | `/fsnippet:fsnippet docker`                                                 |
| MCP           | Claude Desktop/Code 에서 "docker 스니펫 찾아줘"                             |

| 항목        | 경로                                                   |
| :---------- | :----------------------------------------------------- |
| 스니펫 파일 | `~/Documents/finfra/fSnippetData/snippets/`            |
| 설정 파일   | `~/Documents/finfra/fSnippetData/_config.yml`          |
| 폴더 규칙   | `~/Documents/finfra/fSnippetData/snippets/_rule.yml`   |
| 로그        | `~/Documents/finfra/fSnippetData/logs/flog_cliApp.log` |

# 작성 원칙

* 이 매뉴얼은 **엔진 동작의 정본**이다. fSnippet(GUI 래퍼) 매뉴얼은 엔진 동작을 다시 쓰지 않고 이 문서를 링크한다
* fSnippet 화면에서만 하는 조작(설정 창 탭 등)은 여기에 쓰지 않고 [제품 페이지](https://finfra.kr/product/fSnippet/kr/index.html)로 링크한다. 엔진 기능을 설명하다 fSnippet 이 필요한 동작(설정 창 열기 · 팝업 Tab · 클립보드 텍스트 ⌘S)을 언급하면 «fSnippet 필요» 로 범위를 밝힌다
* 한국어(`kr/`)와 영어(`en/`)는 같은 구성 · 같은 파일명으로 함께 갱신한다. 파일명은 fSnippet 매뉴얼이 링크하므로 바꾸지 않는다
* 메뉴 항목 · 단축키 · `_config.yml` 키 · 기본값 · 엔드포인트는 소스(`cli/`)와 번들 `_config.yml` 로 확인한 값만 쓴다. 확인하지 못한 내용은 «(검증 필요)» 로 표시한다
* 링크는 이 파일 기준 상대 경로를 쓴다 (공개 저장소에서는 이 저장소가 루트, `_public/` 접두사 금지)
* REST API 의 정본은 [`api/openapi_v2.yaml`](../api/openapi_v2.yaml) 이다

# 관련 문서

* REST API: [api/README_ko.md](../api/README_ko.md) · [openapi_v2.yaml](../api/openapi_v2.yaml) (SSOT)
* Claude Code Skill: [agents/claude/README_ko.md](../agents/claude/README_ko.md) — 본체는 [Finfra/f-claude-plugins](https://github.com/Finfra/f-claude-plugins) 의 `fSnippet/`
* MCP 서버: [mcp/README_ko.md](../mcp/README_ko.md) (npm 패키지 `fsnippet-mcp`)
* 엔진 소스·아키텍처: [cli/README.md](../cli/README.md)
* 이슈: [Issue.md](../Issue.md)
* 제품 페이지: <https://finfra.kr/product/fSnippet/kr/index.html> (영문 `/en/`)
