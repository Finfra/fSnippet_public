---
title: fSnippet 사용자 매뉴얼 및 기능 명세서 (User Manual & Functional Specification)
description: 본 문서는 fSnippet의 핵심 가치 창출 도구인 **스니펫(Snippet)**과 체계적인 데이터 보관을 위한 **클립보드 히스토리(Clipboard History)** 시스템, 그리고 고급 사용자 설정 및 안정성 제어 기술에 대한 총체적이고 상세한 가이드를 제공합니다.
date: 2026-03-18
tags: [매뉴얼, 사용자 가이드, 기능 명세]
---

# fSnippet이란? (Overview)

fSnippet은 반복적인 텍스트 입력을 획기적으로 줄여주고, 과거에 복사했던 수많은 데이터(텍스트, 이미지, 파일)를 손실 없이 찾아 활용할 수 있게 해주는 macOS 전용 생산성 극대화 도구입니다. 백그라운드에서 가볍고 빠르게 동작하며, 타 스니펫 앱(예: Alfred)의 방대한 데이터베이스를 클릭 한 번으로 가져와 그대로 사용할 수 있는 강력한 호환성도 제공합니다.

---

# 1. 스니펫 (Snippet) 기능

사용자가 몇 글자의 짧은 '단축어'를 키보드로 입력하면, 애플리케이션이 이를 백그라운드에서 즉각 감지하여 미리 정의된 길고 복잡한 '전체 텍스트'로 자동 확장(대치)해 주는 fSnippet의 핵심 엔진입니다.

## 1.1. 스니펫 확장 (Text Expansion)의 원리 및 입력 안정성

### 1.1.1. 지능형 트리거 감지 및 뛰어난 입력 호환성
fSnippet은 사용자의 키보드 입력을 시스템 레벨에서 모니터링합니다. 단축어 다음에 약속된 **트리거 키(예: `Right+Cmd`(다이아몬드 키 `{right_command}`), `=`, Space 등)** 가 입력되는 순간, 화면에 문자를 뿌릴 준비를 마칩니다. 
특히 강력한 안정성을 위해 다음과 같은 특수 호환 로직이 내장되어 있습니다:
* **Karabiner-Elements 완벽 호환**: 키 맵핑 앱을 통해 특정 키를 `{right_command}` 등으로 우회 입력하더라도 이를 원본처럼 정확하게 가로채어 인식합니다.
* **다국어 및 특수 문자 완벽 방어**: 한글 입력기(`Gureum` 등) 사용 중에 영문 단축어(`j`, `k`, `l` 등)를 치거나, Shift 키가 결합된 기호(`<--`, `-->`), 대소문자가 섞인 단축키(`Cf∆`)를 입력해도 백그라운드에서 이를 정확히 보정하여 씹히지 않게 동작합니다.

### 1.1.2. 백스페이스 역방향 탐색 및 순간 대치
트리거를 감지하면 fSnippet은 즉시 **역방향 검색 알고리즘**을 통해 방금 화면에 입력된 단축어 버퍼를 스캔합니다. 특히 공백 접미사(`_symbol_space`)나 특수 스크립트 접미사(`_`)를 가진 복잡한 조건에서도 Greedy 알고리즘을 사용해 가장 긴 최적의 스니펫을 찾아냅니다. 이후 지연 길이 보정치를 계산해 백스페이스 커맨드를 전송하여 입력된 글자를 지우고, 저장된 긴 스니펫 텍스트를 눈 깜짝할 새에 붙여넣습니다.

### 1.1.3. 다양한 트리거 키와 유연한 규칙 지원
애플리케이션은 기본 다이아몬드 트리거(`Right+Cmd`) 외에도 특정 폴더별(예: Markdown, Code 등)로 사용자 정의 접두사(Prefix)/접미사(Suffix) 규칙(`_rule.yml`)을 다르게 세팅할 수 있습니다. 수천 개의 파일에서도 트리거가 꼬이는 일이 없습니다.

## 1.2. 스니펫 관리와 유용한 컴패니언 기능

### 1.2.1. 스마트 폴더 기반 파일 관리
`snippets` 폴더 내의 스니펫은 단순한 텍스트 파일(.txt)로 저장됩니다. 파일명은 직관적인 `단축어===스니펫설명.txt` 형태를 취합니다. 추가로 fSnippet은 대문자로 이루어진 폴더명(예: `EMAIL`, `AWS`)을 분석해 자동으로 해당 폴더의 모든 스니펫에 도메인별 안전한 그룹 접두어(`e`, `a`)를 매핑해 줍니다.

