---
title: fSnippetCli 기능 명세서 (Functional Specification)
description: fSnippetCli(엔진)의 스니펫 확장 · 클립보드 히스토리 · 구동 시스템 · REST API · Claude Code Skill · MCP 기능 명세
date: 2026.10.09
tags: [매뉴얼, 사용자 가이드, 기능 명세]
---

> **적용 범위** — 이 문서는 **fSnippetCli**(엔진)의 기능 명세다. 아래 기능은 모두 fSnippetCli 가 수행한다.
> **fSnippet**(유료 GUI 앱)은 fSnippetCli 의 **GUI 래퍼**로, 같은 기능의 설정을 창에서 바꾸는 화면과 스니펫 편집기만 제공한다. 이 문서는 엔진의 설정 방법(`_config.yml` · REST API · 메뉴바 · 명령행)만 쓴다. fSnippet 이 있어야 하는 동작은 «(fSnippet 사용 시)» 로 범위를 밝힌다. 문서 지도: [manual/README.md](README.md)

# fSnippetCli 란? (Overview)

fSnippetCli 는 반복적인 텍스트 입력을 줄여 주고, 과거에 복사했던 데이터(텍스트, 이미지, 파일)를 다시 찾아 쓸 수 있게 해 주는 macOS 스니펫 엔진입니다. 메뉴바에 상주해 백그라운드에서 가볍게 동작하며, 다른 스니펫 앱(예: Alfred)의 데이터베이스를 명령 하나(`fSnippetCli import alfred <경로>`)로 가져와 그대로 쓸 수 있습니다. 사용자 매뉴얼은 [한국어](kr/01_Overview.md) · [English](en/01_Overview.md).

---

# 1. 스니펫 (Snippet) 기능

사용자가 몇 글자의 짧은 '단축어'를 키보드로 입력하면, 애플리케이션이 이를 백그라운드에서 즉각 감지하여 미리 정의된 길고 복잡한 '전체 텍스트'로 자동 확장(대치)해 주는 fSnippetCli 의 핵심 기능입니다.

## 1.1. 스니펫 확장 (Text Expansion)의 원리 및 입력 안정성

### 1.1.1. 지능형 트리거 감지 및 뛰어난 입력 호환성
fSnippetCli 는 사용자의 키보드 입력을 시스템 레벨에서 모니터링합니다(손쉬운 사용 권한 필요). 단축어 다음에 약속된 **트리거 키(예: `Right+Cmd`(다이아몬드 키 `{right_command}`), `=`, Space 등)** 가 입력되는 순간, 화면에 문자를 뿌릴 준비를 마칩니다. 
특히 강력한 안정성을 위해 다음과 같은 특수 호환 로직이 내장되어 있습니다:
* **Karabiner-Elements 완벽 호환**: 키 맵핑 앱을 통해 특정 키를 `{right_command}` 등으로 우회 입력하더라도 이를 원본처럼 정확하게 가로채어 인식합니다.
* **다국어 및 특수 문자 완벽 방어**: 한글 입력기(`Gureum` 등) 사용 중에 영문 단축어(`j`, `k`, `l` 등)를 치거나, Shift 키가 결합된 기호(`<--`, `-->`), 대소문자가 섞인 단축키(`Cf∆`)를 입력해도 백그라운드에서 이를 정확히 보정하여 씹히지 않게 동작합니다.

### 1.1.2. 백스페이스 역방향 탐색 및 순간 대치
트리거를 감지하면 fSnippetCli 는 즉시 **역방향 검색 알고리즘**을 통해 방금 화면에 입력된 단축어 버퍼를 스캔합니다. 특히 공백 접미사(`_symbol_space`)나 특수 스크립트 접미사(`_`)를 가진 복잡한 조건에서도 Greedy 알고리즘을 사용해 가장 긴 최적의 스니펫을 찾아냅니다. 이후 지연 길이 보정치를 계산해 백스페이스 커맨드를 전송하여 입력된 글자를 지우고, 저장된 긴 스니펫 텍스트를 눈 깜짝할 새에 붙여넣습니다.

