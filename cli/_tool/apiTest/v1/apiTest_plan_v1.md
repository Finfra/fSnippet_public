---
name: apiTest_plan
description: openapi.yaml 기반 API 테스트 스크립트 생성 계획
date: 2026-04-07
---

# 디렉토리 구조

```
cli/_tool/apiTest/
├── apiTestDo.sh                    ← 실행기 (전체 또는 단건)
├── apiTest_plan.md                 ← 본 문서
├── 00.health.sh ~ 29.*.sh          ← 정상 케이스 (30개)
└── E01.*.sh ~ E08.*.sh             ← 에러 케이스 (8개)
```

# 파일명 규칙

```
{00~99}.{내역}.sh       ← 정상 케이스
E{01~99}.{내역}.sh      ← 에러 케이스
```

* 번호: 0부터 시작, 카테고리별 그룹핑
* 내역: 엔드포인트를 간결하게 표현 (kebab-case)

# 실행 방법

```bash
# 전체 순서대로 실행
source cli/_tool/apiTestDo.sh

# 특정 번호만 실행
source cli/_tool/apiTestDo.sh 0     # → 00.hello.sh
source cli/_tool/apiTestDo.sh 3     # → 03.snippets-search.sh
```

# apiTestDo.sh 동작

* 인자 없음: `[0-9]*.sh`, `E*.sh` 를 번호순 정렬 후 전체 실행 (17.cli-quit은 마지막)
* 인자 있음(숫자): `{00~99}.*.sh` 패턴 매칭하여 해당 스크립트만 실행 (0 → 00으로 자동 패딩)

# 테스트 스크립트 목록

## 정상 케이스 (30개)

| 번호 | 파일명                           | Method | Endpoint                                     | Tag       |
| ---: | :------------------------------- | :----- | :------------------------------------------- | :-------- |
|   00 | `00.health.sh`                   | GET    | `/`                                          | Status    |
|   01 | `01.settings.sh`                 | GET    | `/settings`                                  | Settings  |
|   02 | `02.snippets-list.sh`            | GET    | `/snippets?limit=5`                          | Snippets  |
|   03 | `03.snippets-search.sh`          | GET    | `/snippets/search?q={동적}&limit=5`          | Snippets  |
|   04 | `04.snippets-by-abbrev.sh`       | GET    | `/snippets/by-abbreviation/{동적}`           | Snippets  |
|   05 | `05.snippets-detail.sh`          | GET    | `/snippets/{동적 id}`                        | Snippets  |
|   06 | `06.snippets-expand.sh`          | POST   | `/snippets/expand`                           | Snippets  |
|   07 | `07.clipboard-history.sh`        | GET    | `/clipboard/history?limit=5`                 | Clipboard |
|   08 | `08.clipboard-detail.sh`         | GET    | `/clipboard/history/1`                       | Clipboard |
|   09 | `09.clipboard-search.sh`         | GET    | `/clipboard/search?q=test&limit=5`           | Clipboard |
|   10 | `10.folders-list.sh`             | GET    | `/folders`                                   | Folders   |
|   11 | `11.folders-detail.sh`           | GET    | `/folders/{동적}`                            | Folders   |
|   12 | `12.stats-top.sh`                | GET    | `/stats/top?limit=5`                         | Stats     |
|   13 | `13.stats-history.sh`            | GET    | `/stats/history?limit=5`                     | Stats     |
|   14 | `14.triggers.sh`                 | GET    | `/triggers`                                  | Triggers  |
|   15 | `15.cli-status.sh`               | GET    | `/cli/status`                                | CLI       |
|   16 | `16.cli-version.sh`              | GET    | `/cli/version`                               | CLI       |
|   17 | `17.cli-quit.sh`                 | POST   | `/cli/quit` (⚠️ 앱 종료됨)                  | CLI       |
|   18 | `18.import-alfred.sh`            | POST   | `/import/alfred`                             | Import    |
|   19 | `19.snippets-list-folder.sh`     | GET    | `/snippets?folder={동적}`                    | Snippets  |
|   20 | `20.snippets-search-folder.sh`   | GET    | `/snippets/search?q={동적}&folder={동적}`    | Snippets  |
|   21 | `21.clipboard-history-kind.sh`   | GET    | `/clipboard/history?kind=plain_text`         | Clipboard |
|   22 | `22.clipboard-history-app.sh`    | GET    | `/clipboard/history?app={동적}`              | Clipboard |
|   23 | `23.clipboard-history-pinned.sh` | GET    | `/clipboard/history?pinned=true`             | Clipboard |
|   24 | `24.stats-history-date.sh`       | GET    | `/stats/history?from=...&to=...`             | Stats     |
|   25 | `25.snippets-expand-placeholder.sh` | POST | `/snippets/expand` + `placeholder_values`   | Snippets  |
|   26 | `26.folders-create.sh`               | POST   | `/folders`                                   | Folders   |
|   27 | `27.folders-delete.sh`               | DELETE | `/folders/{name}`                            | Folders   |
|   28 | `28.snippets-create.sh`              | POST   | `/snippets`                                  | Snippets  |
|   29 | `29.snippets-delete.sh`              | DELETE | `/snippets/{id}`                             | Snippets  |

## 에러 케이스 (8개)

