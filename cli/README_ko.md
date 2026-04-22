---
name: fSnippetCli
description: fSnippet의 비샌드박스 헬퍼 — 키 모니터링, 텍스트 대체, REST API 엔진
date: 2026-04-07
---

# 개요

fSnippetCli는 [fSnippet](https://github.com/Finfra/fSnippet_public) App Store 앱의 **백그라운드 엔진**임. Accessibility API(CGEventTap, 키 시뮬레이션)가 필요한 핵심 기능을 비샌드박스 환경에서 실행하여 fSnippet의 App Store 배포를 가능하게 함.

```
fSnippet (Sandbox, App Store)         fSnippetCli (Non-Sandbox, Helper)
├── 설정 GUI                          ├── CGEventTap 키 모니터링
├── 스니펫 에디터           REST      ├── 텍스트 자동 대체 엔진
└── RESTClient ──────────────────►    ├── 스니펫 팝업 / 클립보드 히스토리
    (localhost:3015)                  ├── REST API 서버 (port 3015)
                                      └── 글로벌 단축키
```

# 설치

## Homebrew (권장)

```bash
brew tap finfra/tap
brew install finfra/tap/fsnippet-cli

# 로그인 시 자동 시작
brew services start fsnippet-cli
```

## Homebrew 서비스 관리

```bash
brew services start fsnippet-cli     # 시작 (로그인 시 자동 실행)
brew services stop fsnippet-cli      # 중지
brew services restart fsnippet-cli   # 재시작
brew services info fsnippet-cli      # 상태 확인
```

## 소스 빌드

```bash
git clone https://github.com/Finfra/fSnippet_public.git
cd fSnippet_public/cli
xcodebuild -scheme fSnippetCli -configuration Release build
```

# 접근성 권한 설정

fSnippetCli는 키보드 입력 모니터링과 텍스트 대체를 위해 **접근성 권한**이 필수임.

1. **시스템 설정** > 개인정보 보호 및 보안 > 접근성
2. `fSnippetCli.app` 항목에 체크

# 앱 특성

| 항목             | 값                          |
| :--------------- | :-------------------------- |
| Bundle ID        | `kr.finfra.fSnippetCli`     |
| 앱 유형          | macOS Agent (LSUIElement)   |
| Dock 표시        | 안 함                       |
| UI               | 메뉴바 아이콘만             |
| Sandbox          | 비활성화                    |
| Deployment Target | macOS 14.0                 |
| REST 포트        | 3015 (기본)                 |

# 디렉토리 구조

```
cli/
├── fSnippetCli.xcodeproj
├── Formula/
│   └── fsnippet-cli.rb        ← Homebrew Formula
├── project.yml               ← XcodeGen 스펙
└── fSnippetCli/              ← 소스 루트
    ├── fSnippetCliApp.swift   ← 진입점 (MenuBarExtra)
    ├── MenuBarView.swift      ← 메뉴바 UI
    ├── Info.plist
    ├── fSnippetCli.entitlements
    ├── Core/                  ← 키 이벤트 엔진
    │   ├── CGEventTapManager.swift
    │   ├── KeyEventMonitor.swift
    │   ├── KeyEventProcessor.swift
    │   ├── AbbreviationMatcher.swift
    │   ├── TextReplacer.swift
    │   ├── PopupController.swift
    │   └── ...
    ├── Data/                  ← 데이터/파일 관리
    │   ├── SnippetFileManager.swift
    │   ├── RuleManager.swift
    │   ├── ClipboardDB.swift
    │   └── ...
    ├── Managers/              ← 비즈니스 로직
    │   ├── ShortcutMgr.swift
    │   ├── ClipboardManager.swift
    │   ├── APIServer.swift
    │   └── ...
    ├── Services/              ← 시스템 서비스
    │   ├── BrewServiceSync.swift
    │   └── SingleInstanceGuard.swift
    ├── UI/                    ← 팝업/히스토리 윈도우
    │   ├── UnifiedSnippetPopupView.swift
    │   └── History/
    ├── Models/
    ├── Protocols/
    ├── Utils/
    └── Views/
```

# REST API

fSnippetCli는 REST API 서버를 내장하여 fSnippet GUI 및 외부 도구(MCP 서버, Agent 스킬)와 통신함.

* **OpenAPI 명세 v1**: [`api/openapi_v1.yaml`](../api/openapi_v1.yaml) — 스니펫/클립보드/통계/상태 조회
* **OpenAPI 명세 v2**: [`api/openapi_v2.yaml`](../api/openapi_v2.yaml) — Settings CRUD + PaidApp 라이프사이클

## v1 엔드포인트 (`/api/v1/`)

| Method | Path                                | 설명                        |
| :----- | :---------------------------------- | :-------------------------- |
| GET    | `/`                                 | Health check                |
| GET    | `/api/v1/snippets`                 | 스니펫 목록                 |
| GET    | `/api/v1/snippets/search?q=`       | 스니펫 검색                 |
| GET    | `/api/v1/snippets/by-abbreviation/` | abbreviation으로 조회       |
| GET    | `/api/v1/snippets/{id}`            | 스니펫 상세                 |
| POST   | `/api/v1/snippets/expand`          | abbreviation → 텍스트 확장  |
| GET    | `/api/v1/clipboard/history`        | 클립보드 히스토리           |
| GET    | `/api/v1/clipboard/history/{id}`   | 클립보드 항목 상세          |
| GET    | `/api/v1/clipboard/search?q=`     | 클립보드 검색               |
| GET    | `/api/v1/folders`                  | 폴더 목록                   |
| GET    | `/api/v1/folders/{name}`           | 폴더 상세 (스니펫 포함)     |
| GET    | `/api/v1/stats/top`               | 사용 빈도 Top N             |
| GET    | `/api/v1/stats/history`           | 사용 이력                   |
| GET    | `/api/v1/triggers`                | 트리거 키 정보              |
| GET    | `/api/v1/cli/status`              | CLI 헬퍼 상태               |
| GET    | `/api/v1/cli/version`             | CLI 헬퍼 버전               |
| POST   | `/api/v1/cli/quit`                | CLI 종료 (X-Confirm 필수)   |
| POST   | `/api/v1/import/alfred`           | Alfred 스니펫 임포트        |

## v2 엔드포인트 (`/api/v2/`)

| Method       | Path                                          | 설명                              |
| :----------- | :-------------------------------------------- | :-------------------------------- |
| GET          | `/api/v2/changes`                            | 변경 이벤트 조회 (적응형 폴링)    |
| GET/PATCH    | `/api/v2/settings/general`                   | General 설정                      |
| GET/PATCH    | `/api/v2/settings/popup`                     | 팝업 설정                         |
| GET/PATCH    | `/api/v2/settings/behavior`                  | 앱 동작 설정                      |
| GET/PUT      | `/api/v2/settings/shortcuts/{name}`          | 단축키 조회/수정                  |
| GET/PATCH    | `/api/v2/settings/snippet-folders/{folder}`  | 폴더별 prefix/suffix 규칙         |
| GET/PUT      | `/api/v2/settings/excluded-files/per-folder/{folder}` | 폴더별 제외 파일      |
| GET/PATCH    | `/api/v2/settings/history`                   | 히스토리 설정                     |
| GET/PATCH    | `/api/v2/settings/advanced/debug`            | 로그 레벨/디버그 설정             |
| GET/PATCH    | `/api/v2/settings/advanced/api`              | REST API 서버 설정                |
| GET/PUT      | `/api/v2/settings/snapshot`                  | 전체 설정 내보내기/가져오기       |
| POST         | `/api/v2/settings/actions/factory-reset`     | 공장 초기화 (Danger Zone)         |
| POST         | `/api/v2/paidapp/register`                   | paidApp 기동 등록                 |
| POST         | `/api/v2/paidapp/unregister`                 | paidApp 종료 해제                 |
| GET          | `/api/v2/paidapp/status`                     | paidApp 등록 상태                 |
| POST         | `/api/v2/shutdown`                           | cliApp 종료 (지연 지원)           |

## 빠른 테스트

```bash
# Health check
curl http://localhost:3015/

# 스니펫 검색
curl "http://localhost:3015/api/v1/snippets/search?q=docker&limit=5"

# CLI 버전
curl http://localhost:3015/api/v1/cli/version

# 설정 조회 (v2)
curl http://localhost:3015/api/v2/settings/general
```

# 메뉴바 기능

* 활성 스니펫 수 / 마지막 확장 시각 표시
* 모니터링 일시 정지/재개 토글
* 로그 폴더 열기 (`~/Documents/finfra/fSnippetData/logs/`)
* 종료 (`⌘Q`)

# 데이터 경로

fSnippet GUI와 동일한 데이터 디렉토리를 공유함:

| 항목          | 경로                                         |
| :------------ | :------------------------------------------- |
| 스니펫 파일   | `~/Documents/finfra/fSnippetData/snippets/`  |
| 클립보드 DB   | `~/Documents/finfra/fSnippetData/clipboard.sqlite` |
| 설정 파일     | `~/Documents/finfra/fSnippetData/_config.yml` |
| 로그          | `~/Documents/finfra/fSnippetData/logs/flog.log` |

# 요구 사항

* macOS 14.0+
* Xcode 15.0+ (소스 빌드 시)
* 접근성 권한 (필수)

# 라이선스

MIT