### 1.2.2. 에디터 내 「Search to Placeholder」 정규식 도우미
앱에 내장된 스니펫 전용 편집기에서는 길고 복잡한 템플릿의 특정 키워드를 편리하게 처리하는 기능을 제공합니다.
화면 상단의 통합 치환 도구에 정규식(Regex) 형식으로 검색어를 입력하고 치환 버튼을 누르면, 본문 내 문자열들이 한 번에 `{{placeholder}}` 포맷으로 안전하게 일괄 변환(Undo 스택 기본 지원)됩니다.

### 1.2.3. 강력한 Alfred 호환 모드 (Seamless Import)
기존에 사용하던 Alfred 스니펫 팩커지를 설정 - 고급 탭에서 버튼 한 번에 가져옵니다. 이 과정에서 중복된 접미어를 덜어내고, 불필요한 키 이벤트를 줄이는 최적화와 더불어 아이콘까지 그대로 파싱하여 이식하는 강력한 마이그레이션 경험을 제공합니다.

## 1.3. 동적 플레이스홀더 (Dynamic Placeholders)

스니펫 텍스트 내 특정 태그(`{{...}}`)를 적어두면, 타이핑 순간의 상황에 맞추어 마법 같은 자동 완성이 이뤄집니다.

* **`{{date}}`, `{{time}}` 자동 채움**: 현재의 날짜와 시간을 포맷팅해 삽입합니다.
* **포커스 텔레포트 (`{{cursor}}`)**: 코딩 중 괄호 안이나 함수 블록을 비워두기 위해 텍스트 중간에 배치하면 그 위치로 커서가 알아서 돌아갑니다.
* **즉석 동적 폼 (`{{placeholder}}`)**: 문구 중간중간에 가변 정보(고객명 등)가 필요할 때 사용하면, 텍스트가 모두 출력되기 직전에 작고 우아한 **입력 팝업창**이 떠오릅니다. 내용을 적고 엔터를 누르면 원래 타이핑하던 창(포커스 앱)으로 깔끔하게 자동으로 복귀해 남은 문장을 완성합니다!
* **시너지 복합 삽입 (`{{clipboard}}`, `{{uuid}}`)**: 최신 클립보드 값이나 고유 문자열 ID를 생성하여 꽂아 넣습니다.

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
* **키보드 액션 완벽 제어**: 검색 모드에서 리스트 삭제 단축키(Delete)가 엉뚱하게 오작동하는 것을 원천 차단했고, `Cmd+A` 전체 선택 기능과 더불어 `Esc` 키를 눌렀을 때 완전히 창이 닫히지 않고 우아하게 리스트 모드로 복귀하는 등 세밀한 유저 경험을 보장합니다.

## 2.3. スマート 3-Phase 검색과 자동 가비지 컬렉션

* **타이핑 렉 없는 3-Phase 메모리 최적화 검색 엔진**: 검색창에 단어를 넣을 때마다 수 만 개의 클립보드 데이터를 0.5초 디바운싱 -> 백그라운드 필터링 -> 메모리 부분 병합(3단계) 방식으로 읽어오므로 지연이 느껴지지 않습니다.
* **수명 관리(TTL)**: 앱 최적화를 위해 클립보드 내 텍스트는 90일 후, 파일 리스트는 30일 후, 무거운 이미지는 7일이 지나면 스스로 가비지 처리되어 하드 디스크 여유 공간을 안전하게 회수합니다.

## 2.4. 스니펫과의 놀라운 연계 (직접 붙여넣기)

* **Direct Hit**: 클립보드 히스토리 뷰어 내부에서 원하는 아이템을 키보드로 선택하고 바로 엔터(Enter)만 치면, 현재 커서가 존재하던 에디터 창이나 채팅 앱 위치에 마치 방금 `Cmd + V`를 한 것처럼 즉각 텍스트 혹은 스크린샷 덩어리가 박힙니다.
* **스니펫 매크로 연동 (`{{clipboard:N}}`)**: 클립보드 내역의 특정 인덱스(예: 지난번에 복사한 값)를 호출하는 여러 매크로를 합쳐 복잡한 코딩 템플릿(URL+이름 등) 한방 스니펫으로 승화시킬 수 있습니다.

---

# 3. 앱 구동 시스템과 퍼포먼스 제어 기술

운영체제의 키보드 후킹 권한을 직접 제어해야 하는 만큼, fSnippet은 매우 유연하면서도 보수적인 극강의 최적화 시스템을 거느리고 있습니다.

