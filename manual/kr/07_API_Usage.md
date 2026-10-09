---
title: fSnippetCli REST API 사용법
description: fSnippetCli REST API v2 — 접속 · 응답 형식 · 엔드포인트 묶음별 예제 · 보안 (한국어)
date: 2026.10.09
---
# REST API 사용법

fSnippetCli 는 `http://localhost:3015/api/v2` 에 REST API 를 엽니다. curl · 셸 스크립트 · 자동화 도구 · AI 도구(Skill · MCP)가 모두 이 API 를 쓰고, GUI 래퍼 fSnippet 도 설정을 이 API 로 저장합니다.

* 정본 명세: [openapi_v2.yaml](../../api/openapi_v2.yaml) — 요청 · 응답 필드 전체는 이 파일을 봅니다
* v1(`/api/v1/*`)은 폐기되어 `410 Gone` 을 돌려줍니다. v2 만 씁니다

## 기본

| 항목      | 값                                              |
| :-------- | :---------------------------------------------- |
| 주소      | `http://localhost:3015/api/v2`                  |
| 기본 상태 | 켜짐 (`api_enabled: true`)                      |
| 접속 허용 | `127.0.0.1/32` 만 (`api_allow_external: false`) |
| 형식      | JSON (`Content-Type: application/json`)         |
| 인증      | 없음 — 주소 범위(CIDR)로만 제한                 |

응답 형식:

```json
{ "ok": true, "data": { ... }, "meta": { ... } }
{ "ok": false, "error": { "code": "not_found", "message": "..." } }
```

목록 응답의 `meta` 에는 이번 응답 개수(`count`) · 전체 개수(`total`) · 처리 시간(`durationMs`)이 들어갑니다.

## 상태 확인

```bash
curl -s http://localhost:3015/api/v2/status
# {"ok":true,"data":{"app":"fSnippetCli","status":"ok", ...}}
```

## 스니펫

| 메서드 · 경로                            | 설명                                                                        |
| :--------------------------------------- | :-------------------------------------------------------------------------- |
| `GET /snippets`                          | 목록 (`folder`, `limit` 기본 50 · 최대 200, `offset`)                       |
| `GET /snippets/search`                   | 검색 (`q` 필수, `folder`, `limit` 기본 20, `offset`)                        |
| `GET /snippets/by-abbreviation/{abbrev}` | 약어로 찾기 — 트리거 표기까지 포함한 전체 약어(URL 인코딩)                  |
| `GET /snippets/{id}`                     | 하나 조회 — `id` 는 `폴더/파일명`(URL 인코딩)                               |
| `POST /snippets`                         | 만들기 `{folder, keyword, name, content}` → `keyword===name.txt`            |
| `DELETE /snippets/{id}`                  | 지우기                                                                      |
| `POST /snippets/expand`                  | 확장 결과 텍스트만 받기 `{abbreviation, placeholder_values}` (키 입력 없음) |

```bash
# 검색
curl -s "http://localhost:3015/api/v2/snippets/search?q=docker&limit=5"

# 약어로 찾기 ({right_command} 는 %7Bright_command%7D)
curl -s "http://localhost:3015/api/v2/snippets/by-abbreviation/drocv2%7Bright_command%7D"

# 만들기 (폴더가 없으면 404, 같은 파일이 있으면 409)
curl -s -X POST http://localhost:3015/api/v2/snippets \
  -H "Content-Type: application/json" \
  -d '{"folder":"Docker","keyword":"dps","name":"docker ps","content":"docker ps -a"}'

# 확장 (플레이스홀더 값 넘기기)
curl -s -X POST http://localhost:3015/api/v2/snippets/expand \
  -H "Content-Type: application/json" \
  -d '{"abbreviation":"awsec2{right_command}","placeholder_values":{"clipboard":"i-0123"}}'
```

## 폴더

| 메서드 · 경로            | 설명                                     |
| :----------------------- | :--------------------------------------- |
| `GET /folders`           | 폴더 목록 (`?icons=true` 면 아이콘 포함) |
| `POST /folders`          | 만들기 `{name}`                          |
| `GET /folders/{name}`    | 폴더 정보와 스니펫                       |
| `DELETE /folders/{name}` | 지우기 — 빈 폴더만                       |

## 클립보드 히스토리

| 메서드 · 경로                 | 설명                                                                               |
| :---------------------------- | :--------------------------------------------------------------------------------- |
| `GET /clipboard/history`      | 목록 (`limit`, `offset`, `kind`=`plain_text`·`image`·`file_list`, `app`, `pinned`) |
| `GET /clipboard/history/{id}` | 항목 하나                                                                          |
| `GET /clipboard/search`       | 검색 (`q` 필수)                                                                    |

## 통계 · 트리거

