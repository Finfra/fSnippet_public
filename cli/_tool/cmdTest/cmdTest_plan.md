---
name: cmdTest_plan
description: fSnippetCli CLI 커맨드 테스트 계획 (cmd_design.md 기반)
date: 2026-04-08
---

# 디렉토리 구조

```
cli/_tool/cmdTest/
├── cmdTestDo.sh                    ← 실행기 (전체 또는 단건)
├── cmdTest_plan.md                 ← 본 문서
├── 00.help.sh ~ 19.*.sh           ← 정상 케이스
└── E01.*.sh ~ E06.*.sh            ← 에러 케이스
```

# 파일명 규칙

```
{00~99}.{내역}.sh       ← 정상 케이스
E{01~99}.{내역}.sh      ← 에러 케이스
```

* 번호: 0부터 시작, 카테고리별 그룹핑
* 내역: 커맨드를 간결하게 표현 (kebab-case)

# 실행 방법

```bash
# 전체 순서대로 실행
source cli/_tool/cmdTest/cmdTestDo.sh

# 특정 번호만 실행
source cli/_tool/cmdTest/cmdTestDo.sh 0     # → 00.help.sh
source cli/_tool/cmdTest/cmdTestDo.sh 5     # → 05.snippet-search.sh
```

# cmdTestDo.sh 동작

* 인자 없음: `[0-9]*.sh`, `E*.sh` 를 번호순 정렬 후 전체 실행
* 인자 있음(숫자): `{00~99}.*.sh` 패턴 매칭하여 해당 스크립트만 실행 (0 → 00으로 자동 패딩)

# 전제 조건

* fSnippetCli 서비스가 `brew services start fsnippetcli` 로 실행 중이어야 함
* REST API 포트 3015 응답 가능 상태

# 테스트 스크립트 목록

## 정상 케이스 (20개)

| 번호 | 파일명                       | 커맨드                                   | 카테고리  |
| ---: | :--------------------------- | :--------------------------------------- | :-------- |
|   00 | `00.help.sh`                 | `fSnippetCli --help`                     | Global    |
|   01 | `01.version.sh`              | `fSnippetCli --version`                  | Global    |
|   02 | `02.version-short.sh`        | `fSnippetCli -v`                         | Global    |
|   03 | `03.status.sh`               | `fSnippetCli status`                     | Service   |
|   04 | `04.snippet-list.sh`         | `fSnippetCli snippet list`               | Snippet   |
|   05 | `05.snippet-search.sh`       | `fSnippetCli snippet search docker`      | Snippet   |
|   06 | `06.snippet-get.sh`          | `fSnippetCli snippet get 1`              | Snippet   |
|   07 | `07.snippet-expand.sh`       | `fSnippetCli snippet expand bb`          | Snippet   |
|   08 | `08.snippet-list-limit.sh`   | `fSnippetCli snippet list --limit 3`     | Snippet   |
|   09 | `09.snippet-list-json.sh`    | `fSnippetCli snippet list --json`        | Snippet   |
|   10 | `10.clipboard-list.sh`       | `fSnippetCli clipboard list`             | Clipboard |
|   11 | `11.clipboard-get.sh`        | `fSnippetCli clipboard get 1`            | Clipboard |
|   12 | `12.clipboard-search.sh`     | `fSnippetCli clipboard search test`      | Clipboard |
|   13 | `13.folder-list.sh`          | `fSnippetCli folder list`                | Folder    |
|   14 | `14.folder-get.sh`           | `fSnippetCli folder get Docker`          | Folder    |
|   15 | `15.stats-top.sh`            | `fSnippetCli stats top`                  | Stats     |
|   16 | `16.stats-history.sh`        | `fSnippetCli stats history`              | Stats     |
|   17 | `17.trigger.sh`              | `fSnippetCli trigger`                    | Trigger   |
|   18 | `18.config.sh`               | `fSnippetCli config`                     | Config    |
|   19 | `19.config-json.sh`          | `fSnippetCli config --json`              | Config    |

## 에러 케이스 (6개)

