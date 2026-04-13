---
name: apiTest_plan_v2
description: openapi_v2.yaml 기반 API v2 테스트 스크립트 계획 (Settings CRUD)
date: 2026-04-13
---

# 개요

v2 API(`/api/v2/`)는 fSnippet 설정(Settings) 전 항목을 읽기/쓰기하는 CRUD 중심 API.
`api/openapi_v2.yaml`이 SSOT. 38 paths / 59 operations.

# 디렉토리 구조

```
cli/_tool/apiTest/
├── apiTestDo.sh                    ← 실행기 (v1|v2|all|단건)
├── apiTest_plan_v1.md              ← v1 계획
├── apiTest_plan_v2.md              ← 본 문서 (v2 계획)
├── v1/                             ← v1 스크립트
└── v2/                             ← v2 스크립트
    ├── 00.v2-general-get.sh ~ 60.v2-snapshot-put.sh  ← 정상 케이스
    └── E00.v2-404.sh ~ E06.v2-popup-invalid.sh       ← 에러 케이스
```

# 파일명 규칙

```
{00~99}.v2-{내역}.sh       ← 정상 케이스
E{00~99}.v2-{내역}.sh      ← 에러 케이스
```

* 번호: 카테고리별 그룹핑 (00-09: general/snapshot, 10-19: behavior/history, 20-29: shortcuts, 30-39: snippet-folders, 40-49: excluded, 50-59: import, 60+: actions)

# 실행 방법

```bash
# v2 전체 실행
bash cli/_tool/apiTest/apiTestDo.sh v2

# v2 특정 번호 실행
bash cli/_tool/apiTest/apiTestDo.sh v2 5   # → v2/05.*.sh

# v1 + v2 전체
bash cli/_tool/apiTest/apiTestDo.sh all
```

# 공통 변수

```bash
BASE="http://localhost:3015/api/v2"
```

# 테스트 스크립트 목록

## 정상 케이스 (27개)

### General / Advanced / Snapshot (00-05)

| 번호 | 파일명                        | Method | Endpoint                        | 설명                         |
| ---: | :---------------------------- | :----- | :------------------------------ | :--------------------------- |
|   00 | `00.v2-general-get.sh`        | GET    | `/settings/general`             | General 설정 조회            |
|   01 | `01.v2-popup-get.sh`          | GET    | `/settings/popup`               | Popup 설정 조회              |
|   02 | `02.v2-behavior-get.sh`       | GET    | `/settings/behavior`            | Behavior 설정 조회           |
|   03 | `03.v2-advanced-info.sh`      | GET    | `/settings/advanced`            | Advanced/Debug/Performance 조회 |
|   04 | `04.v2-snapshot-get.sh`       | GET    | `/settings/snapshot`            | 스냅샷 Export (JSON)         |
|   05 | `05.v2-general-patch.sh`      | PATCH  | `/settings/general`             | General 설정 변경 후 원복    |

### Popup / Behavior / Debug / Performance / Input / History (10-16)

| 번호 | 파일명                        | Method | Endpoint                        | 설명                         |
| ---: | :---------------------------- | :----- | :------------------------------ | :--------------------------- |
|   10 | `10.v2-popup-patch.sh`        | PATCH  | `/settings/popup`               | Popup 설정 변경 후 원복      |
|   11 | `11.v2-behavior-patch.sh`     | PATCH  | `/settings/behavior`            | Behavior 설정 변경 후 원복   |
|   12 | `12.v2-debug-patch.sh`        | PATCH  | `/settings/advanced/debug`      | Debug 설정 변경 후 원복      |
|   13 | `13.v2-performance-patch.sh`  | PATCH  | `/settings/advanced/performance`| Performance 설정 변경 후 원복|
|   14 | `14.v2-input-patch.sh`        | PATCH  | `/settings/advanced/input`      | Input 설정 변경 후 원복      |
|   15 | `15.v2-history-get.sh`        | GET    | `/settings/history`             | History 설정 조회            |
|   16 | `16.v2-history-patch.sh`      | PATCH  | `/settings/history`             | History 설정 변경 후 원복    |

### Shortcuts (20-23)

| 번호 | 파일명                         | Method | Endpoint                        | 설명                         |
| ---: | :----------------------------- | :----- | :------------------------------ | :--------------------------- |
|   20 | `20.v2-shortcuts-list.sh`      | GET    | `/settings/shortcuts`           | 단축키 전체 목록             |
|   21 | `21.v2-shortcuts-get-one.sh`   | GET    | `/settings/shortcuts/{id}`      | 특정 단축키 조회             |
|   22 | `22.v2-shortcuts-put.sh`       | PUT    | `/settings/shortcuts/{id}`      | 단축키 등록/수정 후 원복     |
|   23 | `23.v2-shortcuts-delete.sh`    | DELETE | `/settings/shortcuts/{id}`      | 단축키 삭제 후 원복          |

### Snippet Folders (30-33)

