---
title: fSnippetCli 클립보드 히스토리
description: 클립보드 히스토리 창 열기 · 키 조작 · 일시 정지 · 보존 기간 · REST 조회 (한국어)
date: 2026.10.09
---
# 클립보드 히스토리

fSnippetCli 는 복사한 내용을 기록해 두었다가 전역 단축키로 다시 붙여넣게 해 줍니다. 텍스트 · 이미지 · 파일 목록을 기록하며, 기록은 데이터 폴더의 `clipboard/clipboard.db`(이미지 원본은 `clipboard/blobs/`)에 저장됩니다.

## 창 열기

| 방법   | 동작                                                            |
| :----- | :-------------------------------------------------------------- |
| 단축키 | **⌘;** (번들 기본값 · `_config.yml` 의 `history.viewer.hotkey`) |
| 메뉴바 | **📋 클립보드 히스토리 보기**                                   |
| REST   | `GET /api/v2/clipboard/history` (창 없이 조회)                  |

창은 작업 중이던 앱 위에 뜨고, 항목을 고르면 그 앱에 붙여넣습니다.

## 키 조작

| 키                   | 동작                                                                          |
| :------------------- | :---------------------------------------------------------------------------- |
| 문자 입력            | 검색                                                                          |
| ↑ · ↓                | 항목 이동 (⇧ 를 누르고 움직이면 선택 확장)                                    |
| Enter                | 선택한 항목을 원래 앱에 붙여넣기. 여러 텍스트를 고르면 이어 붙여 넣음         |
| ⌘1 ~ ⌘9              | 해당 순번 항목을 바로 붙여넣기                                                |
| ⌘ 클릭 · ⇧ 클릭 · ⌘A | 여러 항목 선택                                                                |
| Delete · Backspace   | 선택한 항목 삭제 (검색어가 있으면 검색어 글자를 지움)                         |
| Tab                  | 텍스트 미리보기 편집 · 이미지 상세 보기                                       |
| Space                | 이미지 상세 보기                                                              |
| ⌘S                   | 이미지: 파일로 저장 · 텍스트: 새 스니펫으로 등록 — **텍스트는 fSnippet 필요** |
| Esc                  | 검색어 지우기, 검색어가 없으면 창 닫기                                        |

* 창을 연 직후의 첫 Delete 는 실수 방지를 위해 무시됩니다. 방향키나 Tab 을 한 번 누르면 바로 지울 수 있습니다

## 일시 정지 · 비우기

| 작업                  | 방법                                                                                                      |
| :-------------------- | :-------------------------------------------------------------------------------------------------------- |
| 기록 일시 정지 · 재개 | **⌃⌥⌘P** (`history.pause.hotkey`) · 메뉴바 **📜 클립보드 ▸ 일시 정지 / 재개**                             |
| 전체 비우기           | 메뉴바 **📜 클립보드 ▸ 클립보드 히스토리 비우기** · REST `POST /api/v2/settings/history/clear`            |
| 클립보드 → 스니펫     | 히스토리 창에서 항목을 고른 상태로 메뉴바 **📜 클립보드 ▸ 클립보드 → 스니펫 등록** (창의 ⌘S 와 같은 동작) |

비밀번호를 복사하기 전에 일시 정지해 두면 기록에 남지 않습니다.

## 설정 (`_config.yml`)

| 키                                | 번들 기본값 | 설명                                    |
| :-------------------------------- | :---------- | :-------------------------------------- |
| `history.viewer.hotkey`           | `{⌘;}`      | 히스토리 창 단축키                      |
| `history.pause.hotkey`            | `{^⌥⌘P}`    | 일시 정지 단축키                        |
| `history.isPaused`                | `false`     | 일시 정지 상태                          |
| `history.enable.plainText`        | `true`      | 텍스트 기록                             |
| `history.enable.images`           | `true`      | 이미지 기록                             |
| `history.enable.fileLists`        | `true`      | 파일 목록(Finder 에서 복사한 파일) 기록 |
| `history.retentionDays.plainText` | `90`        | 텍스트 보존 일수                        |
| `history.retentionDays.images`    | `7`         | 이미지 보존 일수                        |
| `history.retentionDays.fileLists` | `30`        | 파일 목록 보존 일수                     |
| `history.moveDuplicatesToTop`     | `true`      | 같은 내용을 다시 복사하면 맨 위로 올림  |
| `history.showPreview`             | `true`      | 미리보기 표시                           |
| `history.viewer.width`            | `350`       | 창 너비(pt)                             |

보존 기간이 지난 항목과 쓰이지 않는 이미지 파일은 자동으로 정리됩니다. REST 로는 `GET` · `PATCH /api/v2/settings/history` 로 읽고 바꿉니다.

## REST · 명령행으로 조회

```bash
# 최근 10개
curl -s "http://localhost:3015/api/v2/clipboard/history?limit=10"

# 종류 · 앱으로 거르기 (kind: plain_text | image | file_list)
curl -s "http://localhost:3015/api/v2/clipboard/history?kind=plain_text&app=Safari"

# 검색
curl -s "http://localhost:3015/api/v2/clipboard/search?q=docker"

# 명령행
fSnippetCli clipboard list --limit 10
fSnippetCli clipboard search docker
fSnippetCli clipboard get <id>
```

플레이스홀더 `{{clipboard:N}}` 로 히스토리 N 번째 항목을 스니펫에 넣을 수도 있습니다 — [플레이스홀더 가이드](../Placeholder.md).

## 다음 단계

* [메뉴바 사용법](06_MenuBar_Usage.md)
* [REST API 사용법](07_API_Usage.md)