| 메서드 · 경로        | 설명                                                          |
| :------------------- | :------------------------------------------------------------ |
| `GET /stats/top`     | 많이 쓴 스니펫                                                |
| `GET /stats/history` | 사용 기록 (`from`, `to`)                                      |
| `GET /triggers`      | 기본 트리거 키(`default`)와 쓰이고 있는 트리거 목록(`active`) |

## 엔진 관리

| 메서드 · 경로                          | 설명                                                                           |
| :------------------------------------- | :----------------------------------------------------------------------------- |
| `POST /reload`                         | 스니펫 · 규칙 다시 불러오기                                                    |
| `POST /import/alfred`                  | Alfred 가져오기 `{db_path}` (생략하면 파일 선택 창)                            |
| `GET /cli/status` · `GET /cli/version` | 엔진 상태 · 버전                                                               |
| `POST /cli/pause` · `POST /cli/resume` | REST API 일시 정지 · 재개 — 정지 중 다른 요청은 `503`, 스니펫 확장은 계속 동작 |
| `POST /cli/quit`                       | 엔진 종료 — 헤더 `X-Confirm: true` 필수                                        |

```bash
curl -s -X POST http://localhost:3015/api/v2/reload
curl -s -X POST http://localhost:3015/api/v2/cli/quit -H "X-Confirm: true"
```

## 설정 (`/settings/*`)

`_config.yml` 의 거의 모든 항목을 읽고 바꿀 수 있습니다. 바꾼 값은 바로 반영되고 파일에도 저장됩니다.

| 경로                                                                       | 내용                                                                           |
| :------------------------------------------------------------------------- | :----------------------------------------------------------------------------- |
| `/settings/general` · `language` · `appearance` · `paths` · `logging`      | 일반 설정                                                                      |
| `/settings/general/trigger-key` · `trigger-bias` · `quick-select-modifier` | 트리거 키 · 보정 · 팝업 빠른 선택 수정키                                       |
| `/settings/general/permissions`                                            | 손쉬운 사용 권한 상태 (읽기 전용)                                              |
| `/settings/popup` · `/settings/behavior`                                   | 팝업 · 앱 동작(로그인 시 실행, 메뉴바 아이콘 등)                               |
| `/settings/shortcuts` · `/settings/shortcuts/{name}`                       | 전역 단축키                                                                    |
| `/settings/snippet-folders/{folder}`                                       | 폴더별 접두어 · 접미어 (`PATCH {prefix, suffix}`)                              |
| `/settings/excluded-files/...`                                             | 제외 파일                                                                      |
| `/settings/history` · `/settings/history/clear`                            | 클립보드 히스토리 설정 · 비우기                                                |
| `/settings/advanced/api`                                                   | REST 서버 (`enabled`, `port`, `allowExternal`, `allowedCidr`)                  |
| `/settings/advanced/alfred-import`                                         | Alfred 가져오기 설정 · 실행(`/run`)                                            |
| `/settings/snapshot`                                                       | 설정 전체 내보내기(`GET`) · 들여오기(`PUT`)                                    |
| `/settings/actions/reset-settings` 등                                      | 초기화 — `reset-settings` · `reset-snippets` · `clear-stats` · `factory-reset` |

```bash
# 트리거 키 확인
curl -s http://localhost:3015/api/v2/settings/general/trigger-key

# 클립보드 텍스트 보존 기간을 30일로
curl -s -X PATCH http://localhost:3015/api/v2/settings/history \
  -H "Content-Type: application/json" -d '{"historyRetentionDaysPlainText":30}'
```

요청 본문의 필드 이름은 `_config.yml` 키와 다를 수 있습니다(ex) `api_allow_external` ↔ `allowExternal`). 정확한 이름은 [openapi_v2.yaml](../../api/openapi_v2.yaml) 의 스키마를 확인합니다.

`/paidapp/*` · `/changes` · `/key-capture/*` · `/log/paidapp` 은 fSnippet(GUI 래퍼)이 엔진과 주고받는 용도입니다.

## 보안

* 기본값은 이 Mac(`127.0.0.1`)에서만 접속됩니다. 인증이 없으므로 외부 접속은 필요할 때만 엽니다
* 외부 접속을 열려면 `PATCH /settings/advanced/api` 로 `allowExternal: true` 와 `allowedCidr`(ex) `192.168.0.0/24`)를 함께 줍니다. `allowExternal: false` 면 CIDR 은 `127.0.0.1/32` 로 고정됩니다
* 포트를 바꾸거나 서버를 끄고 켜면 서버가 다시 바인딩됩니다. 포트를 바꾼 뒤에는 명령행 `-p` · MCP `FSNIPPET_SERVER` 도 맞춰 줍니다

## 다음 단계

* [Claude Code Skill](08_Skill_Usage.md)
* [MCP 서버](09_MCP_Usage.md)
