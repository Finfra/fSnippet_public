---
title: fSnippetCli 매뉴얼 개요
description: fSnippetCli(무료 엔진) 사용자/개발자 매뉴얼 구조 — fSnippet(유료 GUI 앱)은 fSnippetCli 의 GUI 래퍼다
date: 2026.10.08
---

> **이 매뉴얼은 fSnippetCli 의 매뉴얼이다.**
> fSnippetCli 는 키 입력 감시·스니펫 확장·스니펫 팝업·클립보드 히스토리·REST API 를 수행하는 **엔진**이며 단독으로 동작한다.
> **fSnippet**(유료 GUI 앱)은 fSnippetCli 의 **GUI 래퍼**다 — 이 엔진 위에서 설정·관리 화면만 제공하며, fSnippetCli 없이는 동작하지 않는다. fSnippet 은 별도 프로젝트이고 매뉴얼도 따로 있다.

# 제품 구성

| 항목      | fSnippetCli (이 매뉴얼)                             | fSnippet                                                                                                  |
| :-------- | :-------------------------------------------------- | :-------------------------------------------------------------------------------------------------------- |
| 위상      | 엔진 (단독 실행 가능)                               | **fSnippetCli 의 GUI 래퍼**                                                                               |
| 하는 일   | 키 감시·스니펫 확장·팝업·클립보드 히스토리·REST API | 설정 창·스니펫 관리 화면 (모든 값은 REST 로 fSnippetCli 에 저장)                                          |
| 배포      | Homebrew `finfra/tap/fsnippet-cli` (무료)           | Mac App Store (유료)                                                                                      |
| Bundle ID | `kr.finfra.fSnippetCli`                             | `kr.finfra.fSnippet`                                                                                      |
| 소스      | 이 저장소 [cli/](../cli/)                           | 비공개                                                                                                    |
| 매뉴얼    | 이 문서                                             | fSnippet 프로젝트 `manual/` · 공개 안내는 [제품 페이지](https://finfra.kr/product/fSnippet/kr/index.html) |

* fSnippetCli 만 설치해도 스니펫 확장·팝업·클립보드 히스토리·REST API 는 모두 쓸 수 있다. 설정은 `_config.yml`·REST API·메뉴바로 바꾼다
* fSnippet 을 함께 쓰면 같은 설정을 GUI 창에서 바꿀 수 있다. 엔진은 그대로 fSnippetCli 다

# 문서 목록

| 문서                                                     | 내용                                                                |
| :------------------------------------------------------- | :------------------------------------------------------------------ |
| [FunctionalSpecification.md](FunctionalSpecification.md) | 기능 명세 — 스니펫 확장·클립보드·REST API·Claude Skill·MCP          |
| [Placeholder.md](Placeholder.md)                         | 동적 플레이스홀더 문법 (`{{date}}`·`{{clipboard}}`·`{{cursor}}` 등) |
| [ReferenceAgenda.md](ReferenceAgenda.md)                 | 매뉴얼 참조 목차                                                    |
| [Glossary.md](Glossary.md)                               | 용어 사전 (10개 언어)                                               |

# 빠른 시작

```bash
# 1. 설치
brew tap finfra/tap
brew install finfra/tap/fsnippet-cli

# 2. 백그라운드 서비스 시작 (로그인 시 자동 시작)
brew services start fsnippet-cli

# 3. REST API 동작 확인 (v1 은 410 Gone — v2 를 쓴다)
curl http://localhost:3015/api/v2/status
```

| 항목        | 경로                                                   |
| :---------- | :----------------------------------------------------- |
| 스니펫 파일 | `~/Documents/finfra/fSnippetData/snippets/`            |
| 설정 파일   | `~/Documents/finfra/fSnippetData/_config.yml`          |
| 폴더 규칙   | `~/Documents/finfra/fSnippetData/snippets/_rule.yml`   |
| 로그        | `~/Documents/finfra/fSnippetData/logs/flog_cliApp.log` |

* 첫 실행 시 접근성 권한을 허용해야 키 감시가 동작한다 — 설치 상세는 저장소 [README](../README_ko.md)

# 디렉토리 구조 (확장 계획)

현재는 위 «문서 목록» 의 단일 파일들로 운영한다. 분량이 늘면 아래 구조로 나눈다. **fSnippet(GUI 래퍼) 화면 사용법은 여기에 쓰지 않는다** — fSnippet 매뉴얼 몫이다.

* 01_Overview/ — 제품 개요, 트리거·스니펫·폴더 기본 개념
* 02_Install/ — Homebrew 설치, 접근성 권한, 서비스 시작·중지
* 03_QuickStart/ — 첫 스니펫 만들기 → 확장 확인
* 04_UserGuide/ — 스니펫 확장, 스니펫 팝업, 클립보드 히스토리 뷰어, 메뉴바
* 05_SnippetRules/ — 파일명 규칙(`keyword===name.txt`), 폴더 Prefix, `_rule.yml`
* 06_Advanced/ — 플레이스홀더, Alfred 가져오기, REST API, Claude Skill, MCP
* 07_Debugging/ — 로그 위치·레벨(`flog_cliApp.log`), 트러블슈팅
* 08_Reference/ — 단축키, REST 엔드포인트, `_config.yml` 키
* 09_FAQ/

# 향후 작성 일정 (To‑Do)

* [ ] 01_Overview/Introduction.md 초안
* [ ] 02_Install/Permissions.md (스크린샷 포함)
* [ ] 05_SnippetRules/Rules.md (예제 파일명·확장 데모)
* [v] 06_Advanced/REST_API.md — FunctionalSpecification.md 섹션 4에 통합
* [v] 06_Advanced/Claude_Skill.md — FunctionalSpecification.md 섹션 5에 통합
* [v] 06_Advanced/MCP_Server.md — FunctionalSpecification.md 섹션 6에 통합
* [ ] 07_Debugging/Logs.md
* [ ] 08_Reference/Shortcuts.md (키보드 매핑 표)
* [ ] 09_FAQ/FAQ.md

# 작성 원칙

* 이 매뉴얼은 **엔진 동작의 정본**이다. fSnippet(GUI 래퍼) 매뉴얼은 엔진 동작을 다시 쓰지 않고 이 문서를 링크한다
* fSnippet 화면에서만 하는 조작(설정 창 탭 등)은 여기에 쓰지 않는다. 엔진 기능을 설명하다 fSnippet 화면을 언급해야 하면 «fSnippet(GUI 래퍼) 사용 시» 로 범위를 밝힌다
* 링크는 이 파일 기준 상대 경로를 쓴다 (공개 저장소에서는 이 저장소가 루트)

# 관련 문서

* REST API: [api/README_ko.md](../api/README_ko.md) · [openapi_v2.yaml](../api/openapi_v2.yaml) (SSOT)
* Claude Code Skill: [agents/claude/README_ko.md](../agents/claude/README_ko.md)
* MCP 서버: [mcp/README_ko.md](../mcp/README_ko.md)
* 엔진 소스·아키텍처: [cli/README.md](../cli/README.md)
* 이슈: [Issue.md](../Issue.md)
* 제품 페이지: <https://finfra.kr/product/fSnippet/kr/index.html> (영문 `/en/`)