### 3.1. 백그라운드 편의성과 단축키 글로벌 호출
앱이 기본적으로 독(Dock)을 더럽히지 않도록 메뉴바 전용(LSUIElement)으로 디자인되어 조용히 돌아가지만, 원할 경우 설정에서 `앱 전환기(Cmd + Tab) 표시`를 켜서 윈도우 간격을 손쉽게 좁힐 수 있습니다. 모든 핵심 창호출이나 환경 설정은 글로벌 단축키로 제어되며, 앱 재실행을 시도(중복 클릭)하면 자동으로 환경 설정 창을 화면 앞으로 호출합니다.

### 3.2. [O(1) 증분 로딩]을 통한 앱 프리징 탈출 (Zero Freezing)
수천 개의 스니펫과 수십 개의 폴더 환경 구성을 사용할 때 빛을 발합니다. 사용자가 특정 스니펫 하나를 편집하거나, 클립보드로 만들어 바로 스니펫 폴더에 저장할 때마다 과거처럼 전체 파일 리스트를 새로 갱신하지 않고 **[파일 단 한 개만 스캔하여]** 메모리를 바꿔 끼우는 증분 업데이트 성능을 실현했습니다. 파일 추가/수정이 매우 즉각적으로 이루어집니다.

### 3.3. 배터리와 CPU를 살려내는 [지능형 동적 폴링 (Dynamic Polling)]
macOS의 한계 상 NSPasteboard(클립보드) 변화는 지속적인 폴링(감시)이 필요해 CPU를 야금야금 잡아먹는 원인이었습니다. fSnippet은 사용자가 키보드로 `Cmd + C` 따위의 액션을 취하는 바로 그 순간(밀리초 커버)에만 바짝 긴장하여 0.5초 단위로 수집합니다. 이후 사용자 행동이 없으면 조용히 감시 간격을 10초까지 조금씩 늘려서(Back-off 백그라운드 알고리즘) 배터리 소모와 발열을 원천적으로 막아냅니다.

---

# 4. REST API 서버 (External Integration)

fSnippet에 **NWListener 기반 REST API 서버**가 내장되었습니다. 외부 도구, 자동화 스크립트, 혹은 나만의 대시보드에서 fSnippet의 스니펫 데이터베이스와 클립보드 히스토리를 HTTP 요청 한 줄로 자유롭게 조회하고 활용할 수 있는 강력한 통합 인터페이스입니다.

## 4.1. 보안과 접근 제어 (Security & Access Control)

REST API 서버는 기본적으로 **비활성화** 상태로 출하됩니다. 사용자가 설정에서 명시적으로 켜야만 동작하며, 켜더라도 다음과 같은 다층 방어 체계가 가동됩니다:

* **localhost 전용 바인딩**: 기본적으로 `127.0.0.1`에서만 요청을 수락합니다. 같은 Mac 안의 스크립트/앱만 접근 가능하고, 외부 네트워크에서의 침투는 원천 차단됩니다.
* **CIDR 기반 IP 화이트리스트**: `api_allowed_cidr` 설정으로 허용할 IP 대역을 서브넷 마스크 단위(`127.0.0.1/32`, `192.168.0.0/24` 등)로 세밀하게 제어합니다.
* **외부 접속 이중 잠금**: `api_allow_external` 플래그가 `OFF`인 한, CIDR 규칙과 무관하게 외부 IP의 연결 시도 자체를 거부합니다.

## 4.2. 설정 항목 (Configuration)

| 설정 키 | 설명 | 기본값 |
|---------|------|--------|
| `api_enabled` | API 서버 활성화 여부 | `OFF` |
| `api_port` | 수신 포트 번호 | `3015` |
| `api_allow_external` | 외부(LAN/WAN) 접속 허용 여부 | `OFF` |
| `api_allowed_cidr` | 허용 IP 대역 (CIDR 표기) | `127.0.0.1/32` |

## 4.3. 엔드포인트 레퍼런스 (13개)

fSnippet REST API는 스니펫 검색/조회, 클립보드 히스토리 탐색, 폴더/통계/트리거 정보 조회까지 총 13개의 엔드포인트를 제공합니다.

