---
title: fSnippetCli 스니펫 사용법
description: 스니펫 파일 · 폴더 규칙, 트리거 키, _rule.yml Prefix/Suffix, 스니펫 팝업, 플레이스홀더, Alfred 가져오기 (한국어)
date: 2026.10.09
---
# 스니펫 사용법

스니펫은 스니펫 폴더(`~/Documents/finfra/fSnippetData/snippets/`) 안의 **텍스트 파일**입니다. 파일을 추가 · 수정 · 삭제하면 폴더 감시로 바로 반영되므로, Finder · 편집기 · Git · 스크립트 어느 쪽으로 관리해도 됩니다.

## 폴더 · 파일 구조

```
snippets/
├── _rule.yml                  # 폴더별 Prefix/Suffix 규칙
├── _rule_for_import.yml       # Alfred 가져오기용 매핑 규칙
├── Docker/                    # 폴더 하나 = 스니펫 묶음(컬렉션)
│   ├── rocv2===Docker_Run.txt
│   └── dps===docker ps.txt
└── AWS/
    └── ec2===EC2.txt
```

* 스니펫은 `snippets/` 바로 아래의 **폴더 안**에 둡니다. 폴더 하나가 하나의 묶음입니다
* 확장자는 보통 `.txt` 를 씁니다. `.md` 와 `.sh` · `.py` · `.json` 같은 텍스트 확장자, 확장자 없는 파일도 인식하고 바이너리 파일은 무시합니다
* `.` 으로 시작하는 파일, 제외 목록(`_config.yml` 의 `snippet_excluded_files`, 기본 `README.md` · `_README.md` · `z_old` · `.gitignore` · `.DS_Store`)은 스니펫으로 읽지 않습니다

## 파일명 규칙

| 파일명 형식       | 의미                                                      | 예 (`Docker` 폴더)                  |
| :---------------- | :-------------------------------------------------------- | :---------------------------------- |
| `약어===이름.txt` | 기본 형식. `===` 앞이 약어, 뒤가 설명(검색 · 팝업 표시용) | `rocv2===Docker_Run.txt` → `drocv2` |
| `===이름.txt`     | 약어 없음 — 폴더 접두어만 약어가 됨                       | `===Docker.txt` → `d`               |
| `===이름_.txt`    | 약어 없음 + 끝 `_` — 접두어 첫 글자를 대문자로            | `===Docker_.txt` → `D`              |
| `약어.txt`        | `===` 없음 — 파일명 전체가 약어                           | `dps.txt` → `ddps`                  |

파일명에 쓸 수 없거나 쓰기 곤란한 문자는 토큰으로 적습니다. 약어 계산 때 실제 문자로 바뀝니다.

| 토큰                   | 문자      | 토큰                           | 문자          |
| :--------------------- | :-------- | :----------------------------- | :------------ |
| `{gt}` · `{lt}`        | `>` · `<` | `{semicolon}`                  | `;`           |
| `{pipe}`               | `\|`      | `{apostrophe}` · `{backtick}`  | `'` · `` ` `` |
| `{caret}`              | `^`       | `{exclamation}` · `{question}` | `!` · `?`     |
| `{underbar}`           | `_`       | `{tilde}`                      | `~`           |
| `{equal}` · `{equals}` | `=`       | `{lbracket}` · `{rbracket}`    | `[` · `]`     |
| `{hash}`               | `#`       | `{comma}`                      | `,`           |

## 약어가 정해지는 방식

일반 폴더(이름이 `_` 로 시작하지 않고 `_rule.yml` 규칙이 없는 폴더)의 약어는 다음과 같습니다.

**약어 = 폴더 접두어 + 파일명의 약어 + 트리거 키**

* **폴더 접두어**: 폴더명의 대문자만 모아 소문자로 바꾼 것 — `Docker` → `d`, `AWS` → `aws`, `MyFolder` → `mf`. 대문자가 없는 폴더(`demo`)는 접두어가 없습니다
* **트리거 키**: 기본 **오른쪽 ⌘** — 아래 «트리거 키» 절

| 폴더 · 파일               | 입력                 |
| :------------------------ | :------------------- |
| `Docker/rocv2===…txt`     | `drocv2` 후 오른쪽 ⌘ |
| `AWS/ec2===EC2.txt`       | `awsec2` 후 오른쪽 ⌘ |
| `MyFolder/x===Sample.txt` | `mfx` 후 오른쪽 ⌘    |