| 번호 | 파일명                             | Method | Endpoint                              | 설명                         |
| ---: | :--------------------------------- | :----- | :------------------------------------ | :--------------------------- |
|   30 | `30.v2-snippet-folders-list.sh`    | GET    | `/settings/snippet-folders`           | 스니펫 폴더 목록             |
|   31 | `31.v2-snippet-folders-detail.sh`  | GET    | `/settings/snippet-folders/{name}`    | 특정 폴더 상세               |
|   32 | `32.v2-snippet-folders-patch.sh`   | PATCH  | `/settings/snippet-folders/{name}`    | 폴더 설정 변경 후 원복       |
|   33 | `33.v2-snippet-folders-rebuild.sh` | POST   | `/settings/snippet-folders/rebuild`   | 폴더 인덱스 재빌드           |

### Excluded Apps (40-42)

| 번호 | 파일명                             | Method | Endpoint                              | 설명                         |
| ---: | :--------------------------------- | :----- | :------------------------------------ | :--------------------------- |
|   40 | `40.v2-excluded-global.sh`         | GET    | `/settings/excluded/global`           | 전역 제외 앱 목록            |
|   41 | `41.v2-excluded-perfolder-crud.sh` | POST/DELETE | `/settings/excluded/per-folder` | 폴더별 제외 앱 CRUD        |
|   42 | `42.v2-excluded-perfolder-list.sh` | GET    | `/settings/excluded/per-folder`       | 폴더별 제외 앱 전체 조회     |

### Alfred Import (50-51)

| 번호 | 파일명                         | Method | Endpoint                        | 설명                         |
| ---: | :----------------------------- | :----- | :------------------------------ | :--------------------------- |
|   50 | `50.v2-alfred-import-source.sh`| GET    | `/settings/import/alfred/source`| Alfred 소스 경로 조회        |
|   51 | `51.v2-alfred-import-run.sh`   | POST   | `/settings/import/alfred`       | Alfred 임포트 실행           |

### Snapshot Import (60)

| 번호 | 파일명                    | Method | Endpoint                  | 설명                         |
| ---: | :------------------------ | :----- | :------------------------ | :--------------------------- |
|   60 | `60.v2-snapshot-put.sh`   | PUT    | `/settings/snapshot`      | 스냅샷 Import (복원)         |

## 에러 케이스 (7개)

| 파일명                              | 기대 코드 | 설명                                |
| :---------------------------------- | ---------: | :---------------------------------- |
| `E00.v2-404.sh`                    |        404 | 존재하지 않는 v2 엔드포인트         |
| `E01.v2-actions-confirm.sh`        |        400 | X-Confirm 헤더 없이 destructive 요청|
| `E02.v2-shortcuts-conflict.sh`     |        409 | 단축키 충돌 (중복 등록)             |
| `E03.v2-shortcuts-notfound.sh`     |        404 | 존재하지 않는 단축키 ID             |
| `E04.v2-snippet-folders-notfound.sh`|       404 | 존재하지 않는 폴더명                |
| `E05.v2-excluded-conflict.sh`      |        409 | 이미 제외된 앱 중복 추가            |
| `E06.v2-popup-invalid.sh`          |        400 | popup 설정 유효성 오류 (범위 초과)  |

# apiTest v2 ↔ cmdTest v2 교차 비교

| 기능                    | apiTest v2                    | cmdTest v2                         | 비고                         |
| :---------------------- | :---------------------------- | :--------------------------------- | :--------------------------- |
| Settings general GET    | 00.v2-general-get             | 00.settings-general-get            | ✅ 대응                      |
| Settings popup GET      | 01.v2-popup-get               | 01.settings-popup-get              | ✅ 대응                      |
| Settings behavior GET   | 02.v2-behavior-get            | 02.settings-behavior-get           | ✅ 대응                      |
| Settings advanced GET   | 03.v2-advanced-info           | -                                  | API 전용                     |
| Snapshot GET            | 04.v2-snapshot-get            | 10.settings-snapshot-export        | ✅ 대응 (format 차이 있음)   |
| Settings general PATCH  | 05.v2-general-patch           | 03.settings-general-set            | ✅ 대응                      |
| Settings popup PATCH    | 10.v2-popup-patch             | 04.settings-popup-set              | ✅ 대응                      |
| Settings behavior PATCH | 11.v2-behavior-patch          | 05.settings-behavior-set           | ✅ 대응                      |
| Shortcuts list          | 20.v2-shortcuts-list          | -                                  | API 전용 (CLI 미구현)        |
| Snippet folders list    | 30.v2-snippet-folders-list    | -                                  | API 전용 (CLI 미구현)        |
| Snapshot export         | 04.v2-snapshot-get            | 10.settings-snapshot-export        | ✅ 대응                      |
| Snapshot import         | 60.v2-snapshot-put            | 11.settings-snapshot-import        | ✅ 대응                      |
| Error: invalid value    | E06.v2-popup-invalid          | E01.settings-invalid-section       | ✅ 대응 (다른 케이스)        |