| Method | Path | 설명 |
|--------|------|------|
| GET | `/` | Health Check (앱 상태, 스니펫 수, 가동 시간 등) |
| GET | `/api/snippets/search?q=&limit=&offset=&folder=` | 스니펫 검색 |
| GET | `/api/snippets/by-abbreviation/{abbrev}` | 약어(Abbreviation)로 스니펫 조회 |
| GET | `/api/snippets/{id}` | 스니펫 상세 조회 |
| POST | `/api/snippets/expand` | 스니펫 확장 (플레이스홀더 치환 포함) |
| GET | `/api/clipboard/history?limit=&offset=&kind=&app=&pinned=` | 클립보드 히스토리 목록 |
| GET | `/api/clipboard/history/{id}` | 클립보드 항목 상세 조회 |
| GET | `/api/clipboard/search?q=&limit=&offset=` | 클립보드 검색 |
| GET | `/api/folders` | 폴더 목록 조회 |
| GET | `/api/folders/{name}?limit=&offset=` | 폴더 상세 (하위 스니펫 포함) |
| GET | `/api/stats/top?limit=` | 사용 통계 Top N |
| GET | `/api/stats/history?limit=&offset=&from=&to=` | 사용 이력 조회 |
| GET | `/api/triggers` | 트리거 키 매핑 정보 조회 |

## 4.4. 사용 예제 (Quick Taste)

서버를 켠 뒤, 터미널에서 `curl` 한 줄이면 fSnippet의 심장부에 닿을 수 있습니다.

```bash
# Health Check — 앱 상태와 스니펫 총 개수 확인
$ curl -s http://localhost:3015/ | python3 -m json.tool
{
    "app": "fSnippet",
    "status": "ok",
    "port": 3015,
    "snippet_count": 1961,
    "uptime_seconds": 143
}

# 스니펫 검색 — "docker" 키워드로 1건 검색
$ curl -s "http://localhost:3015/api/snippets/search?q=docker&limit=1" | python3 -m json.tool

# 폴더 목록 — 전체 스니펫 컬렉션 구조 확인
$ curl -s http://localhost:3015/api/folders | python3 -m json.tool

# 트리거 키 — 현재 설정된 트리거 매핑 조회
$ curl -s http://localhost:3015/api/triggers | python3 -m json.tool
```

자동화 스크립트(Python, Node.js 등)에서도 동일한 HTTP 요청으로 fSnippet 데이터를 프로그래밍 방식으로 활용할 수 있으며, OpenAPI 스펙(`api/openapi.yaml`)을 참조하면 Swagger UI나 코드 제너레이터와의 연동도 가능합니다.

## 4.5. 엔드포인트 상세 레퍼런스

### GET `/` — Health Check

서버 상태와 기본 통계를 반환합니다.

**응답 예시:**
```json
{
    "status": "ok",
    "app": "fSnippet",
    "version": "2.1.0",
    "port": 3015,
    "uptime_seconds": 3600,
    "snippet_count": 1937,
    "clipboard_count": 245
}
```

### GET `/api/snippets/search` — 스니펫 검색

약어, 폴더명, 태그, 설명 등을 키워드로 검색합니다. 관련도 점수(relevance score) 기준으로 정렬됩니다.

| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|----------|------|------|--------|------|
| `q` | string | O | - | 검색 키워드 |
| `limit` | int | X | `20` | 반환할 최대 결과 수 |
| `offset` | int | X | `0` | 페이지네이션 오프셋 |
| `folder` | string | X | - | 특정 폴더로 필터링 |

**요청 예시:**
```bash
curl -s "http://localhost:3015/api/snippets/search?q=docker&limit=2" | python3 -m json.tool
```

### GET `/api/snippets/by-abbreviation/{abbrev}` — 약어로 스니펫 조회

정확한 약어(Abbreviation)를 사용하여 스니펫을 조회합니다.

```bash
curl -s "http://localhost:3015/api/snippets/by-abbreviation/dc" | python3 -m json.tool
```

### GET `/api/snippets/{id}` — 스니펫 상세 조회

스니펫 ID(폴더/파일명 형식)로 상세 정보를 조회합니다.

```bash
curl -s "http://localhost:3015/api/snippets/Docker%2Frm%3D%3D%3Ddrm.txt" | python3 -m json.tool
```

### POST `/api/snippets/expand` — 스니펫 확장

약어를 전달하면 플레이스홀더 치환을 포함한 확장된 텍스트를 반환합니다.

**요청:**
```bash
curl -s -X POST -H "Content-Type: application/json" \
    -d '{"abbreviation":"dc"}' \
    http://localhost:3015/api/snippets/expand | python3 -m json.tool
```

### GET `/api/clipboard/history` — 클립보드 히스토리

| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|----------|------|------|--------|------|
| `limit` | int | X | `50` | 반환할 최대 결과 수 |
| `offset` | int | X | `0` | 페이지네이션 오프셋 |
| `kind` | string | X | - | 항목 종류 필터 (`plain_text`, `image`, `file_list`) |
| `app` | string | X | - | 복사 출처 앱으로 필터 |
| `pinned` | bool | X | - | 고정된 항목만 필터 |

### GET `/api/clipboard/search` — 클립보드 검색

| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|----------|------|------|--------|------|
| `q` | string | O | - | 검색 키워드 |
| `limit` | int | X | `50` | 반환할 최대 결과 수 |
| `offset` | int | X | `0` | 페이지네이션 오프셋 |

### GET `/api/folders` — 폴더 목록

전체 스니펫 폴더 목록과 각 폴더의 스니펫 수를 반환합니다.

### GET `/api/folders/{name}` — 폴더 상세

특정 폴더의 스니펫 목록을 반환합니다. `limit`, `offset` 파라미터로 페이지네이션을 지원합니다.

### GET `/api/stats/top` — 사용 통계 Top N

가장 많이 사용된 스니펫의 통계를 반환합니다.

### GET `/api/stats/history` — 사용 이력

| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|----------|------|------|--------|------|
| `limit` | int | X | `100` | 반환할 최대 결과 수 |
| `offset` | int | X | `0` | 페이지네이션 오프셋 |
| `from` | string | X | - | 시작 날짜 (ISO 8601) |
| `to` | string | X | - | 종료 날짜 (ISO 8601) |

### GET `/api/triggers` — 트리거 키 매핑

현재 설정된 트리거 키 매핑 정보를 반환합니다.

## 4.6. 에러 응답 형식

모든 엔드포인트는 에러 발생 시 일관된 JSON 형식으로 응답합니다.

| HTTP 상태 코드 | 의미 | 예시 |
|----------------|------|------|
| `200` | 정상 응답 | `{"success": true, "data": {...}}` |
| `400` | 잘못된 요청 | `{"success": false, "error": {"code": "BAD_REQUEST", "message": "Invalid parameter"}}` |
| `404` | 리소스 없음 | `{"success": false, "error": {"code": "NOT_FOUND", "message": "Snippet not found"}}` |
| `500` | 서버 내부 오류 | `{"success": false, "error": {"code": "INTERNAL_ERROR", "message": "Internal error"}}` |

## 4.7. OpenAPI 스펙

fSnippet REST API의 전체 스펙은 OpenAPI 3.0.3 형식으로 제공됩니다.