정확한 약어는 `fSnippetCli snippet search <검색어>` 나 REST `GET /api/v2/snippets/search?q=` 응답의 `abbreviation` 에서 확인합니다(ex) `drocv2{right_command}`). 폴더별 접두어 · 접미어는 `fSnippetCli folder list` 로 한눈에 봅니다.

## 트리거 키

트리거 키는 «약어 입력이 끝났다» 는 신호입니다. 약어를 치고 트리거 키를 누르면 입력한 약어가 지워지고 스니펫 내용이 들어갑니다.

| 항목                | 값 · 방법                                                                                     |
| :------------------ | :-------------------------------------------------------------------------------------------- |
| 기본값              | 오른쪽 ⌘ (`_config.yml` 의 `snippet_trigger_key: "{right_command}"`)                          |
| 현재 값 확인        | `curl -s http://localhost:3015/api/v2/triggers` · `fSnippetCli trigger`                       |
| 바꾸기              | `_config.yml` 의 `snippet_trigger_key` 수정 · REST `PUT /api/v2/settings/general/trigger-key` |
| 지우는 글자 수 보정 | `snippet_trigger_bias` (기본 `0`, -10 ~ 10) — 확장 시 지우는 글자 수가 맞지 않을 때 조정      |

* 폴더별로 다른 트리거(접미어)를 쓰려면 `_rule.yml` 을 씁니다

## 폴더 규칙 `_rule.yml`

`snippets/_rule.yml` 은 폴더별 접두어(Prefix) · 접미어(Suffix)를 정합니다. 첫 실행 때 빈 규칙 파일이 만들어집니다.

```yaml
collections:
  - name: "ANsible"        # 폴더명
    suffix: "!"            # 약어 뒤에 칠 접미어 (트리거 역할)
  - name: "_emoji"
    prefix: ",,"           # 약어 앞에 칠 접두어
    suffix: "{keypad_comma}"
    trigger_bias: 0        # (선택) 이 폴더만 지우는 글자 수 보정
    description: "이모지"  # (선택) 설명
```

| 필드           | 설명                                                                                        |
| :------------- | :------------------------------------------------------------------------------------------ |
| `name`         | 규칙을 적용할 폴더명                                                                        |
| `prefix`       | 약어 앞에 붙는 문자열                                                                       |
| `suffix`       | 약어 뒤에 붙는 문자열. 접미어를 치면 바로 확장됩니다. `" "`(공백)이면 약어 뒤 Space 로 확장 |
| `trigger_bias` | 이 폴더에만 적용할 지우는 글자 수 보정 (없으면 전역 값)                                     |
| `description`  | 설명                                                                                        |

* 규칙이 있는 폴더의 약어 = `prefix` + 자동 접두어(`_` 로 시작하지 않는 폴더만) + 약어 + `suffix`. 예: `ANsible` 폴더 + `suffix: "!"` 에서 `pb===Playbook.txt` → `anpb!`
* `prefix` 와 `suffix` 가 모두 비어 있으면 기본 트리거 키가 붙습니다
* `_` 로 시작하는 폴더(Alfred 에서 가져온 폴더 등)는 자동 접두어가 붙지 않으므로 `_rule.yml` 규칙으로 약어를 정합니다
* 파일을 고친 뒤에는 메뉴바 **👻 데몬 ▸ 스니펫 다시 불러오기** 또는 `curl -X POST http://localhost:3015/api/v2/reload` 로 반영합니다
* REST 로도 바꿀 수 있습니다: `GET` · `PATCH /api/v2/settings/snippet-folders/{folder}` (`prefix` · `suffix`)

## 스니펫 팝업

약어를 몰라도 검색해서 넣을 수 있는 창입니다. 팝업이 떠 있어도 작업 중이던 앱의 포커스를 빼앗지 않고, 팝업이 마우스 포인터를 가리지 않도록 포인터를 옆으로 옮깁니다.

| 키        | 동작                                                                              |
| :-------- | :-------------------------------------------------------------------------------- |
| ⌥⇧Space   | 팝업 열기 (기본값 · 메뉴바 **⚡ 스니펫 팝업**)                                    |
| 문자 입력 | 검색                                                                              |
| ↑ · ↓     | 항목 이동                                                                         |
| Enter     | 선택한 스니펫을 원래 앱에 넣기                                                    |
| ⌘1 ~ ⌘9   | 해당 순번 항목을 바로 넣기 (수정키는 `snippet_popup_quick_select_modifier_flags`) |
| Esc       | 닫기                                                                              |
| Tab       | 새 스니펫 작성 · 선택한 스니펫 수정 — **fSnippet(GUI 래퍼) 필요**                 |