### 1.1.3. 다양한 트리거 키와 유연한 규칙 지원
기본 트리거(`Right+Cmd`, `_config.yml` 의 `snippet_trigger_key`) 외에도 폴더별(예: Markdown, Code 등)로 사용자 정의 접두사(Prefix)/접미사(Suffix) 규칙(`snippets/_rule.yml`)을 다르게 세팅할 수 있습니다. 규칙은 파일을 직접 고치거나 REST `PATCH /api/v2/settings/snippet-folders/{folder}` 로 바꿉니다 — 상세: [스니펫 사용법](kr/04_Snippet_Usage.md#폴더-규칙-_ruleyml).

## 1.2. 스니펫 관리와 유용한 컴패니언 기능

### 1.2.1. 스마트 폴더 기반 파일 관리
`snippets` 폴더 내의 스니펫은 단순한 텍스트 파일(.txt)로 저장됩니다. 파일명은 직관적인 `단축어===스니펫설명.txt` 형태를 취합니다. 추가로 fSnippetCli 는 폴더명의 대문자를 모아 소문자로 바꾼 값을 그 폴더 모든 스니펫의 그룹 접두어로 자동 매핑합니다(예: `Docker` → `d`, `AWS` → `aws`, `EMAIL` → `email`, `MyFolder` → `mf`). 대문자가 없거나 `_` 로 시작하는 폴더는 자동 접두어가 없습니다.

### 1.2.2. 스니펫 편집 (fSnippet 사용 시)
fSnippetCli 에는 스니펫 편집 화면이 없습니다. 스니펫은 텍스트 파일이므로 아무 편집기로 고치고, REST `POST /api/v2/snippets` · `DELETE /api/v2/snippets/{id}` 로 만들고 지울 수 있습니다.
fSnippet(GUI 래퍼)을 함께 쓰면 전용 편집기와 「Search to Placeholder」 정규식 도우미(본문 문자열을 `{{placeholder}}` 포맷으로 일괄 변환)를 쓸 수 있습니다 — [fSnippet 제품 페이지](https://finfra.kr/product/fSnippet/kr/index.html).

### 1.2.3. 강력한 Alfred 호환 모드 (Seamless Import)
기존에 사용하던 Alfred 스니펫 패키지(`snippets.alfdb`)를 한 번에 가져옵니다 — 명령행 `fSnippetCli import alfred <경로>` 또는 REST `POST /api/v2/import/alfred`. 컬렉션별 접두어 · 접미어 매핑은 `snippets/_rule_for_import.yml` 을 따릅니다. 이 과정에서 중복된 접미어를 덜어내고, 불필요한 키 이벤트를 줄이는 최적화와 더불어 아이콘까지 그대로 파싱하여 이식하는 강력한 마이그레이션 경험을 제공합니다.

## 1.3. 동적 플레이스홀더 (Dynamic Placeholders)

스니펫 텍스트 내 특정 태그(`{{...}}`)를 적어두면, 타이핑 순간의 상황에 맞추어 마법 같은 자동 완성이 이뤄집니다.

* **`{{date}}`, `{{time}}` 자동 채움**: 현재의 날짜와 시간을 포맷팅해 삽입합니다.
* **포커스 텔레포트 (`{{cursor}}`)**: 코딩 중 괄호 안이나 함수 블록을 비워두기 위해 텍스트 중간에 배치하면 그 위치로 커서가 알아서 돌아갑니다.
* **즉석 동적 폼 (`{{placeholder}}`)**: 문구 중간중간에 가변 정보(고객명 등)가 필요할 때 사용하면, 텍스트가 모두 출력되기 직전에 작고 우아한 **입력 팝업창**이 떠오릅니다. 내용을 적고 엔터를 누르면 원래 타이핑하던 창(포커스 앱)으로 깔끔하게 자동으로 복귀해 남은 문장을 완성합니다!
* **시너지 복합 삽입 (`{{clipboard}}`, `{{random:UUID}}`)**: 최신 클립보드 값이나 고유 문자열 ID를 생성하여 꽂아 넣습니다. 전체 문법: [플레이스홀더 가이드](Placeholder.md)

## 1.4. 언제든지 띄우는 브라우저와 UI/UX

단축어를 모두 외울 필요가 없습니다. 글로벌 단축키 한 번이면 방대한 스니펫 더미를 헤엄칠 수 있습니다.

* **안전한 스마트 팝업 탐색**: 팝업이 뜨는 순간 팝업이 마우스 포인터를 가리지 않도록 마우스를 옆으로 이동(Warping)시켜 줍니다.
* **논-블로킹 포커스**: 팝업이 떠 있는 동안에도 현재 작업 중이던 에디터 앱의 포커스를 탈취하지 않으며, 팝업 리스트 안에서 키보드의 ⬇️위/아래 방향키를 통해 자연스럽게 후보 항목을 선택하고 확장합니다. 다른 앱이나 바탕화면을 누르면 즉시 알아서 닫힙니다.

---

# 2. 클립보드 (Clipboard) 시스템

단순 텍스트를 넘어서 사용자가 복사한 소중한 작업 과정(이미지, 코드, 텍스트, 파일 경로)을 꼼꼼하게 기억하고 재사용할 수 있도록 돕는 클립보드 캐비닛입니다. 

## 2.1. 어떤 데이터든 놓치지 않는 수집 저장소

* **백그라운드 모니터링 및 미디어 보관**: macOS의 클립보드 변화 지점을 조용히 캐치하여 텍스트뿐만 아니라 수MB에 달하는 **고해상도 이미지** 및 복사한 **파일들(`File Paths`)**까지 원형 그대로 데이터베이스(`clipboard.db`)로 영구 저장합니다.
* **중복 방지와 자가 치유(Self-Healing)**: 동일한 텍스트, 해시가 같은 이미지가 연속으로 들어오면 저장하지 않고 걸러냅니다. 이미지 Blob 폴더 내 찌꺼기 파일이 있으면 앱이 띄워질 때 자동으로 쓰레기를 삭제해 시스템을 쾌적하게 유지합니다.

## 2.2. 클립보드 고도화 탐색 «통합 윈도우 (Unified Structure)»

리스트 따로, 뷰어 따로 떠다녀서 불편했던 경험을 벗어나기 위해 뷰어를 일체형으로 통합 개편했습니다.

* **리스트-프리뷰 통합 배치**: 전역 단축키 한 번으로 왼쪽에는 클립보드 목록(List), 오른쪽에는 해당 항목의 풀 사이즈 텍스트나 원본 이미지(Preview Layout)가 동시에 나타나 눈의 피로도와 깜빡임을 혁신적으로 줄였습니다. 
* **타이핑 즉시 검색 (`Typing-to-Search`)**: 리스트를 구경하다 키보드를 치기만 하면 마우스 이동이나 단축키 없이 즉시 검색창 모드로 자동 진입합니다.
* **키보드 액션 완벽 제어**: 검색 모드에서 리스트 삭제 단축키(Delete)가 엉뚱하게 오작동하는 것을 원천 차단했고, `Cmd+A` 전체 선택 기능과 더불어 검색어가 있을 때 `Esc` 를 누르면 창을 닫지 않고 검색어만 지우는(검색어가 없으면 닫힘) 등 세밀한 유저 경험을 보장합니다. 키 전체: [클립보드 히스토리](kr/05_Clipboard_Usage.md#키-조작)

## 2.3. 스마트 3-Phase 검색과 자동 가비지 컬렉션

* **타이핑 렉 없는 3-Phase 메모리 최적화 검색 엔진**: 검색창에 단어를 넣을 때마다 수 만 개의 클립보드 데이터를 0.5초 디바운싱 -> 백그라운드 필터링 -> 메모리 부분 병합(3단계) 방식으로 읽어오므로 지연이 느껴지지 않습니다.
* **수명 관리(TTL)**: 앱 최적화를 위해 클립보드 내 텍스트는 90일 후, 파일 리스트는 30일 후, 무거운 이미지는 7일이 지나면 스스로 가비지 처리되어 하드 디스크 여유 공간을 안전하게 회수합니다.

## 2.4. 스니펫과의 놀라운 연계 (직접 붙여넣기)

* **Direct Hit**: 클립보드 히스토리 뷰어 내부에서 원하는 아이템을 키보드로 선택하고 바로 엔터(Enter)만 치면, 현재 커서가 존재하던 에디터 창이나 채팅 앱 위치에 마치 방금 `Cmd + V`를 한 것처럼 즉각 텍스트 혹은 스크린샷 덩어리가 박힙니다.
* **스니펫 매크로 연동 (`{{clipboard:N}}`)**: 클립보드 내역의 특정 인덱스(예: 지난번에 복사한 값)를 호출하는 여러 매크로를 합쳐 복잡한 코딩 템플릿(URL+이름 등) 한방 스니펫으로 승화시킬 수 있습니다.

---

# 3. 앱 구동 시스템과 퍼포먼스 제어 기술

운영체제의 키보드 후킹 권한을 직접 제어해야 하는 만큼, fSnippetCli 는 매우 유연하면서도 보수적인 극강의 최적화 시스템을 거느리고 있습니다.

### 3.1. 백그라운드 편의성과 단축키 글로벌 호출
앱이 기본적으로 독(Dock)을 더럽히지 않도록 메뉴바 전용(LSUIElement)으로 디자인되어 조용히 돌아가지만, 앱 전환기(Cmd + Tab) 표시 여부는 `_config.yml` 의 `show_in_app_switcher` 로 정합니다. 스니펫 팝업 · 클립보드 히스토리 같은 핵심 창은 글로벌 단축키로 호출되며(단축키 표: [메뉴바 사용법](kr/06_MenuBar_Usage.md#전역-단축키)), 이미 실행 중일 때 앱을 다시 실행하면 새 인스턴스는 바로 종료되고 기존 인스턴스의 메뉴바 아이콘을 복원합니다.

### 3.2. [O(1) 증분 로딩]을 통한 앱 프리징 탈출 (Zero Freezing)
수천 개의 스니펫과 수십 개의 폴더 환경 구성을 사용할 때 빛을 발합니다. 사용자가 특정 스니펫 하나를 편집하거나, 클립보드로 만들어 바로 스니펫 폴더에 저장할 때마다 과거처럼 전체 파일 리스트를 새로 갱신하지 않고 **[파일 단 한 개만 스캔하여]** 메모리를 바꿔 끼우는 증분 업데이트 성능을 실현했습니다. 파일 추가/수정이 매우 즉각적으로 이루어집니다.

### 3.3. 배터리와 CPU를 살려내는 [지능형 동적 폴링 (Dynamic Polling)]
macOS의 한계 상 NSPasteboard(클립보드) 변화는 지속적인 폴링(감시)이 필요해 CPU를 야금야금 잡아먹는 원인이었습니다. fSnippetCli 는 클립보드 변화가 있으면 0.5초 간격으로 감시하고, 변화가 없으면 감시 간격을 1.5배씩 늘려 최대 2초까지 넓혀서(Back-off 알고리즘) 배터리 소모와 발열을 원천적으로 막아냅니다.

---

# 4. REST API 서버 (External Integration)

fSnippetCli 에는 **NWListener 기반 REST API 서버**(API v2)가 내장되어 있습니다. 외부 도구·자동화 스크립트·AI 에이전트가 스니펫·클립보드 히스토리·설정을 HTTP 요청으로 조회하고 바꿀 수 있습니다. fSnippet(GUI 래퍼)도 이 API 로 fSnippetCli 와 통신합니다.

> **API 버전**: 현행 API 는 **v2**(`http://localhost:3015/api/v2/...`) 하나입니다. `/api/v1/*` 는 폐기되어 모든 요청에 `410 Gone` 을 돌려줍니다. 전체 명세의 정본은 [openapi_v2.yaml](../api/openapi_v2.yaml) 입니다.

## 4.1. 보안과 접근 제어 (Security & Access Control)

REST API 서버는 기본 설정(`_config.yml`)에서 **활성화** 상태로 출하됩니다 — fSnippet(GUI 래퍼)이 이 API 로 엔진에 접근하기 때문입니다. 켜져 있어도 다음 방어 체계가 적용됩니다:

* **localhost 전용 바인딩**: 기본적으로 `127.0.0.1` 에서만 요청을 수락합니다. 같은 Mac 안의 스크립트/앱만 접근할 수 있습니다.
* **CIDR 기반 IP 화이트리스트**: 허용할 IP 대역을 CIDR 단위(`127.0.0.1/32`, `192.168.0.0/24` 등)로 제어합니다.
* **외부 접속 이중 잠금**: 외부 접속 허용이 꺼져 있는 한 CIDR 설정과 무관하게 `127.0.0.1/32` 로 강제됩니다.

## 4.2. 설정 항목 (Configuration)

같은 설정을 `_config.yml` 키 또는 REST(`GET`/`PATCH /api/v2/settings/advanced/api`) 필드로 다룹니다.

| `_config.yml` 키     | REST 필드       | 설명                                   | 기본값         |
| :------------------- | :-------------- | :------------------------------------- | :------------- |
| `api_enabled`        | `enabled`       | API 서버 활성화 여부                   | `true`         |
| `api_port`           | `port`          | 수신 포트 번호                         | `3015`         |
| `api_allow_external` | `allowExternal` | 외부(LAN/WAN) 접속 허용 여부           | `false`        |
| `api_allowed_cidr`   | `allowedCidr`   | 허용 IP 대역 (CIDR 표기)               | `127.0.0.1/32` |
| —                    | `running`       | 현재 서버 기동 여부 (조회 전용)        | —              |

* `enabled`·`port` 를 바꾸면 서버 재바인딩이 필요합니다.

## 4.3. 엔드포인트 개요

경로는 모두 `http://localhost:3015/api/v2` 기준입니다(단, Health Check `/` 는 버전 접두 없음).

**데이터 조회·조작**

| Method | Path                                                       | 설명                                           |
| :----- | :--------------------------------------------------------- | :--------------------------------------------- |
| GET    | `/` (접두 없음)                                            | Health Check (앱 상태, 스니펫 수 등)           |
| GET    | `/status`                                                  | 엔진 상태                                      |
| GET    | `/snippets/search?q=&limit=&offset=&folder=`               | 스니펫 검색                                    |
| GET    | `/snippets/by-abbreviation/{abbrev}`                       | 약어(Abbreviation)로 스니펫 조회               |
| GET    | `/snippets/{id}`                                           | 스니펫 상세 조회                               |
| POST   | `/snippets/expand`                                         | 스니펫 확장 (플레이스홀더 치환 포함)           |
| POST   | `/snippets`                                                | 스니펫 생성                                    |
| GET    | `/clipboard/history?limit=&offset=&kind=&app=&pinned=`     | 클립보드 히스토리 목록                         |
| GET    | `/clipboard/history/{id}`                                  | 클립보드 항목 상세 조회                        |
| GET    | `/clipboard/search?q=&limit=&offset=`                      | 클립보드 검색                                  |
| GET    | `/folders`                                                 | 폴더 목록 (prefix·suffix·스니펫 수 포함)       |
| GET    | `/folders/{name}?limit=&offset=`                           | 폴더 상세 (하위 스니펫 포함)                   |
| GET    | `/stats/top?limit=`                                        | 사용 통계 Top N                                |
| GET    | `/stats/history?limit=&offset=&from=&to=`                  | 사용 이력 조회                                 |
| GET    | `/triggers`                                                | 트리거 키 매핑 정보 조회                       |

**설정·제어** (상세는 [openapi_v2.yaml](../api/openapi_v2.yaml))

| 범주            | Path                                                                                   |
| :-------------- | :------------------------------------------------------------------------------------- |
| 일반 설정       | `/settings/general` · `/settings/general/{language,appearance,paths,logging,trigger-key,…}` |
| 팝업·동작·단축키 | `/settings/popup` · `/settings/behavior` · `/settings/shortcuts`                        |
| 폴더 규칙       | `/settings/snippet-folders` · `/settings/snippet-folders/{folder}`                     |
| 히스토리        | `/settings/history` · `/settings/history/clear`                                        |
| 고급            | `/settings/advanced/{info,performance,input,debug,api,alfred-import}`                  |
| 엔진 제어       | `/reload` · `/cli/pause` · `/cli/resume` · `/cli/status` · `/cli/version` · `/cli/quit` |
| 가져오기        | `/import/alfred`                                                                       |

## 4.4. 사용 예제 (Quick Taste)

```bash
# Health Check — 앱 상태와 스니펫 총 개수 확인
$ curl -s http://localhost:3015/ | python3 -m json.tool
{
    "app": "fSnippet",
    "status": "ok",
    "port": 3015,
    "snippet_count": 1861,
    "clipboard_count": 1,
    ...
}

# 스니펫 검색 — "docker" 키워드로 1건 검색
$ curl -s "http://localhost:3015/api/v2/snippets/search?q=docker&limit=1" | python3 -m json.tool

# 폴더 목록 — 전체 스니펫 컬렉션 구조 확인
$ curl -s http://localhost:3015/api/v2/folders | python3 -m json.tool

# 트리거 키 — 현재 설정된 트리거 매핑 조회
$ curl -s http://localhost:3015/api/v2/triggers | python3 -m json.tool
```

자동화 스크립트(Python, Node.js 등)에서도 같은 HTTP 요청으로 활용할 수 있으며, [openapi_v2.yaml](../api/openapi_v2.yaml) 을 Swagger UI 나 코드 제너레이터에 넣어 클라이언트를 만들 수 있습니다.

## 4.5. 엔드포인트 상세 레퍼런스

### GET `/` — Health Check

서버 상태와 기본 통계를 반환합니다. 버전 접두(`/api/v2`) 없이 호출합니다.

**응답 예시:**
```json
{
    "status": "ok",
    "app": "fSnippet",
    "version": "1.1.1",
    "port": 3015,
    "snippet_count": 1861,
    "clipboard_count": 1
}
```

### GET `/api/v2/snippets/search` — 스니펫 검색

약어, 폴더명, 태그, 설명 등을 키워드로 검색합니다. 관련도 점수(relevance score) 기준으로 정렬됩니다.

| 파라미터 | 타입   | 필수 | 기본값 | 설명                |
| :------- | :----- | :--- | :----- | :------------------ |
| `q`      | string | O    | -      | 검색 키워드         |
| `limit`  | int    | X    | `20`   | 반환할 최대 결과 수 |
| `offset` | int    | X    | `0`    | 페이지네이션 오프셋 |
| `folder` | string | X    | -      | 특정 폴더로 필터링  |

```bash
curl -s "http://localhost:3015/api/v2/snippets/search?q=docker&limit=2" | python3 -m json.tool
```

### GET `/api/v2/snippets/by-abbreviation/{abbrev}` — 약어로 스니펫 조회

정확한 약어(Abbreviation)로 스니펫을 조회합니다. 없으면 `404 NOT_FOUND` 를 돌려줍니다.

* 약어는 **트리거 키 표기까지 포함한 전체 값**이어야 합니다(ex) `drocv2{right_command}`). 트리거 표기를 뺀 `drocv2` 는 404 입니다
* 정확한 값은 검색 결과의 `abbreviation` 필드에서 얻고, URL 인코딩해 넣습니다

```bash
# 1) 검색 결과에서 abbreviation 을 얻는다
ABBR=$(curl -s "http://localhost:3015/api/v2/snippets/search?q=docker&limit=1" \
    | python3 -c 'import sys,json,urllib.parse; print(urllib.parse.quote(json.load(sys.stdin)["data"][0]["abbreviation"], safe=""))')
# 2) 약어로 조회
curl -s "http://localhost:3015/api/v2/snippets/by-abbreviation/$ABBR" | python3 -m json.tool
```

### GET `/api/v2/snippets/{id}` — 스니펫 상세 조회

스니펫 ID(`폴더/파일명` — 검색 결과의 `id` 필드)를 URL 인코딩해 상세 정보를 조회합니다.

```bash
# 검색 결과의 id(ex) "Docker/rocv2===Docker_Run.txt")를 URL 인코딩해 조회
ID=$(curl -s "http://localhost:3015/api/v2/snippets/search?q=docker&limit=1" \
    | python3 -c 'import sys,json,urllib.parse; print(urllib.parse.quote(json.load(sys.stdin)["data"][0]["id"], safe=""))')
curl -s "http://localhost:3015/api/v2/snippets/$ID" | python3 -m json.tool
```

### POST `/api/v2/snippets/expand` — 스니펫 확장

약어를 전달하면 플레이스홀더 치환을 포함한 확장 텍스트(`expanded_text`)와 지울 글자 수(`delete_count`)를 반환합니다. 약어는 위와 같이 트리거 키 표기까지 포함한 전체 값입니다.

```bash
curl -s -X POST -H "Content-Type: application/json" \
    -d '{"abbreviation":"<검색 결과의 abbreviation 값>"}' \
    http://localhost:3015/api/v2/snippets/expand | python3 -m json.tool
```

### GET `/api/v2/clipboard/history` — 클립보드 히스토리

| 파라미터 | 타입   | 필수 | 기본값 | 설명                                                |
| :------- | :----- | :--- | :----- | :-------------------------------------------------- |
| `limit`  | int    | X    | `50`   | 반환할 최대 결과 수                                 |
| `offset` | int    | X    | `0`    | 페이지네이션 오프셋                                 |
| `kind`   | string | X    | -      | 항목 종류 필터 (`plain_text`, `image`, `file_list`) |
| `app`    | string | X    | -      | 복사 출처 앱으로 필터                               |
| `pinned` | bool   | X    | -      | 고정된 항목만 필터                                  |

### GET `/api/v2/clipboard/search` — 클립보드 검색

| 파라미터 | 타입   | 필수 | 기본값 | 설명                |
| :------- | :----- | :--- | :----- | :------------------ |
| `q`      | string | O    | -      | 검색 키워드         |
| `limit`  | int    | X    | `50`   | 반환할 최대 결과 수 |
| `offset` | int    | X    | `0`    | 페이지네이션 오프셋 |

### GET `/api/v2/folders` — 폴더 목록

전체 스니펫 폴더 목록과 각 폴더의 prefix·suffix·스니펫 수를 반환합니다.

### GET `/api/v2/folders/{name}` — 폴더 상세

특정 폴더의 스니펫 목록을 반환합니다. `limit`, `offset` 파라미터로 페이지네이션을 지원합니다.

### GET `/api/v2/stats/top` — 사용 통계 Top N

가장 많이 사용된 스니펫의 통계를 반환합니다.

### GET `/api/v2/stats/history` — 사용 이력

| 파라미터 | 타입   | 필수 | 기본값 | 설명                 |
| :------- | :----- | :--- | :----- | :------------------- |
| `limit`  | int    | X    | `100`  | 반환할 최대 결과 수  |
| `offset` | int    | X    | `0`    | 페이지네이션 오프셋  |
| `from`   | string | X    | -      | 시작 날짜 (ISO 8601) |
| `to`     | string | X    | -      | 종료 날짜 (ISO 8601) |

### GET `/api/v2/triggers` — 트리거 키 매핑

현재 설정된 트리거 키 매핑 정보를 반환합니다.

## 4.6. 응답·에러 형식

목록·조회 엔드포인트는 `ok` 플래그로 감싼 JSON 을 돌려줍니다.

| HTTP 상태 코드 | 의미                     | 예시                                                                                   |
| :------------- | :----------------------- | :------------------------------------------------------------------------------------- |
| `200`          | 정상 응답                | `{"ok": true, "data": [...], "meta": {"count": 1, "total": 1, "duration_ms": 0.4}}`    |
| `400`          | 잘못된 요청              | `{"ok": false, "error": {"code": "BAD_REQUEST", "message": "..."}}`                    |
| `404`          | 리소스 없음              | `{"ok": false, "error": {"code": "NOT_FOUND", "message": "Snippet not found for abbreviation: ..."}}` |
| `410`          | 폐기된 API (`/api/v1/*`) | `/api/v2/` 로 호출해야 함                                                              |
| `500`          | 서버 내부 오류           | `{"ok": false, "error": {"code": "INTERNAL_ERROR", "message": "..."}}`                 |

## 4.7. OpenAPI 스펙

REST API 의 전체 스펙은 OpenAPI 3.0.3 형식으로 제공됩니다.

* **정본**: [api/openapi_v2.yaml](../api/openapi_v2.yaml) — 현행 v2 전체 (조회 + 설정 CRUD + 엔진 제어)
* **이력 보존**: [api/openapi_v1.yaml](../api/openapi_v1.yaml) — 폐기된 v1 (서버는 `410 Gone` 응답)
* **활용 방법**:
    - [Swagger Editor](https://editor.swagger.io/)에 붙여넣어 인터랙티브 문서로 사용
    - `openapi-generator-cli`로 각 언어별 클라이언트 코드 자동 생성
    - Postman에서 Import하여 API 컬렉션 생성

---

# 5. Claude Code Skill 연동 (AI Agent Integration)

fSnippetCli 는 [Claude Code](https://claude.com/claude-code)의 Skill 시스템과 연동하여, AI 에이전트가 대화 중에 스니펫 데이터를 직접 검색하고 활용할 수 있도록 지원합니다. 사용자용 안내: [Claude Code Skill 사용법](kr/08_Skill_Usage.md)

## 5.1. 개요

Claude Code Skill은 AI 에이전트에게 특정 도구를 Slash Command(`/fsnippet:...`) 형태로 제공하는 확장 모듈입니다. fSnippetCli REST API를 백엔드로 활용하여, 대화 흐름 안에서 스니펫 검색 · 확장 · 생성 · 삭제, 클립보드 조회, 엔진 일시 정지 · 재개 · 다시 불러오기 등을 수행합니다.

## 5.2. 설치 방법

플러그인 본체는 통합 플러그인 저장소 [Finfra/f-claude-plugins](https://github.com/Finfra/f-claude-plugins) 의 `fSnippet/` 에 있습니다(이 저장소의 [agents/claude/](../agents/claude/README_ko.md) 는 안내 포인터).

### 방법 1: 마켓플레이스 (권장)

```
/plugin marketplace add Finfra/f-claude-plugins
/plugin install fsnippet@f-claude-plugins
```

### 방법 2: 수동 복사

Skill 을 쓸 프로젝트 폴더에서 실행합니다.

```bash
git clone https://github.com/Finfra/f-claude-plugins.git
mkdir -p .claude-plugin .claude
cp f-claude-plugins/fSnippet/plugin.json .claude-plugin/plugin.json
cp -r f-claude-plugins/fSnippet/skills .claude/skills
```

## 5.3. 사전 조건

fSnippetCli 가 실행 중이고 REST API 가 켜져 있어야 합니다.

| 항목      | 값                                                                                            |
| :-------- | :-------------------------------------------------------------------------------------------- |
| 서버 주소 | `http://localhost:3015`                                                                       |
| 활성화    | 기본 켜짐 — `_config.yml` 의 `api_enabled: true` (또는 `PATCH /api/v2/settings/advanced/api`) |
| 포트      | 기본 `3015` — `_config.yml` 의 `api_port`. Skill 은 `localhost:3015` 를 기준으로 동작         |

## 5.4. 플러그인 구조

```
f-claude-plugins/fSnippet/
├── plugin.json              # 플러그인 매니페스트
├── mcp-server.js
└── skills/
    └── fsnippet/
        └── SKILL.md         # fsnippet Skill 정의
```

## 5.5. 사용 예시

Claude Code에서 다음과 같이 사용할 수 있습니다:

```
# 스니펫 검색
"docker 관련 스니펫을 찾아줘"

# 특정 약어로 스니펫 확장
"dc 약어에 해당하는 스니펫의 내용을 보여줘"

# 폴더 목록 조회
"현재 스니펫 폴더 구조를 보여줘"

# 클립보드 히스토리 확인
"최근 복사한 내용 5개를 보여줘"
```

서버가 실행 중이지 않을 경우, Skill 은 앱을 대신 실행하지 않고 실행 방법(`brew services start fsnippet-cli`)을 안내합니다.

---

# 6. MCP 서버 연동 (Model Context Protocol)

fSnippetCli 는 [MCP (Model Context Protocol)](https://modelcontextprotocol.io/)를 통해 Claude Desktop, Claude Code 등의 AI 에이전트에서 스니펫 데이터를 직접 활용할 수 있는 MCP 서버 `fsnippet-mcp`([mcp/](../mcp/))를 제공합니다. 사용자용 안내: [MCP 서버 사용법](kr/09_MCP_Usage.md)

## 6.1. 개요

MCP 서버는 fSnippetCli REST API를 감싸는 경량 프로토콜 어댑터로, AI 에이전트가 표준화된 MCP 도구(Tool) 호출을 통해 스니펫 검색, 확장, 클립보드 히스토리 조회 등의 기능을 수행할 수 있습니다.

```
Claude Code / Claude Desktop
    |
    | MCP (stdio)
    v
fsnippet-mcp (MCP 서버)
    |
    | HTTP (REST API)
    v
fSnippetCli (localhost:3015)
```

## 6.2. 사전 조건

* Node.js 18 이상
* fSnippetCli 가 실행 중이어야 합니다 (`brew services start fsnippet-cli`)
* REST API 가 켜져 있어야 합니다 — 기본 켜짐(`_config.yml` 의 `api_enabled: true`)
* 기본 서버 주소: `http://localhost:3015` (`--server=<url>` 인자 > 환경변수 `FSNIPPET_SERVER` > 기본값 순)

## 6.3. 설정 방법

### Claude Code 설정

`claude mcp add --scope user fsnippet -- npx -y fsnippet-mcp` 로 등록하거나, 프로젝트 루트의 `.mcp.json` 에 아래 형식으로 MCP 서버를 적습니다.

**글로벌 설치 후 실행:**
```bash
npm install -g fsnippet-mcp
```
```json
{
  "mcpServers": {
    "fsnippet": {
      "command": "fsnippet-mcp"
    }
  }
}
```

**npx 실행 (설치 불필요):**
```json
{
  "mcpServers": {
    "fsnippet": {
      "command": "npx",
      "args": ["-y", "fsnippet-mcp"]
    }
  }
}
```

**소스에서 직접 실행:**
```json
{
  "mcpServers": {
    "fsnippet": {
      "command": "node",
      "args": ["<PROJECT_ROOT>/mcp/index.js"]
    }
  }
}
```

### Claude Desktop 설정

`~/Library/Application Support/Claude/claude_desktop_config.json`에 추가합니다:

```json
{
  "mcpServers": {
    "fsnippet": {
      "command": "npx",
      "args": ["-y", "fsnippet-mcp"]
    }
  }
}
```

### 서버 주소 변경

기본 포트(`3015`)가 아닌 다른 포트를 사용하는 경우:

```json
{
  "mcpServers": {
    "fsnippet": {
      "command": "npx",
      "args": ["-y", "fsnippet-mcp", "--server=http://localhost:3020"]
    }
  }
}
```

## 6.4. 제공 도구 (Tools)

정본은 [mcp/index.js](../mcp/index.js) 입니다.

| 도구                | 파라미터 (기본값)                                                                | 설명                                   |
| :------------------ | :------------------------------------------------------------------------------- | :------------------------------------- |
| `health_check`      | 없음                                                                             | REST 서버 상태 확인                    |
| `search_snippets`   | `query`(필수), `limit`(20), `folder`, `offset`                                   | 키워드로 스니펫 검색                   |
| `get_snippet`       | `abbreviation` 또는 `id`                                                         | 스니펫 하나 조회                       |
| `expand_snippet`    | `abbreviation`(필수), 플레이스홀더 값                                            | 플레이스홀더 치환을 포함한 확장 텍스트 |
| `clipboard_history` | `limit`(50), `kind`(`plain_text`·`image`·`file_list`), `app`, `pinned`, `offset` | 최근 클립보드 항목                     |
| `clipboard_search`  | `query`(필수), `limit`(50), `offset`                                             | 클립보드 검색                          |
| `list_folders`      | `name`, `limit`, `offset`                                                        | 폴더 목록 · 폴더 하나 상세             |
| `get_stats`         | `type`(`top`·`history`, 기본 `top`), `limit`(10), `from`, `to`, `offset`         | 사용 통계                              |
| `get_triggers`      | 없음                                                                             | 트리거 키 정보                         |

## 6.5. 사용 예시

MCP 연동 후 Claude에게 자연어로 요청할 수 있습니다:

```
"docker 관련 스니펫을 검색해줘"
"최근 클립보드 히스토리를 보여줘"
"dc 약어의 스니펫을 확장해줘"
"스니펫 폴더 구조를 알려줘"
```

## 6.6. 디버깅

### MCP Inspector로 테스트

```bash
npx @modelcontextprotocol/inspector npx fsnippet-mcp
```

브라우저에서 Inspector UI가 열리며, 각 도구를 직접 테스트할 수 있습니다.

### 서버 연결 확인

```bash
# fSnippetCli REST API 서버가 실행 중인지 확인
curl -s http://localhost:3015/api/v2/status | python3 -m json.tool
```

---

# 7. 설정 화면 (GUI)

설정 창(일반 · 스니펫 · 폴더 · 히스토리 · 고급 탭)과 스니펫 편집기는 GUI 래퍼 **fSnippet** 의 몫입니다 — [fSnippet 제품 페이지](https://finfra.kr/product/fSnippet/kr/index.html). fSnippetCli 에서는 같은 설정을 [`_config.yml`](kr/06_MenuBar_Usage.md#설정-파일-_configyml) · [REST `settings/*`](kr/07_API_Usage.md) · 명령행 `fSnippetCli settings` 로 바꿉니다.