* **파일 위치**: `api/openapi.yaml`
* **활용 방법**:
  - [Swagger Editor](https://editor.swagger.io/)에 붙여넣어 인터랙티브 문서로 사용
  - `openapi-generator-cli`로 각 언어별 클라이언트 코드 자동 생성
  - Postman에서 Import하여 API 컬렉션 생성

---

# 5. Claude Code Skill 연동 (AI Agent Integration)

fSnippet은 [Claude Code](https://claude.com/claude-code)의 Skill 시스템과 연동하여, AI 에이전트가 대화 중에 fSnippet의 스니펫 데이터를 직접 검색하고 활용할 수 있도록 지원합니다.

## 5.1. 개요

Claude Code Skill은 AI 에이전트에게 특정 도구를 Slash Command(`/fsnippet:...`) 형태로 제공하는 확장 모듈입니다. fSnippet REST API를 백엔드로 활용하여, 대화 흐름 안에서 스니펫 검색, 확장, 클립보드 조회 등을 수행합니다.

## 5.2. 설치 방법

### 방법 1: 수동 복사

프로젝트 루트에 플러그인 디렉토리를 복사합니다.

```bash
# fSnippet 프로젝트 루트에서 실행
cp -r agents/claude/.claude-plugin .claude-plugin
cp -r agents/claude/skills .claude/skills
```

### 방법 2: Symbolic Link

```bash
ln -sf agents/claude/skills/fsnippet .claude/skills/fsnippet
```

## 5.3. 사전 조건

fSnippet REST API 서버가 실행 중이어야 합니다.

| 항목 | 값 |
|------|-----|
| 서버 주소 | `http://localhost:3015` |
| 활성화 | 설정 > 고급 > REST API 활성화 |
| 포트 | 기본 `3015` (설정에서 변경 가능) |

## 5.4. 플러그인 구조

```
agents/claude/
├── .claude-plugin/
│   └── plugin.json          # 플러그인 매니페스트
└── skills/
    └── fsnippet/             # fSnippet Skill 정의
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

서버가 실행 중이지 않을 경우, Skill이 사용자에게 앱 실행 안내를 제공합니다.

---

# 6. MCP 서버 연동 (Model Context Protocol)

fSnippet은 [MCP (Model Context Protocol)](https://modelcontextprotocol.io/)를 통해 Claude Desktop, Claude Code 등의 AI 에이전트에서 스니펫 데이터를 직접 활용할 수 있는 MCP 서버를 제공합니다.

## 6.1. 개요

MCP 서버는 fSnippet REST API를 감싸는 경량 프로토콜 어댑터로, AI 에이전트가 표준화된 MCP 도구(Tool) 호출을 통해 스니펫 검색, 확장, 클립보드 히스토리 조회 등의 기능을 수행할 수 있습니다.

```
Claude Code / Claude Desktop
    |
    | MCP (stdio)
    v
fsnippet-mcp (MCP 서버)
    |
    | HTTP (REST API)
    v
fSnippet.app (localhost:3015)
```

## 6.2. 사전 조건

* fSnippet 앱이 실행 중이어야 합니다
* 설정에서 REST API가 활성화되어야 합니다
* 기본 서버 주소: `http://localhost:3015`

## 6.3. 설정 방법

### Claude Code 설정

`~/.claude/settings.json` 또는 프로젝트의 `.claude/settings.json`에 MCP 서버를 등록합니다.

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

### `health_check` — 서버 상태 확인

fSnippet REST API 서버의 동작 상태를 확인합니다.

**파라미터**: 없음

**응답 예시:**
```json
{
    "status": "ok",
    "app": "fSnippet",
    "port": 3015,
    "snippet_count": 1937
}
```

### `search_snippets` — 스니펫 검색

키워드로 스니펫을 검색합니다.

| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|----------|------|------|--------|------|
| `query` | string | O | - | 검색 키워드 |
| `limit` | int | X | `10` | 반환할 최대 결과 수 |
| `folder` | string | X | - | 특정 폴더로 필터링 |

### `expand_snippet` — 스니펫 확장

약어를 입력하면 플레이스홀더 치환을 포함한 확장된 텍스트를 반환합니다.

| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| `abbreviation` | string | O | 스니펫 약어 |

### `get_clipboard_history` — 클립보드 히스토리

최근 복사한 항목 목록을 반환합니다.

| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|----------|------|------|--------|------|
| `limit` | int | X | `10` | 반환할 최대 결과 수 |
| `kind` | string | X | - | 항목 종류 필터 (`plain_text`, `image`, `file_list`) |

### `list_folders` — 폴더 목록

전체 스니펫 폴더 목록과 각 폴더의 스니펫 수를 반환합니다.

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
# fSnippet REST API 서버가 실행 중인지 확인
curl -s http://localhost:3015/ | python3 -m json.tool
```

---

# 7. 설정 화면 참조 (Settings Reference)

fSnippet의 설정 화면은 5개 탭으로 구성되어 있습니다.

| 탭 | 설명 | 스크린샷 |
|----|------|----------|
| 일반 (General) | 기본 동작 설정, 트리거 키, 앱 표시 옵션 | ![일반 설정](https://finfra.kr/product/fSnippet/kr/screen_settings_general.png) |
| 스니펫 (Snippets) | 스니펫 폴더 경로, 가져오기/내보내기 | ![스니펫 설정](https://finfra.kr/product/fSnippet/kr/screen_settings_snippets.png) |
| 폴더 (Folders) | 폴더별 규칙, Prefix/Suffix, Trigger Bias | ![폴더 설정](https://finfra.kr/product/fSnippet/kr/screen_settings_folders.png) |
| 히스토리 (History) | 클립보드 히스토리 보관 기간, 수집 대상 설정 | ![히스토리 설정](https://finfra.kr/product/fSnippet/kr/screen_settings_history.png) |
| 고급 (Advanced) | REST API 서버 설정, 디버그 옵션, Alfred 가져오기 | ![고급 설정](https://finfra.kr/product/fSnippet/kr/screen_settings_advanced_info.png) |

### 주요 UI 스크린샷

| 기능 | 스크린샷 |
|------|----------|
| 스니펫 팝업 | ![스니펫 팝업](https://finfra.kr/product/fSnippet/kr/screen_snippet.png) |
| 클립보드 히스토리 | ![클립보드](https://finfra.kr/product/fSnippet/kr/screen_clipboard.png) |