| 파일명                            | 기대 코드 | 설명                               |
| :-------------------------------- | ---------: | :--------------------------------- |
| `E01.unknown-command.sh`          |          2 | 존재하지 않는 커맨드               |
| `E02.missing-subcommand.sh`       |          2 | `fSnippetCli snippet` (서브커맨드 누락) |
| `E03.missing-argument.sh`         |          2 | `fSnippetCli snippet search` (인자 누락) |
| `E04.invalid-option.sh`           |          2 | `fSnippetCli --unknown`            |
| `E05.service-not-running.sh`      |          3 | 서비스 중지 후 커맨드 실행         |
| `E06.snippet-get-404.sh`          |          1 | 존재하지 않는 스니펫 ID            |

# 공통 변수

```bash
CLI="fSnippetCli"
# 또는 빌드된 바이너리 경로
CLI="/opt/homebrew/opt/fsnippetcli/fSnippetCli.app/Contents/MacOS/fSnippetCli"
```

# 검증 기준

| 항목           | 검증 방법                                     |
| :------------- | :-------------------------------------------- |
| 종료 코드      | `$?` 값 확인 (0=성공, 2=인자오류, 3=서비스없음) |
| 출력 형식      | `--json` 시 `jq .` 파싱 가능                  |
| 도움말         | `--help` 시 Usage 메시지 포함                  |
| 버전           | `--version` 시 버전 번호 포함                  |
| 결과 개수      | `--limit N` 시 N개 이하 출력                   |
| 에러 메시지    | stderr에 사용자 친화적 메시지 출력             |

# cmd_design.md ↔ 테스트 매핑

| 설계 커맨드             | 테스트 번호 | Phase |
| :---------------------- | :---------- | :---- |
| `--help`                | 00          | 1     |
| `--version`             | 01, 02      | 1     |
| `status`                | 03          | 1     |
| `snippet list`          | 04, 08, 09  | 1     |
| `snippet search`        | 05          | 1     |
| `snippet get`           | 06          | 2     |
| `snippet expand`        | 07          | 2     |
| `clipboard list`        | 10          | 2     |
| `clipboard get`         | 11          | 2     |
| `clipboard search`      | 12          | 2     |
| `folder list`           | 13          | 2     |
| `folder get`            | 14          | 2     |
| `stats top`             | 15          | 3     |
| `stats history`         | 16          | 3     |
| `trigger`               | 17          | 3     |
| `config`                | 18, 19      | 3     |

# cmdTest ↔ apiTest 교차 비교

| 기능             | cmdTest                  | apiTest                  | 비고                          |
| :--------------- | :----------------------- | :----------------------- | :---------------------------- |
| Help             | 00.help                  | -                        | CLI 전용                      |
| Version          | 01.version, 02.version-short | 16.cli-version        | ✅ 대응                       |
| Status           | 03.status                | 15.cli-status            | ✅ 대응                       |
| Snippet list     | 04.snippet-list          | 02.snippets-list         | ✅ 대응                       |
| Snippet search   | 05.snippet-search        | 03.snippets-search       | ✅ 대응                       |
| Snippet get      | 06.snippet-get           | 05.snippets-detail       | ✅ 대응                       |
| Snippet expand   | 07.snippet-expand        | 06.snippets-expand       | ✅ 대응                       |
| Snippet limit    | 08.snippet-list-limit    | -                        | API에서는 02에서 limit 사용   |
| Snippet JSON     | 09.snippet-list-json     | -                        | API는 항상 JSON               |
| Clipboard list   | 10.clipboard-list        | 07.clipboard-history     | ✅ 대응                       |
| Clipboard get    | 11.clipboard-get         | 08.clipboard-detail      | ✅ 대응                       |
| Clipboard search | 12.clipboard-search      | 09.clipboard-search      | ✅ 대응                       |
| Folder list      | 13.folder-list           | 10.folders-list          | ✅ 대응                       |
| Folder get       | 14.folder-get            | 11.folders-detail        | ✅ 대응                       |
| Stats top        | 15.stats-top             | 12.stats-top             | ✅ 대응                       |
| Stats history    | 16.stats-history         | 13.stats-history         | ✅ 대응                       |
| Trigger          | 17.trigger               | 14.triggers              | ✅ 대응                       |
| Config/Settings  | 18.config, 19.config-json | 01.settings             | 동일 데이터, 다른 포맷       |
| Snippet by-abbr  | -                        | 04.snippets-by-abbrev    | CLI 미구현                    |
| Health check     | -                        | 00.health                | API 전용                      |
| CLI quit         | -                        | 17.cli-quit              | API 전용 (CLI에서 불필요)     |
| Alfred import    | -                        | 18.import-alfred         | CLI import 커맨드 미테스트    |
