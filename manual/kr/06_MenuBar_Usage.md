---
title: fSnippetCli 메뉴바 사용법
description: 메뉴바 메뉴 · 전역 단축키 · 설정 파일 _config.yml 주요 키 · 명령행(CLI) (한국어)
date: 2026.10.09
---
# 메뉴바 사용법

fSnippetCli 는 Dock 없이 메뉴바 아이콘으로만 동작합니다. 아이콘을 누르면 아래 메뉴가 열립니다.

## 메뉴 항목

메뉴 이름은 `_config.yml` 의 `language` 를 따릅니다(번들 기본 `en` 은 영어, `ko` 는 한국어). 아래 표는 한국어 이름과 영어 이름을 함께 적었습니다.

| 메뉴                                                             | 동작                                                                                                      |
| :--------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------- |
| fSnippetCli 정보 (About fSnippetCli)                             | 버전 정보                                                                                                 |
| ⚡ 스니펫 팝업 (Snippet Popup)                                   | 스니펫 검색 팝업 열기 — [스니펫 팝업](04_Snippet_Usage.md#스니펫-팝업)                                    |
| 📋 클립보드 히스토리 보기 (Show Clipboard History)               | 클립보드 히스토리 창 열기 — [클립보드 히스토리](05_Clipboard_Usage.md)                                    |
| 📜 클립보드 ▸ 일시 정지 / 재개 (Pause / Resume)                  | 클립보드 기록 일시 정지 · 재개                                                                            |
| 📜 클립보드 ▸ 클립보드 → 스니펫 등록 (Clipboard to Snippet)      | 히스토리 창에서 고른 항목을 스니펫으로 등록 (텍스트는 fSnippet 필요)                                      |
| 📜 클립보드 ▸ 클립보드 히스토리 비우기 (Clear Clipboard History) | 기록 전체 삭제                                                                                            |
| 🔧 설정 창 열기 (Open Settings Window)                           | fSnippet 의 설정 창 열기 — **fSnippet 필요**. 없으면 App Store 안내 창                                    |
| 👻 데몬 ▸ 스니펫 다시 불러오기 (Reload Snippets)                 | 스니펫 폴더를 다시 읽음                                                                                   |
| 👻 데몬 ▸ 데몬 재시작 (Restart Daemon)                           | `brew services restart fsnippet-cli` 실행                                                                 |
| 👻 데몬 ▸ REST API 일시 정지 / 재개                              | REST 요청에 `503` 을 돌려줌(`/api/v2/cli/*` 제외). 스니펫 확장은 계속 동작                                |
| ⚙️ 환경 설정 ▸ 설정 파일 열기 (Open Config File)                  | `_config.yml` 열기                                                                                        |
| ⚙️ 환경 설정 ▸ 스니펫 폴더 열기 (Open Snippet Folder)             | `snippets/` 를 Finder 로 열기                                                                             |
| ⚙️ 환경 설정 ▸ 데이터 폴더 열기 (Open Data Folder)                | `~/Documents/finfra/fSnippetData/` 열기                                                                   |
| ⚙️ 환경 설정 ▸ 로그 폴더 열기 (Open Log Folder)                   | `logs/` 열기                                                                                              |
| 🚀 로그인 시 자동 실행 (Launch at Login)                         | 로그인 시 자동 실행 켜기 · 끄기 (Homebrew 서비스 등록과 함께 바뀜)                                        |
| 모두 종료 (Quit All)                                             | fSnippetCli 종료. fSnippet 이 실행 중이면 «fSnippet 종료(⌘Q)» 항목이 함께 보이며, «모두 종료» 는 둘 다 끔 |

* 종료하면 Homebrew 서비스도 함께 멈추고, 실행 중인 fSnippet 도 같이 종료됩니다. 다시 시작하려면 `brew services start fsnippet-cli` 를 씁니다
* 메뉴에 «⚠️ Service handoff failed — restart via brew services» 가 보이면 `brew services restart fsnippet-cli` 로 재시작합니다

## 전역 단축키

| 기능                    | 번들 기본값 | `_config.yml` 키                 |
| :---------------------- | :---------- | :------------------------------- |
| 스니펫 팝업             | ⌥⇧Space     | `snippet_popup_hotkey`           |
| 클립보드 히스토리 창    | ⌘;          | `history.viewer.hotkey`          |
| 클립보드 기록 일시 정지 | ⌃⌥⌘P        | `history.pause.hotkey`           |
| 설정 창 열기(fSnippet)  | ⌃⇧⌘;        | `settings.hotkey`                |
| 미리보기 전환           | (없음)      | `history.preview.hotkey`         |
| 스니펫으로 등록         | (없음)      | `history.registerSnippet.hotkey` |
| 스니펫 확장 트리거      | 오른쪽 ⌘    | `snippet_trigger_key`            |

* 단축키 값은 `{⌥⇧Space}` 처럼 중괄호 안에 수정키 기호(⌃ ⌥ ⇧ ⌘, `^` 도 ⌃)와 키를 적습니다
* REST 로 읽고 바꾸기: `GET /api/v2/settings/shortcuts` · `PUT` · `DELETE /api/v2/settings/shortcuts/{name}` — `name` 은 `popupHotkey` · `viewerHotkey` · `toggleCollectionPauseHotkey` · `settingsHotkey` · `togglePreviewHotkey` · `registerAsSnippetHotkey`

## 설정 파일 `_config.yml`

설정은 `~/Documents/finfra/fSnippetData/_config.yml` 한 파일에 있습니다. 첫 실행 때 앱에 들어 있는 기본 파일이 복사되며, `preferences:` 아래에 `키: 값` 이 한 줄씩 있습니다.

```yaml
preferences:
  api_enabled: true
  api_port: 3015
  snippet_trigger_key: "{right_command}"
  history.viewer.hotkey: "{⌘;}"
```

* 설정 파일은 앱이 시작할 때 읽습니다. 직접 고쳤다면 **👻 데몬 ▸ 데몬 재시작**(또는 `brew services restart fsnippet-cli`)으로 반영합니다
* 앱이 실행 중일 때 바꾸려면 REST `settings/*` 를 쓰는 편이 안전합니다 — 바로 반영되고 파일에도 저장됩니다
* 잘못 고쳐 문제가 생기면 `POST /api/v2/settings/actions/reset-settings` 로 기본값으로 되돌릴 수 있습니다

### 주요 키

| 키                                           | 번들 기본값        | 설명                                                                                  |
| :------------------------------------------- | :----------------- | :------------------------------------------------------------------------------------ |
| `snippet_base_path`                          | `./snippets`       | 스니펫 폴더 (데이터 폴더 기준)                                                        |
| `snippet_excluded_files`                     | `README.md` 등 5개 | 스니펫으로 읽지 않을 파일 · 폴더 이름                                                 |
| `snippet_trigger_key`                        | `{right_command}`  | 확장 트리거 키                                                                        |
| `snippet_trigger_bias`                       | `0`                | 확장 시 지우는 글자 수 보정 (-10 ~ 10)                                                |
| `snippet_popup_hotkey`                       | `{⌥⇧Space}`        | 스니펫 팝업 단축키                                                                    |
| `snippet_popup_quick_select_modifier_flags`  | `{command}`        | 팝업 빠른 선택(1~9) 수정키                                                            |
| `snippet_popup_rows` · `snippet_popup_width` | `9` · `500`        | 팝업 행 수 · 너비                                                                     |
| `history.*`                                  | —                  | 클립보드 히스토리 — [클립보드 히스토리 › 설정](05_Clipboard_Usage.md#설정-_configyml) |
| `api_enabled`                                | `true`             | REST API 서버 켜기                                                                    |
| `api_port`                                   | `3015`             | REST API 포트 (1024 ~ 65535)                                                          |
| `api_allow_external`                         | `false`            | `true` 면 외부(다른 기기) 접속 허용                                                   |
| `api_allowed_cidr`                           | `127.0.0.1/32`     | 외부 접속을 허용할 주소 범위                                                          |
| `language`                                   | `en`               | 메뉴 · 알림 언어 (`ko` 한국어). 다음 실행부터 적용                                    |
| `appearance`                                 | `system`           | 화면 모드                                                                             |
| `launch_at_login` · `start_at_login`         | `true`             | 로그인 시 자동 실행                                                                   |
| `hide_menu_bar_icon`                         | `false`            | 메뉴바 아이콘 숨기기                                                                  |
| `show_notifications`                         | `true`             | 알림 표시                                                                             |
| `play_ready_sound`                           | `true`             | 준비 완료 시 소리                                                                     |
| `log_level`                                  | `info`             | 로그 수준                                                                             |

* `api_allow_external: true` 로 열면 같은 네트워크의 다른 기기가 스니펫 · 클립보드 기록을 읽을 수 있습니다. 필요할 때만 켜고 `api_allowed_cidr` 로 범위를 좁히세요

## 명령행 (CLI)

fSnippetCli 실행 파일에 인자를 주면 실행 중인 엔진에 REST 로 질의하는 명령행 도구로 동작합니다(서비스가 실행 중이어야 함). 인자가 없으면 메뉴바 앱으로 실행됩니다.

```bash
alias fSnippetCli=/opt/homebrew/opt/fsnippet-cli/fSnippetCli.app/Contents/MacOS/fSnippetCli
fSnippetCli status
fSnippetCli snippet search docker --limit 5
```

| 명령                                                              | 설명                    |
| :---------------------------------------------------------------- | :---------------------- |
| `status` · `version`                                              | 서비스 상태 · 버전      |
| `snippet list` · `search <검색어>` · `get <id>` · `expand <약어>` | 스니펫 조회 · 확장 결과 |
| `clipboard list` · `get <id>` · `search <검색어>`                 | 클립보드 히스토리 조회  |
| `folder list` · `get <이름>`                                      | 폴더와 접두어 · 접미어  |
| `stats top` · `stats history`                                     | 사용 통계               |
| `settings get [키]` · `set <키> <값>`                             | 설정 읽기 · 바꾸기      |
| `settings reset --confirm`                                        | 설정 초기화             |
| `settings snapshot export [파일]` · `import <파일>`               | 설정 백업 · 복원        |
| `trigger`                                                         | 현재 트리거 키          |
| `config`                                                          | 현재 일반 설정 출력     |
| `import alfred <경로>`                                            | Alfred 스니펫 가져오기  |

| 옵션           | 설명                  |
| :------------- | :-------------------- |
| `-p`, `--port` | REST 포트 (기본 3015) |
| `--json`       | JSON 그대로 출력      |
| `--limit`      | 결과 개수 (기본 20)   |
| `--offset`     | 건너뛸 개수           |
| `-h` · `-v`    | 도움말 · 버전         |

전체 사용법은 `fSnippetCli --help` 로 봅니다.

## GUI 로 하려면

설정을 창에서 바꾸는 GUI(일반 · 팝업 · 클립보드 · 단축키 · 고급 탭)는 래퍼 앱 **fSnippet** 이 제공합니다 — [fSnippet 제품 페이지](https://finfra.kr/product/fSnippet/kr/index.html).

## 다음 단계

* [REST API 사용법](07_API_Usage.md)
* [자주 묻는 질문](10_FAQ.md)