| `_config.yml` 키              | 번들 기본값 | 설명                 |
| :---------------------------- | :---------- | :------------------- |
| `snippet_popup_hotkey`        | `{⌥⇧Space}` | 팝업 단축키          |
| `snippet_popup_rows`          | `9`         | 한 번에 보이는 행 수 |
| `snippet_popup_width`         | `500`       | 팝업 너비(pt)        |
| `snippet_popup_preview_width` | `400`       | 미리보기 너비(pt)    |
| `snippet_popup_search_scope`  | `content`   | 검색 범위            |

## 플레이스홀더

스니펫 내용에 `{{...}}` 를 쓰면 확장 시점에 값이 채워집니다.

| 예                                  | 동작                                 |
| :---------------------------------- | :----------------------------------- |
| `{{date}}` · `{{time}}`             | 오늘 날짜 · 현재 시각                |
| `{{isodate:yyyy.MM.dd}}`            | 원하는 형식의 날짜                   |
| `{{clipboard}}` · `{{clipboard:1}}` | 현재 클립보드 · 히스토리 N 번째 항목 |
| `{{cursor}}`                        | 확장 후 커서를 이 위치로             |
| `{{고객명}}` 같은 이름              | 확장 직전에 입력 창을 띄워 값을 받음 |

문법 전체: [플레이스홀더 가이드](../Placeholder.md)

## REST · 명령행으로 관리

| 작업                 | REST                                                                | 명령행                              |
| :------------------- | :------------------------------------------------------------------ | :---------------------------------- |
| 검색                 | `GET /api/v2/snippets/search?q=docker`                              | `fSnippetCli snippet search docker` |
| 목록                 | `GET /api/v2/snippets?folder=Docker`                                | `fSnippetCli snippet list`          |
| 확장 결과 보기       | `POST /api/v2/snippets/expand`                                      | `fSnippetCli snippet expand <약어>` |
| 스니펫 만들기        | `POST /api/v2/snippets`                                             | —                                   |
| 스니펫 지우기        | `DELETE /api/v2/snippets/{id}`                                      | —                                   |
| 폴더 만들기 · 지우기 | `POST /api/v2/folders` · `DELETE /api/v2/folders/{name}`(빈 폴더만) | `fSnippetCli folder list` (조회)    |
| 다시 불러오기        | `POST /api/v2/reload`                                               | —                                   |

예제와 응답 형식은 [REST API 사용법](07_API_Usage.md), 명령행은 [메뉴바 사용법 › 명령행](06_MenuBar_Usage.md#명령행-cli).

## Alfred 스니펫 가져오기

Alfred 의 스니펫 DB(`snippets.alfdb`)를 fSnippetCli 폴더로 변환합니다.

```bash
# 명령행 (경로를 생략하면 파일 선택 창이 열림)
fSnippetCli import alfred "$HOME/Library/Application Support/Alfred/Databases/snippets.alfdb"

# REST
curl -X POST http://localhost:3015/api/v2/import/alfred \
  -H "Content-Type: application/json" \
  -d '{"db_path":"~/Library/Application Support/Alfred/Databases/snippets.alfdb"}'
```

* 자동 확장(auto expand)이 켜져 있고 키워드가 있는 Alfred 스니펫만 가져옵니다
* Alfred 컬렉션 하나가 `snippets/` 아래 폴더 하나가 되고, 컬렉션 아이콘은 폴더의 `icon.png` 로 복사됩니다
* 컬렉션별 접두어 · 접미어 매핑은 `snippets/_rule_for_import.yml` 을 따릅니다
* 가져오기 전에 `snippets/` 폴더를 백업해 두기를 권장합니다
* DB 위치는 Alfred 동기화 설정에 따라 다를 수 있습니다 (검증 필요)

## GUI 로 하려면

스니펫 편집기(새 스니펫 · 수정 · 정규식으로 `{{placeholder}}` 일괄 변환)와 폴더 규칙 설정 화면은 래퍼 앱 **fSnippet** 이 제공합니다 — [fSnippet 제품 페이지](https://finfra.kr/product/fSnippet/kr/index.html).

## 다음 단계

* [클립보드 히스토리](05_Clipboard_Usage.md)
* [메뉴바 사용법](06_MenuBar_Usage.md)
* [REST API 사용법](07_API_Usage.md)