| 파일명                               | 기대 코드 | 설명                          |
| :----------------------------------- | ---------: | :---------------------------- |
| `E01.snippets-search-no-q.sh`       |        400 | `q` 파라미터 누락             |
| `E02.snippets-detail-404.sh`        |        404 | 존재하지 않는 ID              |
| `E03.clipboard-detail-bad-id.sh`    |        400 | 잘못된 ID 형식                |
| `E04.cli-quit-no-confirm.sh`        |        400 | `X-Confirm` 헤더 누락         |
| `E05.folders-create-empty-name.sh`  |        400 | 빈 이름으로 폴더 생성         |
| `E06.folders-delete-notempty.sh`    |        409 | 비어있지 않은 폴더 삭제       |
| `E07.snippets-create-no-folder.sh`  |        404 | 존재하지 않는 폴더에 스니펫   |
| `E08.snippets-delete-404.sh`        |        404 | 존재하지 않는 스니펫 삭제     |

# 공통 변수

```bash
BASE="http://localhost:3015/api/v1"
```

* `00.health.sh`만 `http://localhost:3015/` (루트) 대상
* 나머지는 모두 `$BASE` prefix 사용

# apiTest ↔ cmdTest 교차 비교

| 기능             | apiTest                  | cmdTest                  | 비고                          |
| :--------------- | :----------------------- | :----------------------- | :---------------------------- |
| Health check     | 00.health                | -                        | API 전용 (CLI에 대응 없음)    |
| Settings/Config  | 01.settings              | 18.config, 19.config-json | 동일 데이터, 다른 포맷       |
| Snippet list     | 02.snippets-list         | 04.snippet-list          | ✅ 대응                       |
| Snippet search   | 03.snippets-search       | 05.snippet-search        | ✅ 대응                       |
| Snippet by-abbr  | 04.snippets-by-abbrev    | -                        | CLI 미구현                    |
| Snippet detail   | 05.snippets-detail       | 06.snippet-get           | ✅ 대응                       |
| Snippet expand   | 06.snippets-expand       | 07.snippet-expand        | ✅ 대응                       |
| Snippet expand+placeholder | 25.snippets-expand-placeholder | -              | placeholder_values 파라미터  |
| Snippet folder filter | 19.snippets-list-folder | -                       | folder 파라미터              |
| Search folder filter | 20.snippets-search-folder | -                      | search + folder 파라미터     |
| Snippet limit    | -                        | 08.snippet-list-limit    | API에서는 02에서 limit 사용   |
| Snippet JSON     | -                        | 09.snippet-list-json     | API는 항상 JSON               |
| Clipboard list   | 07.clipboard-history     | 10.clipboard-list        | ✅ 대응                       |
| Clipboard detail | 08.clipboard-detail      | 11.clipboard-get         | ✅ 대응                       |
| Clipboard search | 09.clipboard-search      | 12.clipboard-search      | ✅ 대응                       |
| Clipboard kind   | 21.clipboard-history-kind | -                       | kind 파라미터                |
| Clipboard app    | 22.clipboard-history-app  | -                       | app 파라미터                 |
| Clipboard pinned | 23.clipboard-history-pinned | -                     | pinned 파라미터              |
| Folder list      | 10.folders-list          | 13.folder-list           | ✅ 대응                       |
| Folder detail    | 11.folders-detail        | 14.folder-get            | ✅ 대응                       |
| Stats top        | 12.stats-top             | 15.stats-top             | ✅ 대응                       |
| Stats history    | 13.stats-history         | 16.stats-history         | ✅ 대응                       |
| Stats date range | 24.stats-history-date    | -                        | from/to 파라미터             |
| Triggers         | 14.triggers              | 17.trigger               | ✅ 대응                       |
| CLI status       | 15.cli-status            | 03.status                | ✅ 대응                       |
| CLI version      | 16.cli-version           | 01.version, 02.version-short | ✅ 대응                  |
| CLI quit         | 17.cli-quit              | -                        | API 전용 (CLI에서 불필요)     |
| Alfred import    | 18.import-alfred         | -                        | CLI import 커맨드 미테스트    |
| Folder create    | 26.folders-create        | -                        | CRUD: POST /folders           |
| Folder delete    | 27.folders-delete        | -                        | CRUD: DELETE /folders/{name}  |
| Snippet create   | 28.snippets-create       | -                        | CRUD: POST /snippets          |
| Snippet delete   | 29.snippets-delete       | -                        | CRUD: DELETE /snippets/{id}   |
| Help             | -                        | 00.help                  | CLI 전용                      |

# openapi.yaml ↔ Swift 구현 검증 결과

| 영역     | 결과    | 비고                                           |
| :------- | :------ | :--------------------------------------------- |
| Snippets  | ✅ 일치 | 7개 엔드포인트 모두 정확 (CRUD 포함)           |
| Clipboard | ✅ 일치 | 3개 엔드포인트 모두 정확                       |
| Folders   | ✅ 일치 | 4개 엔드포인트 모두 정확 (CRUD 포함)           |
| Stats    | ⚠️ 부분 | `/stats/top` description 필드 값 로직 부정확   |
| Triggers | ✅ 일치 | -                                              |
| CLI      | ⚠️ 모델 | Codable 구조체 미정의 (JSONSerialization 사용) |
| Import   | ⚠️ 모델 | Request/Response Codable 모델 미정의           |
