---
name: cmdTest_plan_v2
description: fSnippetCli CLI v2 커맨드 테스트 계획 (settings 서브커맨드 기반)
date: 2026-04-13
---

# 개요

v2 cmdTest는 `fSnippetCli settings` 서브커맨드를 통해 v2 Settings API를 검증함.
`settings get/set/reset/snapshot` 서브커맨드 전체 커버리지 목표.

# 디렉토리 구조

```
cli/_tool/cmdTest/
├── cmdTestDo.sh                    ← 실행기 (v1|v2|all|단건)
├── cmdTest_plan_v1.md              ← v1 계획
├── cmdTest_plan_v2.md              ← 본 문서 (v2 계획)
├── v1/                             ← v1 스크립트
└── v2/                             ← v2 스크립트
    ├── 00.settings-general-get.sh  ← 정상 케이스
    ├── ...
    └── E01.*.sh                    ← 에러 케이스
```

# 실행 방법

```bash
# v2 전체 실행
bash cli/_tool/cmdTest/cmdTestDo.sh v2

# v2 특정 번호 실행
bash cli/_tool/cmdTest/cmdTestDo.sh v2 3   # → v2/03.*.sh

# 전체 (v1 + v2)
bash cli/_tool/cmdTest/cmdTestDo.sh all
```

# 전제 조건

* fSnippetCli 서비스가 실행 중이어야 함 (`brew services start fsnippet-cli`)
* REST API 포트 3015 응답 가능 상태
* `settings` 서브커맨드 구현 완료 (Issue31)

# 테스트 스크립트 목록

## 정상 케이스 (12개)

| 번호 | 파일명                          | 커맨드                                        | 카테고리   |
| ---: | :------------------------------ | :-------------------------------------------- | :--------- |
|   00 | `00.settings-general-get.sh`    | `fSnippetCli settings get`                    | Settings   |
|   01 | `01.settings-popup-get.sh`      | `fSnippetCli settings get popup`              | Settings   |
|   02 | `02.settings-behavior-get.sh`   | `fSnippetCli settings get behavior`           | Settings   |
|   03 | `03.settings-general-set.sh`    | `fSnippetCli settings set general.{key} {val}` | Settings  |
|   04 | `04.settings-popup-set.sh`      | `fSnippetCli settings set popup.popupRows 9`  | Settings   |
|   05 | `05.settings-behavior-set.sh`   | `fSnippetCli settings set behavior.{key} {val}` | Settings |
|   06 | `06.settings-get-json.sh`       | `fSnippetCli settings get --json`             | Settings   |
|   07 | `07.settings-get-popup-json.sh` | `fSnippetCli settings get popup --json`       | Settings   |
|   08 | `08.settings-reset-key.sh`      | `fSnippetCli settings reset popup.popupRows`  | Settings   |
|   09 | `09.settings-reset-section.sh`  | `fSnippetCli settings reset popup`            | Settings   |
|   10 | `10.settings-snapshot-export.sh`| `fSnippetCli settings snapshot export`        | Snapshot   |
|   11 | `11.settings-snapshot-import.sh`| `fSnippetCli settings snapshot import {file}` | Snapshot   |

## 에러 케이스 (3개)

| 파일명                           | 기대 코드 | 설명                                    |
| :------------------------------- | ---------: | :-------------------------------------- |
| `E01.settings-invalid-section.sh` |         2 | 존재하지 않는 section (ex: `settings get xyz`) |
| `E02.settings-set-missing-val.sh` |         2 | `settings set` 인자 누락                |
| `E03.settings-service-down.sh`    |         3 | 서비스 중지 상태에서 settings 실행      |

# 공통 변수

```bash
CLI="fSnippetCli"
# 또는 빌드된 바이너리 경로
CLI="/opt/homebrew/opt/fsnippet-cli/fSnippetCli.app/Contents/MacOS/fSnippetCli"
```

# 검증 기준

| 항목           | 검증 방법                                          |
| :------------- | :------------------------------------------------- |
| 종료 코드      | `$?` 값 확인 (0=성공, 2=인자오류, 3=서비스없음)    |
| 출력 형식      | `--json` 시 `jq .` 파싱 가능                       |
| 원복 로직      | set 테스트는 변경 후 원래 값으로 반드시 복원        |
| 에러 메시지    | stderr에 사용자 친화적 메시지 출력                  |
| snapshot 파일  | export 시 유효한 JSON 파일 생성, import 시 정상 복원 |

# cmdTest v2 ↔ apiTest v2 교차 비교

| 기능                    | cmdTest v2                     | apiTest v2                    | 비고                         |
| :---------------------- | :----------------------------- | :---------------------------- | :--------------------------- |
| Settings general GET    | 00.settings-general-get        | 00.v2-general-get             | ✅ 대응                      |
| Settings popup GET      | 01.settings-popup-get          | 01.v2-popup-get               | ✅ 대응                      |
| Settings behavior GET   | 02.settings-behavior-get       | 02.v2-behavior-get            | ✅ 대응                      |
| Settings general SET    | 03.settings-general-set        | 05.v2-general-patch           | ✅ 대응 (CLI wraps PATCH)    |
| Settings popup SET      | 04.settings-popup-set          | 10.v2-popup-patch             | ✅ 대응                      |
| Settings behavior SET   | 05.settings-behavior-set       | 11.v2-behavior-patch          | ✅ 대응                      |
| Settings JSON output    | 06.settings-get-json           | -                             | CLI 전용 (--json 플래그)     |
| Settings RESET          | 08.settings-reset-key          | -                             | CLI 전용                     |
| Snapshot export         | 10.settings-snapshot-export    | 04.v2-snapshot-get            | ✅ 대응 (format 차이)        |
| Snapshot import         | 11.settings-snapshot-import    | 60.v2-snapshot-put            | ✅ 대응                      |
| Error: invalid section  | E01.settings-invalid-section   | E00.v2-404                    | 유사 (레이어 차이)           |

# settings 커맨드 설계 참조

```
fSnippetCli settings get [section] [--json]
  section: general | popup | behavior | shortcuts (미구현)
  기본 section: general

fSnippetCli settings set <section.key> <value>
  ex) settings set popup.popupRows 9
      settings set behavior.pasteMode direct

fSnippetCli settings reset [section.key | section]
  ex) settings reset popup.popupRows
      settings reset popup

fSnippetCli settings snapshot export [--output <file>]
fSnippetCli settings snapshot import <file>
```
