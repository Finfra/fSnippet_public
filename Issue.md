---
name: Issue
description: fSnippetCli 이슈 관리
date: 2026-04-07
---

# Issue Management

* Issue HWM: 205
* Checkpoints:
      - 2026.07.20: d372aff (_doc_arch 정합성 검토(Issue193) 진행 중 작업 트리 스냅샷)
      - 2026.07.19: a494408 (Fix Issue192 Edit Mode ⌘S 스니펫 등록 오작동 회귀)
      - 2026.07.18: c3fe0c7 (Fix Issue191 "스니펫으로 등록" 전역 단축키·메뉴바 스텁)
      - 2026.07.09: 2e15877 (Fix(fSnippet#Issue949 후속) popupRows/searchScope/width/previewWidth stale-mirror 리싱크 추가)

# 🤔 결정사항

결정은 **각 정본 문서**에 산다 — 여기 사본을 두지 않는다(2026.09.02 정리).

| 결정 | 정본 |
| :--- | :--- |
| paidApp↔cliApp 연동은 상위 레포 프로토콜 문서 기준 | [paid_cli_protocol.md](../_doc_arch/paid_cli_protocol.md) — 상위 메인 레포 |
| 메뉴바는 `cli/_doc_arch/menuBar_enhance.md` 기준 (로컬 SSOT · gitignored) | [menuBar_enhance.md](cli/_doc_arch/menuBar_enhance.md) |

# 🌱 이슈후보

# 🚧 진행중

# 📕 중요

# 📙 일반

# 📗 선택

# ✅ 완료
## Issue203: [API] PUT /api/v2/settings/snapshot 이 명세와 달리 아무 설정도 복원하지 않는 no-op (등록: 2026-08-18, 완료: 2026-09-01) (Hash: 7853984) ✅
* 목적: `api/openapi_v2.yaml` 은 PUT snapshot 을 "전체 설정 스냅샷 복원(import, 부분 허용)" 으로 명세하고 성공 응답을 규정하나, 구현부는 각 섹션에 대해 로그만 남기고 실제 반영 로직이 전무함. 호출측(paidApp import 기능 등)이 성공 응답을 받고도 설정이 하나도 복원되지 않는 **조용한 실패**. consultant-m 검토(2026-08-18)에서 발견.
* 보류 해제 (2026-09-01): 등록 시 "App Store 제출 후 처리" 보류였으나 사용자 명시 지시로 착수·해결. 세션 2ed3956a(Issue972 조사) 맥락 반영.
* 상세:
    - 구현부: `cli/fSnippetCli/Managers/APIRouter.swift` `handleV2PutSnapshot` — 7개 섹션 각각에 `logD("... 현재 무시")` 만 존재. 반환값도 `v2NoContent()` (204) 로 명세의 200 "Restored" 와 불일치.
* 구현 (2026-09-01):
    - `handleV2PutSnapshot` 실복원 구현 — 제공된 각 섹션을 **검증된 기존 PATCH/PUT 핸들러로 위임 재사용** (synthetic localhost sub-request 로 각 핸들러의 decode·검증·부수효과를 그대로 통과). 신규 키 매핑을 만들지 않아 stale-mirror 계열 회귀(Issue178·183·184) 위험 회피 — 이슈 구현 명세 그대로.
    - 위임 대상: general(triggerKey 는 객체→token 문자열 변환) / popup / behavior / history / advanced.{performance, debug, input(nil→"" clear 매핑)} / snippetFolders(폴더별 PATCH, 없는 폴더 404→missing skip, rename 미수행) / perFolderExcludedFiles(폴더별 PUT 전체 교체)
    - 복원 제외: `settingsFolder`·`snippetFolder`(타 머신 스냅샷 import 시 데이터 폴더 경로 오염 방지), `settingsHotkey`·`popupHotkey`·`permissions`·`advanced.api`(read-only. popup 핫키는 popup 섹션으로 복원됨)
    - 시맨틱 확정(명세 기록): **best-effort 부분 복원·롤백 없음**. nil 섹션 skip. 응답 204 → **200 + `{ok, restored, skipped, failed}`** 섹션별 결과로 조용한 실패 제거. `api/openapi_v2.yaml` 에 `SnapshotRestoreResult` 스키마 신설·PUT 명세 동기화.
* 검증 (2026-09-01, brew 1.1.1 실측):
    - 원본 스냅샷 GET → 그대로 PUT: `ok=true`, 7개 섹션 + snippetFolders 56개 적용, failed 0건.
    - popupRows 10→7 / retentionDaysPlainText 90→45 / keyBufferSize 100→200 변경 PUT → REST GET·`_config.yml` 디스크 모두 반영. 원본 PUT 로 완전 원복. 잘못된 body 는 400 invalid_argument. 사용자 입력소스(Gureum han390) 보존.
    - **t=15s 지속 관찰**: popup·performance 키는 t=15s 까지 유지. **history 키만 t≈3s 에 원복** — 이는 본 이슈 코드가 아니라 Issue205(지연 stale mirror flush, history 전 키 소유)의 결함이며 위임한 PATCH /history 직접 호출과 동일하게 영향받음.
* 관련: **Issue205 미해결 동안 history 섹션 복원의 내구성은 보장되지 않음** (t≈3s 후 미러가 되씀). Issue205 해결 시 별도 코드 변경 없이 함께 안정화됨.

## Issue204: [Chore] 이슈후보 섹션에 종결된 Issue196 컨펌 항목이 잔존 — 규칙4 위반 (등록: 2026-08-18, 완료: 2026-08-18) (Hash: 995c4a5) ✅
* 목적: `🌱 이슈후보` 의 "[컨펌] Issue196 Collision 0.4초 지연 타이머 죽은 코드 해결 방향 결정" 항목이 컨펌·종결 후에도 삭제되지 않아 미결 항목처럼 보임. consultant-m 검토(2026-08-18)에서 발견.
* 상세:
    - 해당 항목은 ACK 2026-07-21 에 A안(제거)으로 컨펌되었고, Issue196 이 2026-07-22 "제거" 결정으로 완료(Hash: 5a7eafe)됨.
    - 그럼에도 이슈후보 목록에 그대로 남아 issue-g 규칙4("이슈 등록 시 이슈후보 섹션의 중복 항목은 삭제")를 위반한 상태.
* 구현 명세:
    - 로직: 이슈후보에서 해당 1줄 삭제. 결정 내용은 이미 Issue196 본문 "사용자 결정(2026-07-22): **제거**" 에 보존되어 있어 정보 손실 없음. handoff 원문(`handoff/z_consumed/20260721-162512-001.json`)도 별도 보존.
    - 검증: `grep -n "Issue196" Issue.md` 결과에 이슈후보 섹션 라인 없음 — 실측 통과(이슈후보 섹션 공란).

## Issue202: [Docs] README.md / README_ko.md 버전 표기가 v1.0.1 로 정체 — 실제 VERSION 은 1.1.1 (등록: 2026-08-18, 완료: 2026-08-18) (Hash: 995c4a5) ✅
* 목적: 공개(오픈소스) 저장소의 사용자 대면 문서가 실제 배포 버전과 어긋남. 에디션 표 버전 배지와 "최근 개선사항" 절이 v1.0.1 기준에 멈춰 있음. consultant-m 검토(2026-08-18)에서 발견.
* 상세:
    - README.md·README_ko.md 에디션 표의 fSnippetCli 버전 셀이 `v1.0.1`, "Recent Improvements (v1.0.1)"/"최근 개선사항 (v1.0.1)" 절도 동일 기준.
    - 마지막 README 수정 커밋(974ca93, "Update README with v1.0.1 release info")이 cli-v1.0.2·cli-v1.1.0 태그 지점에 머물러 있고, 이후 VERSION 은 1.1.0 → 1.1.1(Issue198)로 갱신되며 `cli/` 에 40커밋이 누적됨.
* 구현:
    - 양 README 에디션 표 버전 셀 `v1.0.1` → `v1.1.1` (VERSION 파일 SSOT 일치).
    - "Recent Improvements"/"최근 개선사항" 절을 v1.1.1 기준 7항목으로 재작성 — 974ca93 이후 완료 이슈에서 사용자 대면 변경만 선별(Issue172·177 단축키 즉시 반영 / Issue178·183·184 설정 원복 / Issue182·183 설정 포맷 가독화 / Issue185 팝업 마침표 / Issue186·190 폴더 목록·rename / Issue187~192 히스토리 미리보기·스니펫 등록 / Issue194~196 죽은 코드 정리).
    - REST API v1 폐기(410 GONE) 안내 1줄을 양 README 에 추가 — Issue201 과 동일 사실을 사용자 대면 문서에도 반영.
* 검증:
    - `grep -n "v1\.0\.1" README.md README_ko.md` → 0건 (exit 1) 실측.
    - 표기 버전 == `cat VERSION`(1.1.1) 실측. 한/영 항목 수 7개로 동일.
    - 앱 소스·빌드 설정 무변경 — `git diff --name-only` 에 `.swift`/`.yml`/`.pbxproj` 0건 실측(App Store 제출 빌드 영향 없음).

## Issue201: [Docs] CLAUDE.md REST API v1 설명이 실제 구현(전면 deprecated/410)과 불일치 (등록: 2026-08-18, 완료: 2026-08-18) (Hash: 995c4a5 — Issue.md 이력, 문서 본체 CLAUDE.md 는 gitignored) ✅
* 목적: CLAUDE.md 가 v1 을 정상 서빙되는 API 로 기술하고 Quick Start 예제도 v1 엔드포인트를 제시하나, 실제로는 모든 v1 요청이 410 GONE 으로 거부됨. 문서대로 실행한 신규 기여자가 정상 상태 대신 deprecated 에러를 받아 혼란을 겪음. consultant-m 검토(2026-08-18)에서 발견.
* 상세:
    - 구현: `cli/fSnippetCli/Managers/APIRouter.swift` `routeInternal` 진입부에서 `decodedPath.hasPrefix("/api/v1/")` 이면 무조건 `410 GONE "API v1 is deprecated. Use /api/v2/ instead."` 반환. 개별 v1 핸들러 도달 불가.
    - 실제 상태 조회 경로는 `GET /api/v2/status` (APIRouter 라우팅 실측). README.md 는 이미 `/api/v2/status` 로 정확히 표기.
* 구현:
    - "REST API 명세" 절 v1 항목을 "⛔ 전면 deprecated — 모든 요청 410 GONE, 신규 구현·호출 금지, `api/openapi_v1.yaml` 은 폐기 이력 보존용" 으로 교체. v2 항목에 v1 이 담당하던 조회 기능을 흡수 명기.
    - SSOT 문장을 "두 yaml" → `api/openapi_v2.yaml` 단수로 정정. "중요 관련 파일" 표 v1 yaml 행도 (폐기 — 이력 보존용) 표기.
    - Quick Start 예제 `curl .../api/v1/status` → `curl .../api/v2/status` + 폐기 주석 1줄.
* 검증:
    - `grep -n "api/v1" CLAUDE.md` 결과가 전부 deprecated 문맥임을 육안 확인 — 실행 예제로 남은 v1 호출 0건.
    - 앱 코드 무변경(문서 전용).
* ⚠️ 커밋 범위 주의: 본 저장소는 `.gitignore:3` 에서 `CLAUDE.md` 를 제외하고 있어 문서 본체는 버전관리 대상이 아님(공개 레포 특성상 의도된 설정으로 판단). 파일 수정은 워킹트리에 반영 완료, 커밋 해시는 본 Issue.md 이력 기준. Issue193 과 동일 표기 관례.

## Issue200: [Docs] CLAUDE.md 에 존재하지 않는 경로 참조 — locales/, cli/Issue.md (등록: 2026-08-18, 완료: 2026-08-18) (Hash: 995c4a5 — Issue.md 이력, 문서 본체 CLAUDE.md 는 gitignored) ✅
* 목적: CLAUDE.md 가 실재하지 않는 폴더·파일을 가리켜 신규 기여자·에이전트가 잘못된 경로를 탐색함. consultant-m 검토(2026-08-18)에서 발견.
* 상세:
    - "구조" 절 `locales/` · "다국어 (locales/)" 절 제목 — 실제 폴더명은 저장소 루트의 `localization/`. README.md 문서 표 링크도 `./localization/` 으로 정확히 표기됨.
    - "중요 관련 파일" 표 `[cli/Issue.md](cli/Issue.md)` — 실재하지 않음(`ls cli/Issue.md` No such file). 이슈 관리 파일은 저장소 **루트**의 `Issue.md`.
* 구현:
    - `locales/` → `localization/` 2곳(구조 목록·다국어 절 제목) 정정.
    - `[cli/Issue.md](cli/Issue.md)` → `[Issue.md](Issue.md)` + 설명에 "저장소 루트, cli/ 아님" 명기하여 재발 방지.
* 검증:
    - `grep -n "locales/\|cli/Issue\.md" CLAUDE.md` → 0건 (exit 1) 실측.
    - 참조 대상 실존 확인 — `ls -d localization Issue.md` 양쪽 존재 실측.
* ⚠️ 커밋 범위 주의: Issue201 과 동일 — `CLAUDE.md` 는 `.gitignore` 대상이라 워킹트리 반영만 되고 커밋에는 포함되지 않음.

## Issue199: [Docs] CLAUDE.md brew 패키지명 오기재 — fsnippetcli(하이픈 없음) vs 실제 fsnippet-cli (등록: 2026-08-18, 완료: 2026-08-18) (Hash: 995c4a5 — Issue.md 이력, 문서 본체 CLAUDE.md 는 gitignored) ✅
* 목적: CLAUDE.md 의 Formula 파일명·Quick Start brew 명령이 하이픈 없는 `fsnippetcli` 로 적혀 있어, 문서를 그대로 복붙 실행하면 formula 를 찾지 못해 실패함. consultant-m 검토(2026-08-18)에서 발견.
* 상세:
    - CLAUDE.md "중요 관련 파일" 표 배포 행: `cli/Formula/fsnippetcli.rb` — 실제 파일명은 `cli/Formula/fsnippet-cli.rb`.
    - CLAUDE.md Quick Start: `brew install finfra/tap/fsnippetcli` · `brew services start fsnippetcli` — 실제 tap 패키지명은 `fsnippet-cli`.
    - 대조 근거: `cli/_tool/fsc-deploy-brew.sh` 전역이 `fsnippet-cli` 로 통일(TAP_FORMULA·brew install/services/uninstall 전부), README.md·README_ko.md 도 하이픈 포함으로 정확히 표기. 오기재는 CLAUDE.md 단독.
* 구현:
    - "중요 관련 파일" 표 배포 행 `cli/Formula/fsnippetcli.rb` → `cli/Formula/fsnippet-cli.rb`.
    - Quick Start `brew install finfra/tap/fsnippetcli` → `.../fsnippet-cli`, `brew services start fsnippetcli` → `fsnippet-cli`.
* 검증:
    - `grep -n "fsnippetcli" CLAUDE.md` → 0건 (exit 1) 실측.
    - 정정된 Formula 경로 실존 확인 — `ls cli/Formula/fsnippet-cli.rb` 존재 실측. 배포 스크립트(`cli/_tool/fsc-deploy-brew.sh`)의 명칭과 일치.
    - 소스코드·빌드 산출물 무변경(문서 전용).
* ⚠️ 커밋 범위 주의: Issue201 과 동일 — `CLAUDE.md` 는 `.gitignore` 대상이라 워킹트리 반영만 되고 커밋에는 포함되지 않음.

## Issue198: [Release] 버전 1.1.1 bump — brew publish 사전 준비 (등록: 2026-08-18, 완료: 2026-08-18) (Hash: 134d1dd) ✅
* 목적: cli-v1.1.0 공개(2026-07-13) 이후 cli/ 에 40커밋 누적 — 같은 버전 번호에 다른 바이너리 배포를 막기 위해 패치 상승(사용자 승인, pm-do 위임 작업). GitHub API outage 로 원격 publish 는 보류, 로컬 준비까지만.
* 상세:
    - VERSION 1.1.0 → 1.1.1 (SSOT). develop 에서 bump 후 release/1.1.1 신설 (release/1.1.0 브랜치는 잔존 — 삭제는 승인 대상이라 보류)
    - `cli/Formula/fsnippet-cli.rb` url/version 1.1.1 동기화. sha256 은 publish 5단계가 새 tarball 로 재계산하므로 구값 유지
    - `cli/version-meta.yml` 은 버전 값 미보관(주석 규약 준수) — 변경 불요 확인
    - `cli/project.yml`·`project.pbxproj` MARKETING_VERSION 1.1.1 동기화 (publish 층2 검증게이트: Info.plist ≠ VERSION 시 중단 대비)
* 구현 명세:
    - 검증: Release 빌드 통과 + 산출물 Info.plist `CFBundleShortVersionString` = 1.1.1 실측
    - 후속: GitHub API 복구 후 `/deploy brew publish` 실행 (release/1.1.1 에서, cli-v1.1.1 태그)

## Issue197: [Release] 앱스토어 업로드 준비 — develop 정리 커밋 + release/1.1.0 머지 (등록: 2026-08-17, 완료: 2026-08-17) (Hash: 2a63cf7) ✅
* 목적: 앱스토어 업로드 준비를 위해 develop 의 미커밋 변경을 정리하고 release/1.1.0 에 반영 (pm-do 위임 작업).
* 상세:
    - Issue.md 이슈후보 1건(mq handoff 유래)만 커밋(2a63cf7). `.vscode/settings.json` 은 로컬 IDE 색상 설정이라 커밋에서 제외(워킹트리 유지).
    - VERSION=1.1.0 확인 후 develop → release/1.1.0 fast-forward 머지, release/1.1.0 체크아웃 상태로 종료.
* 구현 명세:
    - 검증: `git log --oneline -1 release/1.1.0` 이 develop HEAD 와 동일 지점인지 확인.

## Issue196: [Chore] Collision 0.4초 지연 타이머 죽은 코드 — 제거 확정 (등록: 2026-07-20, 완료: 2026-07-22) (Hash: 5a7eafe) ✅
* depends: Issue193
* 목적: Issue193 검토에서 발견. Issue479 설계의 "짧은 약어 충돌 시 0.4초 대기" 로직이 미구현 죽은 코드 상태 — 예약 함수 `CollisionManager.setupPendingCollision(candidate:)`(`CollisionManager.swift:36`)의 호출부가 전무하여 `pendingCollisionTimer`·`triggerPendingCollisionMatch()`·`KeyEventMonitor.triggerCollisionMatch` 콜백 전체가 발동 불가. 현재 실동작은 `hasLongerMatches` 시 즉시 무시(`TriggerProcessor.swift:59-64` `return false`) 후 다음 입력 재평가. 원 설계(타이머 복원)와 현행 유지(죽은 코드 제거) 중 UX 방향 결정 필요하여 착수 보류 — `(!)` 마커로 등록.
* 상세:
    - 사용자 결정(2026-07-22): **제거**. "짧은 약어 입력 후 확장 대기" UX보다 "즉시 무시 후 재평가"가 이미 안정 동작 중이므로 죽은 코드만 정리.
    - 제거 대상: `cli/fSnippetCli/Managers/CollisionManager.swift`(파일 삭제), `KeyEventMonitor`의 `CollisionManagerDelegate` 채택·`CollisionManager.shared.delegate` 배선·`triggerCollisionMatch(_:)` 콜백, `KeyEventHandler`의 60Hz collision throttle(`shouldRunCollisionCheck`/`lastCollisionCheckTime`/`collisionCheckInterval`) 및 `validatePendingCollision`/`cancelPendingCollision` 호출 4곳(중복 함수 2벌 × 2호출).
* 구현 명세:
    - `KeyEventMonitor.swift`: `CollisionManagerDelegate` 프로토콜 채택 제거, `CollisionManager.shared.delegate = self` 배선 제거, `triggerCollisionMatch` 콜백 삭제(`performTextReplacement`는 `TriggerProcessorDelegate` 몫이라 존치).
    - `KeyEventHandler.swift`: throttle 헬퍼(`shouldRunCollisionCheck` 등) + "Pending Collision Check" 블록 2곳 + `cancelPendingCollision()` 호출 2곳 삭제.
    - `project.yml`(glob 기반) → `xcodegen generate` 로 `project.pbxproj` 재생성해 파일 참조 동기화.
    - `appSetting.json` logFilter allowList 의 `CollisionManagerDelegate` 항목 제거.
    - 설계 문서 갱신(로컬 `_doc_arch`, gitignored): `abbreviation_matching.md`, `ARCHITECTURE.md`, `tech-consultant.md`, `key-event/design_keyProcess.md`, `key-event/design_keyEventMonitor.md`(§3.6 절 삭제), `class/design_CLASS_RESPONSIBILITIES.md`, `diagram/DIAGRAM_CLASS_all.mermaid` — `CollisionManager` 참조 전부 "제거됨" 각주로 대체. `_doc_base/domain-map.yml`·`EmojiForFile.csv` 도 동일 정리.
    - 검증: `grep -rn "CollisionManager" cli/fSnippetCli --include="*.swift"` 0건. `xcodebuild -scheme fSnippetCli -configuration Release build` BUILD SUCCEEDED. `/run`(`fsc-deploy-brew.sh local`) 9/9 PASS — REST API(`localhost:3015`) 정상 응답.

## Issue193: [Docs] cli/_doc_arch 설계 문서 ↔ 소스코드 정합성 전수 검토 및 업데이트 (등록: 2026-07-20, 완료: 2026-07-20) (Hash: 35edadd — Issue.md 이력, 문서 본체는 gitignored) ✅
* 목적: `cli/_doc_arch/` 27개 설계 문서가 최근 이슈들(Issue122/125/188/189/189_2/190/191/192, Issue543 프리뷰 윈도우 통합 등) 이후의 실제 소스코드 상태를 반영하지 못해 stale 해진 부분을 전수 검증하고 갱신함.
* 상세:
    - 검토 범위: ARCHITECTURE.md, class/, key-event/(4)+abbreviation_matching, clipboard/(4), api/(3), popup/(3), shortcut/, snippet/, statistic/, event/, appsetting-json-design, settings-folder-resolve, menuBar_enhance, paidApp_version, tech-consultant
    - 대조 소스: `cli/fSnippetCli/` 135개 Swift 파일 + `api/openapi_v2.yaml`
    - 방식: 도메인별 병렬 검토 agent 7개(arch/key-event/clipboard/api/settings/ui/misc)가 불일치를 근거(파일:줄)와 함께 수집 → 확정본만 문서 반영
* 해결 (2026-07-20):
    - 총 **55건 불일치** 확정·문서 반영: settings 6 · misc 9 · ui 10 · arch 9 · clipboard 6 · api 9 · key-event 6
    - 주요 정정: handlePaidFeature "단일 진입점" 허위 → 라우팅 3메서드 체계 / ⌘S 스니펫 등록 "유료 안내" → paidApp New Snippet 라우팅(Issue188/189) / "0.15초 고정 딜레이" → 폴링 방식 / Collision 0.4초 타이머 미구현 명시 / snippetMap 타입·우선순위(append + first-wins) / Focus Retention Editor 분기 사문화 / REST 인증·Rate Limit 미구현 표기 / GET general 응답 keyCode=null 고정 + 누락 필드·엔드포인트 보강 / "미구현" 표기 3건 역방향 stale 해소(Issue191 ⌘S 등) / 죽은 링크·라인 인용 다수 정정
    - 파생 이슈: Issue194(ensureStructureSync 연결, 0cfb9be ✅) · Issue195(handlePaidFeature 제거, 7f33e3a ✅) · Issue196(Collision 타이머 제거, 5a7eafe ✅)
    - 검증: 수정 후 `grep -rn "handlePaidFeature" cli/ --include="*.swift"` 이력 주석 1건 외 0건, `/run` 9/9 PASS (Issue194/195 경유)

## Issue194: [Fix] ensureStructureSync() 죽은 코드 — 앱 시작 경로 미연결로 legacy 마이그레이션·규칙 파일 번들 시드 도달 불가 (등록: 2026-07-20, 완료: 2026-07-20) (Hash: 0cfb9be) ✅
* depends: Issue193
* 목적: Issue193 검토에서 발견. `PreferencesManager.ensureStructureSync()`/`ensureStructure()`가 어디서도 호출되지 않아, 내부에만 있는 두 설계 의도가 도달 불가 상태였음: (1) legacy `config.yaml` → `_config.yml` rename 마이그레이션(Issue333), (2) `_rule.yml`/`_rule_for_import.yml` 번들 사전 복사(Issue474_3 — Alert 중복 방지 목적).
* 상세:
    - 기존 앱 시작 경로: `PreferencesManager.init()` → `ensureDirectoriesExist()` + `loadConfig()` → `loadConfigInternal()`. `_config.yml` 부재 시 legacy 확인 없이 즉시 번들 복사/기본값 생성 → 마이그레이션 기회 영구 상실.
    - `_rule.yml` 부재 시 방어선이 `RuleManager.ensureRuleFile(at:)`의 3버튼 대화형 NSAlert 뿐 — Issue474_3 이 의도한 "조용한 사전 시드"가 작동하지 않았음.
* 해결 (2026-07-20):
    - `PreferencesManager.init()`의 `ensureDirectoriesExist()` 호출을 `ensureStructureSync()`로 교체 — 마이그레이션·번들 시드가 `loadConfig()`(async barrier)의 신규 파일 생성보다 먼저 실행되도록 init 내 선행 배치. `ensureStructureSync` 내부가 `ensureDirectoriesExist` 포함 + `loadConfigInternal` 직접 호출 구조라 textQueue 중첩 데드락 없음.
    - 검증: `/run` 9/9 PASS (Release 빌드 → brew local 재설치 → services start → REST 3015 응답). 앱 시작 로그에 `ensureStructureSync` 전용 시그니처 "Config 파일 이미 존재함 (Sync)" 출력 확인 — 죽은 코드가 실행 경로에 편입됨.

## Issue195: [Chore] handlePaidFeature() 미호출 죽은 코드 제거 — outdated URL Scheme 라우팅 잔존 (등록: 2026-07-20, 완료: 2026-07-20) (Hash: 7f33e3a) ✅
* depends: Issue193
* 목적: Issue193 검토에서 발견. `PaidAppManager.handlePaidFeature()`는 호출부가 전무한 죽은 코드이며, `.started` 분기가 Issue903 에서 unreliable 로 폐기된 `PaidAppDetector.openSettings()` URL Scheme 방식을 그대로 담고 있어 향후 오용 시 회귀 위험이 있었음.
* 상세:
    - 실제 라우팅은 `handleNewSnippet`/`handleEditSnippet`/`openSettings()` 3개 메서드로 분산 구현되어 있고 각각 최신 방식(DistributedNotification 등) 사용.
    - grep 결과 호출부 0건 — 삭제해도 컴파일·동작 영향 없음.
* 해결 (2026-07-20):
    - `PaidAppManager.swift`에서 `handlePaidFeature()` 메서드·doc comment 블록 제거, 제거 사유 주석(Issue195) 대체. `handleNewSnippet` doc comment 의 참조 문구도 자립형으로 정리.
    - `cli/_doc_arch/paidApp_version.md`(§1/§3.2/§5/§9/§10)·`menuBar_enhance.md` 의 handlePaidFeature 언급을 제거 사실·3메서드 체계로 갱신.
    - 검증: `grep -rn "handlePaidFeature" cli/ --include="*.swift"` 이력 주석 1건(HistoryPreviewView Issue189 "was handlePaidFeature") 외 0건 + `/run` 9/9 PASS.

## Issue192: [Bug] 클립보드 히스토리 Edit Mode(Tab-Tab 진입)에서 ⌘S가 "편집 저장" 대신 "스니펫 등록"으로 오작동 — Issue189 후속 회귀 (등록: 2026-07-19, 완료: 2026-07-19) (Hash: a494408) ✅
* depends: Issue189
* 목적: 클립보드 히스토리 뷰어에서 Tab을 두 번 눌러 Edit Mode(`previewEdit`)에 진입한 뒤 ⌘S를 누르면, 하단 힌트("Esc: Exit Edit | ⌘s: Save & View")와 다르게 편집 내용이 저장되지 않고 매번 "스니펫으로 등록" 동작이 실행됨. `PreviewTextView`의 `onSave`(텍스트를 `ClipboardDB`에 저장) 경로가 도달 불가능한 죽은 코드 상태가 되어 있음.
* 상세 (코드 조사 결과):
    - `HistoryViewer.swift`의 window-level keyDown 모니터(`handleKeyEvent`, L279-318)가 ⌘S를 chvMode 구분 없이 무조건 "스니펫 등록"으로 처리함. `isRegisterShortcut` 조건(L292-299)에 chvMode 체크가 전혀 없음 — Issue189_2(2026-07-13, "리스트 모드 Cmd+S 상시 허용")에서 기존 모드 스코프 제한이 제거된 것이 원인으로 추정됨.
    - 원래 이 모니터를 우회시켜야 할 가드 `if HistoryPreviewManager.shared.isPreviewWindow(event.window) { return event }`(`HistoryViewer.swift` L170-173)가, Issue543(프리뷰가 별도 NSWindow에서 같은 윈도우로 통합된 리팩터링)로 인해 `HistoryPreviewManager.isPreviewWindow()`(`HistoryPreviewManager.swift` L32-35)가 항상 `false`를 반환하도록 바뀌어 사실상 무력화되어 있음. Edit Mode도 같은 History 윈도우 안에서 렌더링되므로 이 가드가 더 이상 아무것도 걸러내지 못함.
    - 결과적으로 `handleKeyEvent`가 ⌘S 이벤트를 항상 먼저 소비(`return nil`)하여, `HistoryPreviewView.swift`의 chvMode 인식 ⌘S 분기(L200-214, previewView 전용 스니펫 등록)와 `PreviewTextView.swift`의 `onSave` 콜백(L227-231, Edit Mode 전용 편집 저장)에 이벤트가 도달하지 못함. 후자가 죽은 코드가 된 것이 이번 버그의 직접 원인.
    - Issue189의 구현 명세에는 명시적으로 "Edit 모드(`PreviewTextView` CL045_10 Cmd+S = 텍스트 편집 저장)는 별개 기능이므로 변경 없음"이라고 되어 있어, 이번 회귀는 그 이후 변경(Issue189_2)이 의도치 않게 그 경계를 깬 것으로 판단됨.
* 구현 명세:
    - `HistoryViewer.swift` L292-299의 `isCmdS`/`isRegisterShortcut` 판정에 `clipboardManager.chvMode != .previewEdit` 조건을 추가하여, Edit Mode 중에는 window-level 모니터가 ⌘S를 소비하지 않고 `return event`로 통과시키도록 한다 (List/Interactive View 모드의 기존 "스니펫 등록" 동작은 그대로 유지).
    - 통과된 이벤트는 기존 체인대로 `PreviewTextView.swift` L227-231의 `onSave` 콜백(→ `HistoryPreviewView.swift` L120-143, `ClipboardDB.shared.updateItemContent`로 DB 저장 + Interactive View 전환)이 정상 처리하는지 확인.
    - 검증: (1) List/Interactive View 상태에서 ⌘S → 여전히 "스니펫 등록"(paidApp 새 스니펫 창) 동작 확인 (회귀 없음). (2) Tab-Tab으로 Edit Mode 진입 → 텍스트 수정 → ⌘S → 토스트 "저장됨" 표시 + Interactive View로 복귀 확인.
* 해결 (2026-07-19):
    - `HistoryViewer.swift` `handleKeyEvent()` L292-303: `isRegisterShortcut` 판정 선두에 `clipboardManager.chvMode != .previewEdit` 조건 추가. Edit Mode 중에는 window-level 모니터가 ⌘S를 소비하지 않고 `return event`로 통과시켜, `PreviewTextView.swift`의 `onSave` 콜백(→ `ClipboardDB.updateItemContent` 저장 + Interactive View 전환)이 정상 도달하도록 함. List/Interactive View 모드의 기존 "스니펫 등록" 동작은 조건 그대로 유지.
    - 검증: Release 빌드 성공(`xcodebuild -scheme fSnippetCli -configuration Release build` — BUILD SUCCEEDED). 코드 경로 재확인으로 Edit Mode에서 register-shortcut 분기가 더 이상 매칭되지 않고 default case를 거쳐 `return false`(이벤트 미소비)로 귀결됨을 확인. brew 배포 후 실사용 UI 조작 검증(토스트 "저장됨" 노출·DB 반영)은 사용자 재확인 필요.

## Issue191: [Fix] 클립보드 히스토리 "스니펫으로 등록" 전역 단축키·메뉴바가 미구현 스텁만 실행 (등록: 2026-07-18, 완료: 2026-07-18) (Hash: c3fe0c7) ✅
* 목적: 설정 화면(⌃⌘F6 등)에 노출된 "스니펫으로 등록" 단축키를 클립보드 히스토리 창 밖에서(전역 단축키·메뉴바 "Clipboard to Snippet") 실행하면 "Register Snippet — pending implementation" 토스트만 뜨고 실제 등록이 안 되는 문제.
* 원인: 같은 기능에 두 개의 별도 코드 경로가 존재했음.
    - `HistoryViewer.swift`(창 내부 로컬 키 핸들러, ⌘S): Issue188/189에서 `viewModel.registerAndEditAsSnippet(item:)`로 실제 구현됨 — 정상 동작
    - `ShortcutMgr.swift`(전역 시스템 단축키) + `MenuBarView.swift`(메뉴바 클릭): Issue84 당시 "백엔드 구현 보류"로 남긴 토스트 스텁이 그대로 방치됨 — Issue188/189 통합 시 갱신 누락
* 구현 명세:
    - `cli/fSnippetCli/UI/History/HistoryViewModel.swift`: `currentSelectedItem` 계산 프로퍼티 추가 (selectedId → ClipboardItem 변환)
    - `cli/fSnippetCli/Managers/HistoryViewerManager.swift`: `registerCurrentSelectionAsSnippet()` 추가 — 히스토리 창이 열려 있고 선택된 항목이 있으면 기존 `registerItemAsSnippet(_:)`을 재사용해 등록, 아니면 `false` 반환
    - `cli/fSnippetCli/Managers/ShortcutMgr.swift`: `executeAction(for:)`의 `"history.registerSnippet.hotkey"` 분기에서 스텁 토스트 제거 → `registerCurrentSelectionAsSnippet()` 호출, 실패 시 안내 토스트("클립보드 히스토리에서 항목을 선택한 후 다시 시도하세요")
    - `cli/fSnippetCli/MenuBarView.swift`: `registerSnippetAction()` 동일하게 교체
* 검증: `/run`으로 paidApp+cliApp 빌드·배포·재시작(Release → brew local reinstall) 9/9 PASS, REST API(3015) 헬스체크 정상 응답 확인. (수동 UI 재현 테스트는 사용자 확인 대기)
* 참고: 창을 열지 않고 최신 클립보드 항목을 바로 등록하는 더 공격적인 UX는 이번 스코프 밖 — 별도 이슈 판단 필요 시 후속 등록.

## Issue190: [Feat] REST v2 폴더 rename 미지원 — PATCH snippet-folders에 name 필드 추가 (등록: 2026-07-13) (✅ 완료, 69e94d4, 03a56ee / paidApp fSnippet#Issue957) ✅
* 목적: paidApp 스니펫 탭 폴더 규칙 편집기에서 폴더명 변경이 저장되지 않는 문제(paidApp fSnippet#Issue957)의 근본 원인 해결 — cliApp REST v2에 폴더 rename을 노출하는 엔드포인트가 전혀 없었음. `SnippetFileManager.renameFolder`(→`SnippetRepository.renameFolder`)는 이미 정상 동작했으나 REST 레이어에 미노출.
* 상세:
    - `PATCH /api/v2/settings/snippet-folders/{folder}` 요청 바디에 `name` 필드가 있고 기존 폴더명과 다르면: 물리적 폴더 rename → `_rule.yml` 컬렉션 엔트리 rename(name은 `let`이라 CollectionRule 재구성 후 교체) → `openable` 프리퍼런스 키 이관 → 이후 prefix/suffix 처리는 새 이름 기준 진행.
    - 검증: `POST /api/v2/folders` 로 임시 폴더 생성 → `PATCH .../snippet-folders/{name}` `{"name":"...Renamed"}` → 응답 `folder` 필드가 새 이름으로 반환되고 디스크 상 실제 rename 확인 → `DELETE`로 정리.
* 구현 명세:
    - `cli/fSnippetCli/Data/APIModels.swift`: `APIV2SnippetFolderRulePatch`에 `name: String?` 추가.
    - `cli/fSnippetCli/Managers/APIRouter.swift`: `handleV2PatchSnippetFolder`에 rename 분기 추가 (빈 이름/`/`·`..` 포함/중복 이름 검증 포함, 400/409 반환).
    - `api/openapi_v2.yaml`: `SnippetFolderRulePatch` 스키마에 `name` 추가, PATCH 엔드포인트 설명·404/409 응답 갱신.
* 페어 이슈: paidApp `fSnippet#Issue957` — paidApp `SettingsManager.updateRule`이 로컬 stub(`EngineStubs.swift` 항상 `false` 반환) 대신 본 REST 확장을 사용하도록 함께 수정됨.
* 후속 수정 (`03a56ee`): 실사용 검증 중 `UNity` → `Unity` 같은 **대소문자 전용** rename이 409로 거부되는 회귀 발견. APFS/HFS+ case-insensitive 파일시스템에서 `fileExists(newName)`가 "같은 폴더"를 "이미 존재하는 다른 폴더"로 오탐. `SnippetRepository.renameFolder`에 대소문자 전용 rename 감지 + 임시 이름 경유 2단계 rename 추가, `APIRouter`의 사전 중복 검사도 동일 케이스 통과하도록 수정. 임시 폴더로 재현·검증(`CaseTest957`→`Casetest957`, `ls -la`로 디스크 대소문자 변경 확인).

## Issue189: [Bug] Interactive View(Preview) Cmd+S 가 스니펫 등록 대신 설정창 오픈 — Issue188 후속 (등록: 2026-07-12) (✅ 완료, d5d1df7) ✅
* depends: Issue188
* 목적: 클립보드 히스토리 Preview 창(Interactive View)에서 Cmd+S 를 누르면 paidApp 새 스니펫 창이 열려야 하나, 실제로는 paidApp 일반 설정창이 열림. Issue188 에서 리스트 모드 경로는 `registerAndEditAsSnippet` 으로 통일했으나 Preview Window 경로가 누락됨.
* 상세 (코드 조사 결과):
    - Issue188 수정(`HistoryViewer.handleKeyEvent` 통일 처리)의 monitor 는 `isPreviewWindow(event.window)` 이면 pass-through(`HistoryViewer.swift` L170-173) + `isHistoryWindow` strict guard 로 Preview Window 이벤트가 `handleKeyEvent()` 에 도달하지 못함 — "Now handled uniformly here regardless of chvMode" 주석이 Preview Window 케이스에는 미적용.
    - 대신 Preview Window 자체 로컬 monitor(`HistoryPreviewView.swift` L200-211)의 구버전 하드코딩 분기(keyCode 1 + Cmd, `.previewView`)가 이벤트를 consume 하고 `PaidAppManager.handlePaidFeature()` 호출 — 이 함수는 범용 paid 게이트로 모든 분기가 `openSettings()` 로 종결(설정창).
    - 올바른 함수는 Issue188 에서 재배선된 `HistoryViewModel.registerAndEditAsSnippet(item:)` → `PaidAppManager.handleNewSnippet(keyword:)` (이미지면 `saveImageLocally`).
* 구현 명세:
    - `HistoryViewerManager` 에 forwarding 메서드 `registerItemAsSnippet(_:)` 추가 (private viewModel 로 위임: image → `saveImageLocally`, else → `registerAndEditAsSnippet` — 리스트 모드 분기와 동일 로직 재사용)
    - `HistoryPreviewView.swift` Cmd+S 분기에서 `handlePaidFeature()` 제거 → `HistoryViewerManager.shared.registerItemAsSnippet(state.currentItem ?? item)` 호출
    - Edit 모드(`PreviewTextView` CL045_10 Cmd+S = 텍스트 편집 저장)는 별개 기능이므로 변경 없음. Preview 상태바 하드코딩 힌트(⌘s)와 트리거 일치 유지 — 설정 hotkey 와의 통일은 범위 밖.
* 검증: Preview 창에서 Cmd+S → paidApp "새 스니펫" 창 오픈 확인 (2026-07-13 사용자 스크린샷). 후속 결함은 아래 서브 이슈로 분리하여 함께 종결.

### Issue189_1: [후속/Bug] 새 스니펫 창 자동 채움 실패 — 내용 미입력 + 키워드 비정상 (등록: 2026-07-13) (✅ 완료, b19f54c / paidApp fSnippet#Issue955 14549d1d) ✅
* 목적: Cmd+S 로 열린 paidApp "새 스니펫" 창에 선택한 클립보드 항목 텍스트가 **내용**으로 자동 입력되어야 하나 공란으로 열림. **키워드**도 `d998` 같은 비의도 값이 자동 입력됨.
* 상세 (재현):
    - 히스토리에서 텍스트 항목 "해야함"(3 chars) 선택 → Cmd+S → 새 스니펫 창: 저장 폴더 `Question_prompt_engineering`, 키워드 `d998`, 내용 공란 (2026-07-13 스크린샷).
    - 경로: `registerAndEditAsSnippet(item:)` → `PaidAppManager.handleNewSnippet(keyword:)` — 시그니처가 keyword 만 전달, 항목 content 전달 파라미터 부재 추정. `d998` 키워드의 생성 출처(자동 발번? 이전 상태 잔존?) 규명 필요.
* 구현 명세:
    - cliApp → paidApp 새 스니펫 요청에 content 포함 (URL scheme/REST 페이로드 확장 — paidApp 측 수신·프리필 처리 포함, 필요 시 paidApp fSnippet 레포 이슈 페어 등록)
    - 키워드 기본값 규칙 정의 (공란 시작 권장 또는 항목 기반 제안값) + `d998` 오염원 제거
    - 검증: 텍스트 항목 선택 → Cmd+S → 내용=항목 텍스트, 키워드=규칙값 확인
* 해결 (2026-07-13):
    - **`d998` 원인 확정**: `prepareSnippetData` 의 "suggestion+4hex해시" 자동 키워드("해야함d998")가 `PaidAppDetector.sanitizeKeyword` 의 ASCII 화이트리스트에 걸려 한글이 제거되고 해시(`d998`)만 잔존.
    - cliApp: `openNewSnippet(keyword:content:)` content 파라미터 추가(32KB UTF-8 clamp) + sanitize 를 프로토콜 정합 printable 필터(128B)로 완화 + 히스토리 등록 경로는 keyword 공란 전송(사용자 직접 입력). `handleNewSnippet`/`launchAndOpenNewSnippet` content 스레딩 (기본 nil — 팝업 Create 경로 무변경).
    - paidApp: URL Scheme `content` 수신·새 스니펫 창 내용 프리필 + `paid_cli_protocol.md` §1.2 갱신 — fSnippet#Issue955 (14549d1d) pm-do 위임 처리.
    - 검증: 내용="Hello\nWorld Test" 프리필 + 키워드 공란 확인 (2026-07-13 사용자 스크린샷).

### Issue189_2: [후속/UX] 리스트 모드 로우 포커스 상태에서도 Cmd+S 스니펫 등록 작동 (등록: 2026-07-13) (✅ 완료, 1cfaaf1) ✅
* 목적: Cmd+S 스니펫 등록이 현재 Preview(Interactive View) 모드에서만 작동. 리스트 뷰에서 로우에 포커스(선택)만 있어도 동일하게 작동해야 함.
* 상세:
    - 리스트 모드 상태바에 "⌘s: Save To Snippet (Paid Only)" 힌트가 노출되나 실제 미작동 (2026-07-13 스크린샷).
    - Issue188 이 리스트 모드 경로를 `HistoryViewer.handleKeyEvent` 로 통일했으나 현재 Cmd+S 이벤트가 해당 분기에 도달하지 않거나 분기 누락 추정 — monitor 도달 여부(`isHistoryWindow` guard·chvMode 분기) 조사 필요.
* 구현 명세:
    - 리스트 모드 keyDown 경로에서 Cmd+S → 선택 로우 item 으로 `registerItemAsSnippet(_:)` 라우팅 (Preview 와 동일 paid 게이트)
    - 검증: 리스트 로우 선택(프리뷰 off) → Cmd+S → 새 스니펫 창 오픈
* 해결 (2026-07-13):
    - **원인 확정**: 리스트 분기(`HistoryViewer.handleKeyEvent` 1번)가 설정 hotkey 만 매칭 — 사용자 환경 저장값 `history.registerSnippet.hotkey: "{⌥⌘f6}"` (기본값도 unset, Issue87) 이라 Cmd+S 무반응. Preview 창은 하드코딩 Cmd+S 라 작동 → "프리뷰에서만 작동" 증상.
    - 수정: 리스트 모드 Cmd+S 상시 허용(윈도우 로컬 monitor — 글로벌 충돌 없음) + 설정 hotkey 병행 매칭. `selectedId` nil(cmd-클릭 다중선택) 시 `selectedIds` 폴백(Enter 분기 미러) + 무선택 logD.
    - 검증: 빌드·brew 재배포 완료 (2026-07-13). 사용자 리스트 모드 재확인 대기 — 미작동 시 재오픈.

## Issue188: [Bug] "스니펫으로 등록" 기능 미작동 — cliApp 에디터 stub + 단축키 오배선 (등록: 2026-07-11) (✅ 완료, fab09b4 / paidApp fSnippet#b775cd4a) ✅
* 목적: 클립보드 히스토리에서 "스니펫으로 등록"이 우클릭 메뉴·커스텀 단축키 양쪽 모두 실제로는 아무 것도 저장하지 않는 것으로 확인됨. 근본 원인 규명 및 정상 경로(paidApp New Snippet 창)로 재배선.
* 상세 (코드 조사 결과):
    - **우클릭 메뉴 경로**: `HistoryViewModel.registerAndEditAsSnippet(item:)` → `SnippetEditorWindowManager.shared.showNewEditor(...)` 호출. 그러나 cliApp 의 `SnippetEditorWindowManager` 는 "스니펫 편집 GUI는 fSnippet 메인 앱에서 제공됨" 로그만 남기는 **완전한 no-op stub** (`Managers/SnippetEditorWindowManager.swift`). 창도 안 뜨고 파일도 안 생김 — 에러도 없이 조용히 실패.
    - **단축키 경로**: `HistoryViewer.handleKeyEvent()` 에서 `.list` 모드일 때만 `PaidAppManager.shared.handlePaidFeature()` 호출 — 이는 범용 "유료 기능 안내" 함수로 paidApp 의 **일반 설정 창**을 열 뿐, 스니펫 등록과 무관. `.previewView`/`.previewEdit` 모드에서는 이벤트가 자식 뷰로 넘어가는데, 그 자식 뷰들(`HistoryPreviewView`, `PreviewTextView`)의 하드코딩된 Cmd+S 처리는 **전혀 다른 기능**(각각: 유료 게이트 안내 / 편집 중인 텍스트를 클립보드 DB에 저장)이라 등록 함수(`registerAndEditAsSnippet`)를 아예 호출하지 않음.
    - **올바른 기존 인프라 존재 확인**: `PaidAppManager.handleNewSnippet(keyword:)` (Issue157) 가 이미 paidApp 의 새 스니펫 창을 keyword 프리필로 여는 정확한 paid-gated 함수로 존재 (`Create` 버튼이 사용 중). 이번 버그는 히스토리 쪽 두 경로가 이 함수를 쓰지 않고 각각 stub/오배선 함수를 호출한 것.
    - **알려진 한계 (후속 과제, 이번 수정 범위 밖)**: `PaidAppDetector.openNewSnippet(keyword:)` URL Scheme 은 keyword 만 전달하고 클립보드 본문(content) prefill 은 지원 안 함 — "Create" 버튼과 동일한 기존 제약이라 이번 수정에서 확장하지 않음.
* 구현 (`fab09b4`, paidApp `b775cd4a`):
    - `cli/fSnippetCli/UI/History/HistoryViewModel.swift` `registerAndEditAsSnippet(item:)` — `SnippetEditorWindowManager` stub 호출 제거, `PaidAppManager.shared.handleNewSnippet(keyword:)` 호출로 교체
    - `cli/fSnippetCli/UI/History/HistoryViewer.swift` `handleKeyEvent()` 1번 분기 — `.list` 전용 `handlePaidFeature()` 대신 모든 chvMode 에서 선택 항목 조회 후 이미지면 `saveImageLocally`, 아니면 `registerAndEditAsSnippet` 호출하도록 통일 (우클릭 메뉴와 동일 함수 재사용)
    - paidApp `Views/Settings/HistorySettingsView.swift` — "스니펫으로 등록" 필드 옆 물음표 아이콘 + `.help()` 툴팁 추가: "비어 있으면 단축키가 비활성화됩니다. 등록 시 fSnippet(유료 앱)의 새 스니펫 창이 열립니다." (10개 로케일 `Settings.strings` 동시 반영 — en/ko/ja/zh-Hans/zh-Hant/es/fr/de/ar/hi)
    - **원 요청과 다른 지점**: 사용자는 "Cmd+S가 기본값" 문구를 요청했으나, 실제로는 Issue87(과거)에서 macOS 표준 저장 단축키 충돌 때문에 기본값을 의도적으로 빈 문자열로 바꾼 상태 — 이 설계 결정과 모순되므로 "Cmd+S 기본값" 문구 대신 "빈 값 = 비활성화" 로 정확하게 안내
* 검증 (2026-07-11): paidApp Debug 빌드 성공, cliApp Release brew local 배포 9/9 PASS, REST API 헬스체크 정상, 두 앱 프로세스 실행 확인.

## Issue187: 히스토리 뷰어에 미리보기 토글 UI 버튼 추가 (등록: 2026-07-11) (✅ 완료, fab09b4) ✅
* 목적: 설정 > 히스토리 화면의 "미리보기 토글" 단축키 필드는 정상 작동하지만, 클립보드 히스토리 창 자체에는 마우스로 미리보기 패널을 켜고 끌 수 있는 UI가 없음. 단축키 미설정 사용자를 위해 클릭 가능한 토글 버튼 추가.
* 상세:
    - 대상: `cli/fSnippetCli/UI/History/HistoryViewer.swift` footerView (Pause Toggle 버튼 옆)
    - 단축키 로직(`historyPreviewHotkey`, `TriggerKeyManager` 매칭)은 변경하지 않음 — UI 버튼만 추가, 기존 `HistoryPreviewManager.shared.togglePreview(with:)` 재사용
* 구현 (`fab09b4`):
    - `HistoryViewer.swift` footerView 에 `settings.historyShowPreview` 상태에 따라 `◀`/`▶` 표시하는 Button 추가, 클릭 시 현재 선택 항목으로 `togglePreview(with:)` 호출
    - `LocalizedStringManager.swift` en/ko/ja 3개 로케일에 `viewer.help.toggle_preview` 툴팁 키 추가
* 검증 (2026-07-11): cliApp Release brew local 배포 9/9 PASS, 앱 실행 확인.

### Issue187_1: [후속] 미리보기 토글 버튼 위치 이동 (등록: 2026-07-11) (✅ 완료, 717efe8) ✅
* 목적: Issue187 로 추가된 미리보기 토글 버튼(하단 좌측 `◀`/`▶`)의 발견성이 낮음. 더 적절한 위치로 이동.
* 결정 (2026-07-12, hub 폼 회수): 이동 목표 = **상단 검색바 우측(필터 아이콘 옆)**. 상태바 숨김(`historyShowStatusBar=false`)과 무관하게 항상 보이고, 스크린샷 화살표 의도(우상단)에 부합.
* 구현 (`717efe8`):
    - `cli/fSnippetCli/UI/History/HistorySearchBar.swift` — 필터 Menu 옆에 `sidebar.right` SF Symbol 토글 버튼 추가. `previewShown: Bool` + `onTogglePreview: () -> Void` 파라미터 신설. `previewShown` 시 accentColor, 아니면 secondary.
    - `cli/fSnippetCli/UI/History/HistoryViewer.swift` — footerView 좌측 기존 미리보기 토글 버튼 제거, `HistorySearchBar(...)` 호출부에 `previewShown: settings.historyShowPreview` + `onTogglePreview`(선택 항목 조회 후 `HistoryPreviewManager.shared.togglePreview(with:)`) 전달.
* 검증 (2026-07-12): cliApp Release brew local 배포 9/9 PASS, REST API 헬스체크 정상, 앱 실행 확인.

### Issue187_2: [후속] 미리보기 토글 버튼 풍선 도움말 다국어 (등록: 2026-07-11) (✅ 완료, 717efe8) ✅
* 목적: 토글 버튼에 hover 풍선 도움말(툴팁)을 붙이고 다국어로 표시.
* 조사 정정: 등록 시 "10개 로케일 / 나머지 7개 확장"은 paidApp `Settings.strings` 기준 오판단. **cliApp `LocalizedStringManager` 는 en/ko/ja 3개 로케일만 지원**하며, `viewer.help.toggle_preview` 키가 이미 3개 모두에 존재(Issue187). 즉 다국어 풍선 자체는 Issue187 에서 이미 구현됨.
* 구현 (`717efe8`):
    - Issue187_1 로 버튼을 상단으로 이관하면서 툴팁을 함께 이전 — `.instantTooltip(L10n("viewer.help.toggle_preview"))` (딜레이 없는 커스텀 풍선, `InstantTooltipModifier`) 유지.
    - 접근성/네이티브 툴팁 보강: `.help(L10n("viewer.help.toggle_preview"))` 추가 부착. 둘 다 en/ko/ja i18n.
* 검증 (2026-07-12): 위 187_1 검증에 포함(동일 빌드·배포).

## Issue186: GET /api/v2/folders에서 빈 폴더(스니펫 0개) 누락 — paidApp New Snippet Storage Folder 선택 불가 원인 (등록: 2026-07-09) (✅ 완료, 78b9a31) ✅
* depends: prj15#Issue951
* 목적: paidApp에서 새 폴더 생성 직후 New Snippet 창의 Storage Folder 드롭다운이 빈 값으로 뜨는 문제(fSnippet 레포 Issue951)의 근본 원인. `handleGetFolders()`가 스니펫 인덱스 기반으로만 폴더 목록을 구성해, 스니펫이 하나도 없는 폴더는 생성 주체(paidApp/cliApp)와 무관하게 항상 목록에서 누락됨.
* 상세:
    - 원인: `APIRouter.handleGetFolders()` 가 `SnippetIndexManager.shared.entries`를 `folderName`으로 그룹핑해 `folderMap`을 만듦. 스니펫이 0개인 폴더는 `entries`에 아예 나타나지 않으므로 `folderMap`에 키가 생기지 않아 응답 `data`에서 누락됨.
    - `handleCreateFolder()` 자체는 폴더 생성 후 `SnippetFileManager.shared.loadAllSnippets(force: true)`로 인덱스를 동기 리로드하지만, 빈 폴더는 애초에 인덱스할 스니펫이 없으므로 리로드해도 여전히 `folderMap`에 반영 안 됨 — REST 경유/직접 fs 접근 여부와 무관한 구조적 결함.
* 구현 (`78b9a31`):
    - 파일: `cli/fSnippetCli/Managers/APIRouter.swift` `handleGetFolders()`.
    - `SnippetFileManager.shared.getSnippetFolders()`(디스크 실제 하위 디렉토리 스캔)로 얻은 폴더명 목록(`lastPathComponent`)을 인덱스 기반 `folderMap`과 union — `folderMap[name] == nil`인 디스크 폴더를 빈 배열로 추가. 빈 폴더는 `snippetCount:0`·`icon` 생략으로 정상 노출.
* 검증 (2026-07-09, Release brew local 9/9 PASS 배포 후 curl):
    - `POST /api/v2/folders {"name":"Issue186VerifyFolder"}` → 즉시 `GET /api/v2/folders` 응답 포함(`snippet_count:0`) 확인 → `DELETE .../Issue186VerifyFolder?force=true` 정리.

## Issue185: [Popup] 스니펫 팝업창에서 마침표(.) 입력 시 팝업이 닫힘 (등록: 2026-07-09) (✅ 완료, 3e68f26) ✅
* 목적: 팝업 검색 필터 입력 중 `.` 을 치면 팝업이 닫혀 필터링이 끊김. `.` 을 필터 문자로 취급하도록 수정.
* 상세:
    - 원인: `KeyEventHandler.handleKeyInPopupMode` 가 `AppSettingManager.bufferClearKeys` (= `\r \n \t space .`) 에 포함된 문자를 팝업 close 트리거로 사용. `.` 이 포함되어 팝업이 닫힘.
    - 팝업에는 `SnippetPopupView.searchText` 필터가 있어 타이핑이 목록 필터링에 쓰임 — `.` 도 필터 문자여야 자연스러움.
    - normal mode 의 `.` buffer clear(abbreviation 감지 리셋)는 유지해야 함(부작용 방지).
* 구현 명세:
    - `KeyEventHandler.handleKeyInPopupMode` 의 clear-key 판정에서 `.` 만 예외 처리(팝업 모드 한정) → normal mode 는 무변경.
    - 파일: `cli/fSnippetCli/Core/KeyEventHandler.swift`
* 검증: Release brew 배포 (9 PASS / 0 FAIL) + 사용자 수동 확인 (팝업서 `.` 입력 시 유지).

## Issue184: [Settings] snippet_popup_quick_select_modifier_flags 적용 후 원복 — general 엔드포인트가 고아 키 quick_select_modifier 만 read/write (등록: 2026-07-07) (✅ 완료, ba6521c) ✅
* depends: Issue182
* 목적: paidApp GUI 에서 quick-select modifier 변경이 적용되었다가 원복되는 문제 수정. Issue182 가 저장 포맷(토큰)은 고쳤으나 "고아 키 desync" 는 범위 밖으로 미뤄둠 — 그 desync 가 원복의 실제 원인.
* 상세:
    - 같은 설정에 config 키 2개 공존:
        - 런타임 SSOT `snippet_popup_quick_select_modifier_flags` (토큰 `{command}`) — 런타임(HistoryViewer·PopupKeyboardHandler)·`SettingsManager.load/save`·REST v2 popup 엔드포인트(`buildV2Popup`·`handleV2PatchPopup`) 소비.
        - 고아 키 `quick_select_modifier` (String) — REST v2 general 엔드포인트만 read/write(`buildV2General` L864, `handleV2PatchGeneral` L2479, 별도 sub `handleV2GetGeneralQuickSelectModifier` L2580 / `handleV2PutGeneralQuickSelectModifier` L2594). **런타임 무영향**.
    - paidApp GUI 가 general 엔드포인트로 저장 → 고아 키만 갱신 → 런타임/popup/SettingsManager 는 옛 flags 키 그대로 → 새로고침·재기동 시 옛 값으로 원복.
* 구현 명세:
    - `QuickSelectModifierCodec` 에 `name(fromFlags:) -> String`("command"/"control"/"shift") 추가. `flags(fromToken:)` 는 이미 bare name("command") 처리하므로 String→flags 재사용.
    - general 4곳을 SSOT 키로 통일: 읽기 = 토큰→flags→name, 쓰기 = name→flags→토큰. 고아 키 `quick_select_modifier` 접근 전면 제거.
    - `ConfigMigration.obsoleteConfigKeys` 에 `quick_select_modifier` 추가 → 부팅 시 자동 제거(idempotent, 백업 불요 — SSOT 토큰 키에서 항상 재파생).
    - REST v2 contract(`quickSelectModifier` String enum) 시그니처 불변 — 내부 저장 키만 통일이라 openapi_v2.yaml 스키마 변경 불요.
* 구현 (`ba6521c`):
    - `QuickSelectModifierCodec.name(fromFlags:)` 신설(SettingsManager.swift) — Int flags → bare name.
    - `APIRouter.readQuickSelectModifierName(_:)` / `quickSelectToken(fromName:)` 헬퍼 신설. general 4곳(`buildV2General`·`handleV2PatchGeneral`·`handleV2GetGeneralQuickSelectModifier`·`handleV2PutGeneralQuickSelectModifier`) 을 SSOT 키 read/write 로 교체. 고아 키 `quick_select_modifier` 코드 접근 0건.
    - `ConfigMigration.obsoleteConfigKeys += "quick_select_modifier"` — 부팅 자동 제거.
* 검증 (2026-07-07, brew local 9/9 PASS 배포 후 curl):
    - PATCH general `control` → config `snippet_popup_quick_select_modifier_flags: "{control}"`, GET general `control` (**원복 없음**).
    - 크로스 엔드포인트 일관: general `control` ↔ popup `popupQuickSelectModifierFlags: 262144` ↔ sub-endpoint `control` ↔ config `{control}` — 전부 동일 SSOT.
    - `command` round-trip 정상. 번들 템플릿 `_config.yml` 은 SSOT 키만 시드(고아 키 없음).
* 진단 후속 (2026-07-07, 로그 추적): 사용자 원복 재현 시 cliApp write 로그 **0줄** — paidApp GUI 가 quick-select 변경을 cliApp 에 **전송 자체를 안 함(제로 호출)**. 직접 curl PATCH 는 정상 write·정착(APIRouter 로그 발화 확인). ∴ 원복은 cliApp SSOT desync(본 이슈, 수정 완료)가 아니라 **paidApp 저장 배선 결함**. 이중 호출도 cliApp 자체 원복도 아님. → **후속 paidApp(prj15) 이슈로 분리** 필요.
    - 진단 로그(`[Issue184]` 태그 write 4곳 + load 1곳)는 관측용으로 보존 (커밋 별도). paidApp 수정 후 write 도달 검증에 재사용.
    - paidApp 후속: fSnippet(prj15) `Issue947`로 분리·완료(hash `33289694`) — `applyRemoteSettings()` Issue889 동기화 목록에 `popupQuickSelectModifierFlags` 누락. 본 이슈와는 별개 근본원인.

### Issue184_2: cliApp 자체 SettingsObservableObject 도 동일 stale-revert 클래스 재발 (등록: 2026-07-07) (✅ 완료, f531ba3) ✅
* depends: Issue184
* 목적: Issue184 본체(고아 키 통일) 수정 후에도 원복이 재현됨 — cliApp History/설정창용 `SettingsObservableObject`(`Managers/SettingsManager.swift`와 별개 인스턴스)의 `saveUISettings()` 저장 직전 리싱크 목록에 `popupQuickSelectModifierFlags`가 빠져 있어 발생한 잔존 결함.
* 상세: 이 객체는 앱 시작 시 1회만 `popupQuickSelectModifierFlags`를 디스크 값으로 로드하고(`loadUISettings()`), 이후 갱신되지 않음. Issue941(hotkey)·Issue178(triggerKey)에서는 저장 직전 최신 config로 재동기화하는 방어 코드를 이미 추가했으나, quick-select 필드는 그 목록에서 누락되어 있었음. 그 결과 cliApp 자신의 History/설정창에서 다른 아무 설정(예: autoStart, language)을 저장하기만 해도 stale 값이 SSOT 키를 덮어씀.
* 구현 명세: `_public/cli/fSnippetCli/Data/SettingsObservableObject.swift`의 `saveUISettings()` 리싱크 블록(Issue941/178 패턴 바로 다음)에 `snippet_popup_quick_select_modifier_flags` 재동기화 항목 추가.
* 검증: brew local 9/9 PASS 배포 후 `_config.yml`·REST 양쪽 값 유지 확인.

### Issue184_3: cliApp 종료 직전 _config.yml 비동기 쓰기 유실 레이스 (등록: 2026-07-09) (✅ 완료, 4984401) ✅
* depends: Issue184_2
* 목적: Issue184_2 수정 후에도 원복이 재현됨(main 레포 fSnippet#Issue949 참조). paidApp이 설정 PATCH 전송 직후 재시작을 트리거하면 cliApp이 100ms 뒤 강제 종료되는데, PATCH의 실제 디스크 쓰기가 비동기라 그 창을 놓치면 값이 파일에 한 번도 기록되지 않은 채 프로세스가 죽는 레이스 수정.
* 상세: `PreferencesManager.set()`/`batchUpdate()`는 `textQueue`(concurrent, barrier)에 비동기로 `saveConfigInternal()`을 큐잉하고 HTTP 응답은 그 완료를 기다리지 않고 즉시 반환됨. paidApp의 `saveDraft()` → `needsRelaunch` → `shutdown()` 흐름은 PATCH 전송 후 그 디스크 쓰기 완료를 기다리지 않고 곧바로 cliApp에 `/api/v2/shutdown`(delayMs=0)을 보내고, cliApp은 100ms 뒤 `terminate(nil)`을 실행함. `applicationWillTerminate`에는 Logger용 `flush()`는 있었지만 `PreferencesManager` 쪽 동등한 flush가 없어, 대기 중인 barrier 쓰기가 끝나기 전에 프로세스가 죽을 수 있었음.
* 구현 명세: `PreferencesManager`에 `flush()`(빈 barrier 블록으로 대기 중인 쓰기 완료 보장) 신설 + `fSnippetCliApp.applicationWillTerminate`에서 `logger.flush()`와 함께 호출.
* 검증: curl로 PATCH 직후 즉시 `/api/v2/shutdown`(delayMs=0) 발사 → cliApp 재기동 후 값 정상 유지 확인(수정 전 재현, 수정 후 미재현).

### Issue184_4: popupRows/searchScope/width/previewWidth도 동일 stale-mirror 재발 (등록: 2026-07-09) (✅ 완료, 2e15877) ✅
* depends: Issue184_2
* 목적: Issue184_2(quick-select)·Issue184_3(종료 레이스) 수정 후에도 "Popup Settings" 쪽 다른 필드(특히 popupRows: 9→5 변경이 곧바로 9로 원복)가 재현됨(main 레포 fSnippet#Issue949 사용자 재현). quick-select만 리싱크되고 나머지 popup 필드는 동일 결함이 남아있던 것.
* 상세: 트리거 경로는 종료 레이스(Issue184_3)와 무관하게 앱이 계속 켜져 있는 중에도 발생 가능 — paidApp이 설정 Apply 시 보내는 history PATCH가 `handleV2PatchHistory`(`APIRouter.swift:2876-2882`, Issue900)에서 `obs.historyShowStatusBar`/`historyShowPreview`/`historyImageDetailIsFloating`을 cliApp 자신의 `SettingsObservableObject`에 직접 대입 → `syncHistorySetting()` → `debouncedSave()`(0.5s 지연) → `saveUISettings()` 재호출. 이때 `popupRows`/`popupSearchScope`/`popupWidth`/`popupPreviewWidth`는 launch-time 로드 값 그대로 남아있어, 0.5s 전에 별도 popup PATCH로 막 반영된 값을 스스로 덮어씀.
* 구현 명세: `saveUISettings()`의 quick-select 리싱크 블록 바로 다음에 `snippet_popup_rows`/`snippet_popup_search_scope`/`snippet_popup_width`/`snippet_popup_preview_width` 4개 항목 리싱크 추가(동일 패턴).
* 검증: curl로 popup PATCH(rows: 9→9로 세팅) 직후 history PATCH(다른 필드 토글, Issue900 경로 강제 발동) → 0.5s 대기 → popupRows 값 유지 확인(수정 전 이 경로로 원복 가능, 수정 후 미재현).

## Issue183: [Settings] snippet_popup_hotkey 문자열 단일 SSOT 화 — key_code/modifier_flags 파일 저장 제거 (등록: 2026-07-06) (✅ 완료, ea3eb83) ✅
* 목적: `_config.yml` 팝업 단축키가 `snippet_popup_hotkey`(문자열) + `snippet_popup_key_code` + `snippet_popup_modifier_flags` 3키로 중복 저장됨. 정수 2키는 사람이 직접 편집 불가(raw `NSEvent.ModifierFlags` — device-dependent 비트 노이즈 포함, 현재 값 393475 = ⌃⇧ 393216 + 노이즈 259)하고, 3키 수동 동기화가 불일치 버그 원천(Issue172·173·175·176·178 계열). 문자열 1키만 SSOT로 남기고 flags/code는 로드 시 파생.
* task: `cli/_doc_work/tasks/popup-hotkey-single-ssot_task.md`
* 상세:
    - `PopupKeyShortcut.from(hotkeyString:)`([SettingsManager.swift:31]) 파서 이미 존재 — `⌃⌥⌘⇧⇪` 심볼·중괄호·`reverseKeyMap` 특수키 처리. 문자열 → flags/code 파생 가능
    - Gap 1 (좌/우 modifier 비대칭): `toHotkeyString`은 오른쪽 modifier 시 `right_command+…` verbose 출력(L95-119)하나 `from()`은 심볼만 역파싱. 팝업 핫키는 좌/우 미구분 정책으로 단순화(트리거키와 달리 구분 실익 없음)
    - Gap 2 (REST v2 계약): `openapi_v2.yaml` L2174-2186 `popupModifierFlags`/`popupKeyCode` 노출 중 → deprecated 처리(요청 시 무시, 응답은 파생값 유지로 하위호환)
    - Swift 사용처 18개소: `ShortcutMgr.swift:449`, `APIRouter.swift:870/908/1094-1105`, `SettingsManager.swift:401/455/1164`, `SettingsObservableObject.swift:674/929`, `PreferencesManager.swift:562`
* 구현 명세 (완료, ea3eb83):
    - **로드**: `SettingsManager.load` — `snippet_popup_hotkey` 문자열만 읽고 `PopupKeyShortcut.from(hotkeyString:)` 파생. 정수 2키 read 제거
    - **저장**: `SettingsManager.save` — displayString만 YAML 기록. `APIRouter.handleV2PatchPopup` — 정수 2키 config 쓰기 제거
    - **마이그레이션**: `ConfigMigration.removeObsoleteConfigKeys` 신설 (idempotent, 백업 불요 — 문자열에서 항상 재파생 가능) + `PreferencesManager` 부팅 훅 연결
    - **REST v2**: PATCH의 flags/keyCode는 canonical 문자열 조립용 transient 입력으로만 사용(파일 미기록). GET 2곳(`buildV2General`/`buildV2Popup`)은 문자열 파싱 파생값 반환 — 계약 하위호환 유지. `openapi_v2.yaml` 두 필드 deprecated 표기
    - **기본값**: `PreferencesManager` defaults dict + 번들 `_config.yml` 템플릿에서 정수 2키 제거
    - **부수 정리**: `SettingsObservableObject.saveUISettings` stale-revert resync(Issue941)도 문자열 파싱 파생으로 교체
    - **검증 결과**: BUILD SUCCEEDED → brew local 9 PASS 배포 → 부팅 로그에 `Issue183 obsolete key removed` 2건 + `_config.yml`에서 정수 2키 소멸 확인. GET flags 393216(장치 노이즈 259 제거된 clean 값). PATCH ⌘Space→⌃⇧Space round-trip 시 `"{⌘Space}"`/`"{⌃⇧Space}"` 문자열만 갱신·정수 키 재출현 없음. App Shortcuts 4개 정상 등록. (팝업 실제 키 입력 호출은 미검증 — 등록·REST 레벨 검증까지 완료)

## Issue182: [Settings] snippet_popup_quick_select_modifier_flags 저장 포맷 사람이 편집 어려움 — raw 정수 → {command}/{control} 토큰 (등록: 2026-07-06) (✅ 완료, 4a526c1) ✅
* 목적: `_config.yml` 의 `snippet_popup_quick_select_modifier_flags` 가 raw `NSEvent.ModifierFlags` 정수(262144 등)로 저장되어 사용자가 손으로 편집 불가. 다른 토큰(트리거키 `{right_command}`, hotkey `{^⌘⇧;}`)처럼 브레이스 토큰 `{command}`/`{control}` 로 저장되게 변경.
* 상세:
    - 런타임 SSOT는 이 Int 키 하나(`HistoryViewer`·`PopupKeyboardHandler`·`PopupKeyboardModifier` 가 `.contains(.command/.control/...)` 로 소비). 별도 `quick_select_modifier`(String) 키는 v2 REST 에만 존재하는 **고아 키** — 런타임 무영향(desync, 본 이슈 범위 밖·미수정).
    - 저장 포맷만 문제이므로 런타임 Int·REST Int 계약은 유지하고 config 경계에서만 변환.
* 구현 (`4a526c1`):
    - `QuickSelectModifierCodec`(SettingsManager.swift) 신설 — `token(fromFlags:)` Int→`{command}`/`{control}`/`{shift}`, `flags(fromToken:)` 토큰/레거시Int문자열→Int. Issue742(option deprecated) normalize 를 읽기·쓰기 양쪽 적용 → config 에 `{option}` 미저장.
    - 변환 적용 4곳: `SettingsManager.load`(토큰 우선, 레거시 Int fallback), `SettingsManager.save`(토큰 기록), `APIRouter.buildV2Popup`(토큰→Int), `APIRouter.handleV2PatchPopup`(Int→토큰).
    - 레거시 Int 값은 읽기 시 그대로 수용, 다음 저장 시 토큰으로 self-heal.
* 검증 (2026-07-06, brew local 9/9 PASS ×2 배포 후 curl):
    - 레거시 `262144` → GET `262144` 정상 read
    - PATCH command(1048576) → config `"{command}"`, PATCH control(262144) → `"{control}"`, PATCH option(524288) → `"{command}"`(normalize)
    - GET 은 항상 Int 반환(REST 계약 불변), option 저장분도 `1048576`(command)로 정규화 read

## Issue181: [Lifecycle] 트리거키 변경 재시작 경로 안전화 — cliApp 자기재실행 제거 + paidapp-relaunch 역방향 종료 스킵 (등록: 2026-07-06) (✅ 완료, 766c9cb) ✅
* depends: Issue179
* 목적: 트리거키 변경 후 재시작 흐름에서 cliApp·paidApp이 모두 죽거나(자기재실행 경합), 새로 뜬 paidApp이 사살되어(역방향 종료 신호) "종료만 되고 재시작 안 됨"이 되는 두 가지 프로세스 라이프사이클 결함 수정.
* 상세:
    - 결함 A (자기재실행 경합): Issue38의 "재시작" 버튼이 cliApp 자신을 `NSWorkspace.openApplication`으로 재실행 — 옛 인스턴스가 아직 살아있는 상태라 `SingleInstanceGuard`(non-launchd 패자 규칙)가 새 인스턴스를 즉시 자폭시키고, "실행 성공"으로 오인한 옛 인스턴스도 스스로 종료 → cliApp 완전 사망.
    - 결함 B (역방향 사살): paidApp이 재시작 직전 `POST /api/v2/shutdown`으로 cliApp을 내리면, cliApp의 `applicationWillTerminate`가 Quit All 의도로 `terminatePaidApp()` 실행 → 그 시점에 이미 새로 뜬 paidApp 인스턴스를 사살 (flog 2026-07-06 17:33:21.372 옛 종료 → 17:33:21.556 새 인스턴스 종료).
* 구현 명세:
    - A: `SettingsObservableObject.saveAndUpdate()`의 Issue38 재시작 다이얼로그·자기재실행 블록 전체 제거 — 트리거키는 `TriggerKeyManager.updateDefaultTriggerKey()`로 이미 즉시 적용되므로 조용히 로그만 남김. 전체 재시작은 paidApp(Relauncher, 검증된 경로)이 오케스트레이션 (paidApp 메인 레포 연동 변경: `needsRelaunch()`에 defaultSymbol 추가 + `shutdown(reason:"paidapp-relaunch")` 전송).
    - B: `APIRouter.handleShutdown`이 `reason == "paidapp-relaunch"`면 `AppDelegate.skipPaidAppTerminationOnExit = true` 설정 → `applicationWillTerminate`에서 `terminatePaidApp()` 스킵.
    - 검증: 트리거키 변경 + Apply → cliApp 조용히 종료 → paidApp 재시작 → 새 paidApp이 Issue847 autoStartCliService로 cliApp 재기동 — 사용자 E2E 확인 완료 (2026-07-06).

## Issue179: [Settings] debouncedSave()의 saveAndUpdate() 중복 호출 — 트리거키 변경 시 "재시작 필요" 다이얼로그 2회 표시 (등록: 2026-07-06) (✅ 완료, 766c9cb) ✅
* 목적: 트리거키 변경 한 번에 "앱 재시작 필요" 모달이 연속 2회 뜨는 문제 수정.
* 상세:
    - 원인: `SettingsObservableObject.debouncedSave()`(Issue140)가 `saveUISettings()` 호출 직후 `settingsManager.saveAndUpdate(settings)`를 한 번 더 직접 호출 — `saveUISettings()`는 자기 끝에서 이미 `saveAndUpdate()`를 호출하므로 완전 중복.
    - `saveAndUpdate()`는 `load()`(직전 값) vs `settings`(새 값) diff로 재시작 다이얼로그를 띄우는데, `PreferencesManager` 쓰기가 비동기(barrier)라 두 번째 호출 시점에도 `load()`가 옛값을 반환 → 같은 변경에 다이얼로그 2회 예약.
* 구현 명세:
    - `debouncedSave()`의 중복 `saveAndUpdate()` 직접 호출 삭제 — `saveUISettings()` 단일 경로로 통일.

## Issue177: [MenuBar] 단축키 변경 후 메뉴바 keyEquivalent 미갱신 — shortcut 변경 시 메뉴 재생성 필요 (등록: 2026-07-05) (✅ 완료, 6a5fefe) ✅
* 목적: paidApp Apply → `PUT /api/v2/settings/shortcuts/{name}` 로 hotkey 변경 시 `ShortcutMgr.refreshAll()` 은 호출되어 런타임 단축키는 재등록되지만, 메뉴바 메뉴는 앱 시작 시 1회 + pause 상태 변경 시에만 재생성되어 **옛 단축키 표기가 그대로 남음** (재시작 전까지 stale).
* 구현 (`6a5fefe`) — 등록 시 명세(MenuBarManager 재생성)와 달리 실제 메뉴는 SwiftUI `MenuBarExtra { MenuBarView() }` 이고 `MenuBarManager.createMenuBarMenu()` 는 데드 코드(statusItem 미생성)였음. 진짜 원인은 `MenuBarView` 의 **하드코딩 keyboardShortcut 4곳**:
    - `MenuBarView` 하드코딩 4곳(popup/viewer/pause/settings)을 `storedShortcut(prefKey:fallback:)` — PreferencesManager 저장 토큰 기반 동적 계산으로 교체 (빈 값은 기존 하드코딩 fallback, 단일 문자로 표현 불가 토큰은 표기 생략)
    - `MenuShortcutRefresher`(ObservableObject) 신설 — `.shortcutsChanged` notification 수신 시 version bump → SwiftUI 재렌더
    - `APIRouter` `handleV2PutShortcut`/`handleV2DeleteShortcut` + `handleV2PatchPopup`(hotkey 변경 시)에 `.shortcutsChanged` post 추가
    - 부수 수정: `PopupKeyShortcut.from(hotkeyString:)` 이 canonical display 의 `⌃`(U+2303)를 control 로 파싱하지 않고 유실하던 버그 수정 (Issue173 canonical 포맷 `{⌃⇧Space}` 가 `⇧Space` 로 표기되던 원인; ShortcutMgr L456 동일 함수 사용 — 잠재 등록 버그도 함께 해소)
* 검증 (2026-07-05, brew local 9/9 PASS ×2 배포 후 AX 조회):
    - 런치 후 메뉴: popup `⌃⇧Space`(mods=13, ⌃ 파싱 수정 전 mods=9), settings `⌃⌥⌘;`(mods=6) — 저장 토큰 정상 반영
    - **라이브 갱신**: 실행 중 `PUT settingsHotkey {^⌘⇧;}` → 재시작 없이 즉시 mods=6→5 (`⌃⌥⌘;`→`⌃⇧⌘;`) 갱신 확인

## Issue178: [Settings] snippet_trigger_key REST 변경이 saveUISettings()에 의해 원복됨 — Issue941 stale-revert 패턴 재발 (등록: 2026-07-05) (✅ 완료, 46b1ef1) ✅
* 목적: paidApp 일반설정 탭 또는 REST(`PATCH /api/v2/settings/general`, `PUT /api/v2/settings/general/trigger-key`)로 트리거 키를 변경해도, 짧게는 2초 길게는 90초 뒤 트리거 무관한 다른 설정이 저장되는 순간 자동으로 옛 값(주로 `{right_command}`)으로 원복되는 버그 수정.
* 상세:
    - 근본원인: `SettingsObservableObject.saveUISettings()` — REST 경로는 `PreferencesManager` 직접 기록 + `TriggerKeyManager.reloadSettings()` 만 호출, `triggerKeyShortcut`(@Published UI 미러)는 런치 시점 값에 고정(stale). 무관 설정 저장 시 stale 미러가 `settings.defaultSymbol` 을 거쳐 `_config.yml` 을 덮어씀.
    - 동일 버그 클래스: Issue941 리싱크 목록에서 `snippet_trigger_key`/`defaultSymbol` 누락으로 재발.
* 구현 (`46b1ef1`):
    - `saveUISettings()` 의 Issue941 hotkey 리싱크 블록 옆에 트리거 키 리싱크 추가: `prefs.get("snippet_trigger_key")` 최신 토큰 → `EnhancedTriggerKey.from(keySpec:)` → `PopupKeyShortcut` 변환(loadUISettings 와 동일 변환) 후 미러와 다르면 갱신
* 검증 (2026-07-05, brew local 9/9 PASS 배포 후 curl):
    - `PUT trigger-key {f1}` → `PATCH history`(debounced saveUISettings 유발) → flog "Saving Trigger Key to snippet_default_symbol: {f1}" — stale `{right_command}` 대신 fresh 값 저장, `_config.yml` 원복 없음
    - 역방향 `{right_command}` round-trip 정상 (modifier-only 토큰 54~62 keyCode 경로 유지)

## Issue173: [API] PATCH /api/v2/settings/popup — modifierFlags ↔ displayString 불일치 무검증 수용 (화면≠실제 단축키) (등록: 2026-06-29) (✅ 완료, f381864) ✅
* depends: Issue174
* 목적: 팝업 단축키 PATCH 시 실제 동작을 결정하는 `popupModifierFlags`(정수)와 표시용 `popupDisplayString`이 어긋나도 서버가 그대로 수용함. 화면에는 한 단축키가 보이지만 실제로는 다른 키로 동작하는 함정. paidApp ShortcutRecorder는 세 값을 정합하여 보내므로 무해하나, 수동 curl·외부 클라이언트(MCP 등)는 쉽게 불일치를 만듦.
* 구현 (방안 A — 서버 SSOT, `f381864`):
    - `handleV2PatchPopup`: 클라이언트 `popupDisplayString` 입력 무시, 유효 `modifierFlags`+`keyCode`(patch값 우선, 없으면 현재값)에서 canonical display 생성 후 `snippet_popup_hotkey` 저장
    - `PopupKeyShortcut.canonicalDisplayString(modifierFlags:keyCode:)` + `keyName(for:)` 헬퍼 신설 (`TriggerKeyManager.reverseKeyMap` 역조회, 최단명·알파벳순 결정적 선택)
    - 검증 추가: `popupModifierFlags < 0` / `popupKeyCode ∉ 0...65535` → 400
    - 부수 수정: GET general `popupHotkey.modifiers` 빈 배열 → flags 정수에서 `control/option/shift/command` 직접 산출 (`v2ModifierNames(fromFlags:)`)
* 검증 (2026-07-05, brew local 9/9 PASS 배포 후 curl):
    - 불일치 PATCH(flags=⌃⌘ 1310720 + 거짓 display `⌥⌘Space`) → 응답·`_config.yml` 모두 `⌃⌘Space` 자동 교정 (braced 저장 `{⌃⌘Space}` — Issue176 포맷 유지)
    - display 단독 PATCH(거짓값) → 현재 flags/keyCode 기준 canonical 재생성, 오염 불가
    - `popupKeyCode: 99999` → `400 "popupKeyCode must be between 0 and 65535"`
    - GET general `popupHotkey.modifiers` = `["control","command"]` 정상 산출, 원복 후 `⌃⇧Space`(393475/49) round-trip 일치

## Issue174: [API] PATCH /api/v2/settings/popup — searchScope enum 불일치로 popup PATCH 전체 400 거부 (단축키 변경 무효) (등록: 2026-06-29) (✅ 완료, cd05f5d) ✅
* 목적: cliApp이 저장·사용하고 GET으로 반환하는 searchScope 값(`content`)을, 정작 PATCH 검증(`handleV2PatchPopup` allowed)이 거부함. paidApp의 popup PATCH는 단축키와 함께 항상 `searchScope`를 실어 보내므로, **단축키와 무관하게 PATCH 전체가 400으로 거부**되어 popup 설정(단축키 포함) 변경이 전혀 반영되지 않았다. paidApp의 `try?`가 400을 삼켜 "보냈는데 반영 안 됨"으로 보였다. Issue172(`refreshAll`)의 진짜 가림막 — PATCH가 400이면 refreshAll에 도달조차 못 함.
* depends: Issue172
* 상세:
    - 재현: 단축키 3필드만(`searchScope` 없이) PATCH → 200 정상. paidApp 실제 body(`searchScope:"content"` 포함) → `400 invalid_argument "searchScope must be one of [keyword, keywordName, keywordNameContent]"`.
    - enum 불일치: paidApp/cliApp `PopupSearchScope`(SnippetEntry.swift)는 `abbreviation`/`name`/`content`. `_config.yml`도 `snippet_popup_search_scope: "content"`. 그런데 cliApp 검증 allowed(APIRouter.swift L1045)만 `keyword`/`keywordName`/`keywordNameContent`로 잘못 박혀 있었음.
    - paidApp은 무죄: 단축키 값(393475·9437448 등 device-bit 포함)도, searchScope도 모두 정확히 전송.
* 구현:
    - `cli/fSnippetCli/Managers/APIRouter.swift` `handleV2PatchPopup`: `allowed = ["abbreviation","name","content"]` 정합 + `buildV2Popup` 기본값 `?? "abbreviation"` — cd05f5d 커밋에 포함되어 배포됨
* 검증 (2026-07-05, 실행 중 1.0.2 바이너리 대상 curl):
    - paidApp 실제 body(`searchScope:"content"` + 단축키 3필드) PATCH → 200 + 반영 확인
    - 구 enum `searchScope:"keyword"` PATCH → `400 invalid_argument "searchScope must be one of [abbreviation, name, content]"` 정상 거부

## Issue176: [Config] snippet_popup_hotkey 저장 포맷 brace 통일 — `{⌃⌥J}` (Issue175 strip 반전·대체) (등록: 2026-06-30) (✅ 완료, c614df2) ✅
* 목적: 사용자 요청 — popup 단축키도 다른 hotkey(`settings.hotkey: "{^⌘⇧;}"` 등)처럼 `_config.yml`에 brace 감싸 저장(`snippet_popup_hotkey: "{⌃⌥J}"`). Issue175는 popup brace를 strip하는 방향이었으나 본 이슈에서 **반대로 brace를 canonical 저장 포맷**으로 채택. 단 메모리·API·런타임은 raw(`⌃⌥J`) 유지하여 paidApp REST 정합(Issue173/174) 무영향.
* depends: Issue175
* 구현: `PreferencesManager.saveConfigInternal`이 serializeYAML 직전 사본에서 popup을 `{...}` wrap(cachedConfig 미변경), `loadConfigInternal`이 parseYAML 직후 brace strip → cachedConfig raw. 전 저장 경로가 saveConfigInternal→serializeYAML로, 전 읽기가 cachedConfig로 수렴하므로 단일 chokepoint 2개로 충분. `ConfigMigration`의 Issue175 brace-strip 블록 제거(canonical-braced와 충돌·백업 churn 유발). matching은 numeric 권위라 brace 무관.
* 검증: 저장→`_config.yml "{⌃⇧Space}"`, API GET raw `"⌃⇧Space"`, 재시작 round-trip 안정(이중brace·백업 churn 없음), active_hotkey 18, brew local 9/9 PASS.

## Issue175: [Config] snippet_popup_hotkey 수동 편집 방어 — brace 오입력(`{⌃⌥J}`) 자동 정정 (등록: 2026-06-29) (✅ 완료, 8bfc673) ✅ ⚠️ Issue176에서 방향 반전(strip→brace canonical)으로 대체·코드 제거됨
* 목적: 사용자가 `_config.yml`을 손편집하며 다른 핫키(`settings.hotkey` 등)처럼 `snippet_popup_hotkey: "{⌃⌥J}"`로 brace 감싸 저장하면 displayString에 brace가 박혀 표시/파싱이 어긋남. popup만 `PopupKeyShortcut`(displayString + 숫자필드) 체계라 raw 표기(`⌃⌥J`)여야 함. 두 체계 통합은 안 함(고위험 핫패스·기능버그 0), brace 오입력만 자동 정정.
* depends: Issue173
* 구현: `ConfigMigration.migrate()` 시작 시 1회 경로에 `snippet_popup_hotkey` 단독 brace strip(self-healing, 파일 재기록 + 백업). `Result.bracesNormalized` + `hasChanges` 포함. `PreferencesManager` 로그에 정정 건수 반영. 다른 hotkey는 brace 정상이라 미변경.
* 검증: 격리 ENV에서 `{⌃⌥J}` → `⌃⌥J` 정정 + 백업 생성 확인, 타 hotkey brace 보존(diff=popup 단독), BUILD SUCCEEDED, brew local 9/9 PASS.

## Issue172: [API] PATCH /api/v2/settings/popup 팝업 단축키 변경 후 ShortcutMgr 미갱신 — 재시작 전까지 반영 안 됨 (등록: 2026-06-28) (✅ 완료, 45cb4b9) ✅
* 목적: paidApp 설정 UI 또는 API로 팝업 단축키 변경 시 즉시 적용되지 않는 버그 수정
* 상세:
    - `handleV2PatchPopup` — `batchUpdate`로 `_config.yml`의 `snippet_popup_modifier_flags`, `snippet_popup_key_code`, `snippet_popup_hotkey` 기록 후 ShortcutMgr 재등록 없음
    - ShortcutMgr의 `registerAppGlobalShortcuts()` — 팝업 단축키를 `SettingsManager.shared.load()` 경유 등록 (line 448~456)
    - 결과: `_config.yml` 갱신되나 cliApp 메모리의 팝업 단축키는 구 값 유지 → cliApp 재시작 전까지 새 단축키 미적용
    - `_config.yml` 직접 편집 시에도 동일 문제 (`snippet_popup_hotkey` 표시 문자열만 변경하면 실제 `snippet_popup_modifier_flags`/`snippet_popup_key_code` 불일치 위험 포함)
    - Issue164([API] PATCH/PUT triggerKey 변경 후 TriggerKeyManager 미갱신) 동일 패턴
* 구현 명세:
    - `handleV2PatchPopup`: `popupModifierFlags`/`popupKeyCode`/`popupDisplayString` 중 하나라도 변경 시, `batchUpdate` 완료 후 ShortcutMgr 재등록 트리거
    - 방법: `handleSettingsChange` 알림 발송 (`SettingsManager.settingsChangedNotification` 등), 또는 `ShortcutMgr.shared.registerAppGlobalShortcuts()` 직접 호출
    - Issue164의 `TriggerKeyManager.shared.reloadSettings()` 패턴 참고

## Issue171: [Deploy] 버전 드리프트 방지 — publish 자동동기화 + 검증게이트 (등록: 2026-06-27, 완료: 2026-06-27) (Hash: 7780f93) ✅
* 목적: Issue170 후속 — `VERSION`(SSOT)과 xcodeproj `MARKETING_VERSION` 이 미연결 별개 값이라 드리프트 발생(VERSION 1.0.2지만 Info.plist·API 1.0.1). 재발 방지 위해 publish 경로에 2층 방어 추가.
* depends: Issue170 (충족)
* 구현 (`cli/_tool/fsc-deploy-brew.sh cmd_publish`):
    - 층1 자동동기화 (Step 0, 빌드 직전): `VERSION` → `project.yml` + `pbxproj`(Debug/Release) `MARKETING_VERSION` sed 강제 주입. VERSION 한 줄만 올리면 Info.plist `CFBundleShortVersionString`($(MARKETING_VERSION))·API `/status` version 자동 일치.
    - 층2 검증게이트 (Step 2.5, tarball 후·release 전): 빌드된 `.app` Info.plist `CFBundleShortVersionString` ≠ `VERSION` 이면 `gh release`·tap push 전 `return 1` 중단. 동기화 누락 시 엉뚱한 버전 공개 발행 차단.
* 검증: `bash -n` 문법 통과. 다음 publish 실행 시 Step 0/2.5 로그 발현 (`MARKETING_VERSION → x`·`✅ Info.plist 버전 검증`).
* 미적용(후순위): 층3 런타임 노출(/status 에 commit hash) + `CFBundleVersion`(빌드번호) 동기화 — store 배포 시 `version-manager-m` 스킬 통합 권장.

## Issue170: [Deploy] fSnippetCli 1.0.2 영구배포 — 단축키 게이팅(Issue933) Homebrew 반영 (등록: 2026-06-22, 완료: 2026-06-22) (Hash: 0086607) ✅
* 목적: paidApp 단축키 조합 입력 버그의 진짜 원인은 배포 미반영 — brew Cellar 가 구버전 cliApp 1.0.1(Issue933 게이팅 없음)을 launchd KeepAlive 로 점유. 수동 Cellar 교체 임시 상태라 `brew upgrade`·재설치 시 published 1.0.1 로 롤백되어 버그 재발. 1.0.2 정식 릴리스 + Formula 갱신으로 영구화.
* depends: Issue933(cliApp 게이팅, 4402a41), Issue936(paidApp displayString, 796ea889 — 메인 repo)
* 진단 근거: 메인 repo `_doc_work/z_htm/hub_htm_20260622_185102_a_shortcut-fix.htm` (root cause 규명)
* 구현:
    - `cli/_tool/fsc-deploy-brew.sh publish` 실행 (Issue167 구현분, VERSION=1.0.2 파라미터화)
    - Step1 Release 빌드 ✅ → Step2 tarball `fSnippetCli-1.0.2.tar.gz` (sha256 ab1735cc…) → Step3 `gh release create cli-v1.0.2` + asset ✅ → Step4 `cli/Formula/fsnippet-cli.rb` url/version/sha256 갱신 ✅ → Step5 원격 `Finfra/homebrew-tap` push ✅
    - 로컬 tap 복구: `UU` merge 충돌 + `file:///tmp` WIP stash 잔존 → `merge --abort` + `reset --hard origin/main`(53b7b5d, 1.0.2)
* 검증:
    - `brew reinstall finfra/tap/fsnippet-cli` → Cellar 1.0.2 (16 files), `brew list --versions` = 1.0.2
    - `brew services restart` → 실행 프로세스 `opt/fsnippet-cli`→Cellar/1.0.2 심링크, 빌드시각 18:59(게이팅 포함 Release)
    - 키캡처 런타임 로그는 사용자 단축키 녹화 시 발현 — 게이팅 코드는 1.0.2 바이너리에 포함됨(HID 주입 검증은 진단 report 참조)
* 후속 수정 (Hash: c379188): API `/status` version 이 1.0.1 리턴 → 원인은 xcodeproj `MARKETING_VERSION` 미bump(VERSION SSOT 1.0.2지만 Info.plist `CFBundleShortVersionString`=`$(MARKETING_VERSION)`=1.0.1). project.yml+pbxproj(Debug+Release) 1.0.2 bump → 재publish(sha256 d0434671) → Cellar Info.plist 1.0.2, **API version 1.0.2 확정**. (게이팅 기능은 1차 배포부터 정상이었고 버전 라벨만 stale 이었음)
* 비고: 본 1.0.2 Release 빌드는 working tree 기준 — 미커밋 UI 변경(HistoryPreviewView/PopupUIConstants) 포함됨. 게이팅(Issue933)은 기커밋이라 영향 없음.

## Issue168: [MCP] npm 재배포 — fsnippet-mcp v1.0.2 (등록: 2026-06-21, 완료: 2026-06-22) (Hash: 0cf65dd) ✅
* 목적: fsnippet-mcp MCP 서버를 npm 레지스트리에 재배포하여 최신 변경분을 공개 패키지에 반영.
* depends: Issue169 (충족)
* 상세:
    - 패키지: `fsnippet-mcp` v1.0.2, 위치: `mcp`
    - 재배포 사유: Issue169 REST 경로 v2 정합화(`/api/*`→`/api/v2/*`) 변경분을 npm 공개 버전에 반영
* 구현 명세:
    - ✅ VERSION SSOT 1.0.1→1.0.2 정합 + `package.json`/`package-lock.json` 1.0.2
    - ✅ `npm publish` 완료 — registry `fsnippet-mcp@1.0.2` 게시 확인
    - 비고: 초기 `npm publish` 는 2FA OTP(`EOTP`) 로 1회 차단 → OTP 재시도 후 게시 성공

## Issue169: [MCP] index.js REST 경로 v2 정합화 — /api/* → /api/v2/* (등록: 2026-06-21, 완료: 2026-06-21) (Hash: 1e0214d) ✅
* 목적: MCP 서버(`mcp/index.js`) REST 호출 경로 10곳이 버전 없는 `/api/...` 인데 cliApp 서버(`APIRouter.swift`)는 `/api/v2/...` 만 라우팅 → 전부 404. 공개 배포 전 v2 정합화.
* 구현:
    - `mcp/index.js` 10곳 v2 정합화 (sed): L87 snippets/search, L126 by-abbreviation, L128 snippets/{id}, L162 snippets/expand, L211 clipboard/history, L247 clipboard/search, L279 folders, L285 folders/{name}, L337 stats/{type}, L360 triggers
    - stats type(top/history)·baseURL(`http://localhost:3015`)·README 정상 (무수정)
* 검증:
    - 서버 가동(brew services) 상태 curl: old `/api/snippets` → 404 (버그 재현), v2 snippets/triggers/stats-top/folders/clipboard-history → 전부 200, snippets/expand POST → 400(route 매칭·검증단)
    - `node --check index.js` 통과, double-v2 grep 0건
    - 검토 리포트: `cli/_doc_work/z_htm/hub_htm_20260621_200030_a_mcp-api-sync.htm`
* 후행: Issue168(npm 재배포) 착수 가능

## Issue167: [Deploy] brew remote deploy 구현 — 원격 tap publish 활성화 (등록: 2026-06-18, 완료: 2026-06-18) (Hash: 74c4b16) ✅
* 목적: `/deploy brew publish` 미구현 → 원격 `finfra/homebrew-tap` + GitHub release 발행으로 외부 사용자 `brew install finfra/tap/fsnippet-cli` 동작화
* 구현:
    - `cli/_tool/fsc-deploy-brew.sh` `cmd_publish` 구현 (fWarrange 패턴 미러, 5단계): Release 빌드 → tarball(`fsnippet-cli-pkg/fSnippetCli.app`) → `gh release create cli-v1.0.1` + asset → `cli/Formula/fsnippet-cli.rb` url/version/sha 갱신 → 원격 tap clone·commit·push
    - `cli/Formula/fsnippet-cli.rb`: url `releases/download/cli-v1.0.1/fSnippetCli-1.0.1.tar.gz`, version 1.0.1, sha256 `32fc2132...` 실제값
    - `.claude/skills/deploy/SKILL.md`: publish 🚧 TODO → ✅ (로컬 SCAR, gitignore)
* 검증:
    - 원격 tap `Finfra/homebrew-tap` 에 `fsnippet-cli.rb` push 확인 (commit c86d048)
    - 로컬 tap origin 미연결(dev 전용) 문제 → `git remote add origin` + `reset --hard origin/main` 동기화
    - 클린 `brew reinstall finfra/tap/fsnippet-cli` → 원격 asset 다운로드 + sha 검증 통과 + `.brew` formula 기록
    - `brew services start` → Running:true, REST 헬스 `status:ok` (신규 인스턴스 uptime 3s)
* 잔여: 앱 번들 내부 version 문자열이 "1.0.0" (Info.plist 미bump) — formula 1.0.1과 불일치. version-manager-m 적용 시 동기화 필요 (별개)

## Issue166: [Docs/Plugin] API 문서 + LLM plugin(prj20) 최신화 — cliApp/brew 전환 반영 (등록: 2026-06-13, 완료: 2026-06-13) (Hash: 4a08a5b, prj20 8ec2ade) ✅
* 목적: 최근 API 작업(Issue163~165, paidApp 연동 920/921) 이후 공개 문서·prj20 LLM plugin 이 paidApp GUI 기준으로 stale. cliApp(fSnippetCli)/brew 운영 모델로 동기화
* 구현:
    - prj20 `f-claude-plugins/fSnippet/skills/fsnippet/SKILL.md` (8ec2ade): prereq `open -a fSnippet`+"Settings > Advanced > Enable REST API" → `brew install/services start finfra/tap/fsnippet-cli`. 트리거 심볼 `◊` → `{right_command}` (3곳). date bump
    - `_public/api/README.md`·`README_ko.md` (4a08a5b): Server "macOS native app" → fSnippetCli helper(Homebrew), API enabled OFF→ON, 잔존 ◊ 인코딩(`%E2%97%8A`) → `%7Bright_command%7D`. README_ko 예제 `/api/snippets` → `/api/v2/snippets` 버전 정정 + v1 deprecated 스펙 노트 동기화
    - `openapi_v2.yaml`: Issue916/921 로 이미 동기화 확인 (trigger-key 엔드포인트 존재) — 무수정
* 검증: 잔존 `◊`/`%E2%97%8A`/`open -a` GUI런치 0건, brew명 하이픈(`fsnippet-cli`) 정확

## Issue165: [KeyCapture] right_command 키 캡처 실패 — KM 인터셉션 + CGEvent flags 누락 (등록: 2026-06-13, 완료: 2026-06-13) (Hash: 0fcb9bc) ✅
* 목적: paidApp ShortcutInputView에서 right_command(keyCode 54) 키를 캡처할 수 없는 버그 수정
* 상세:
    - 원인 1: Keyboard Maestro Engine이 right_command의 flagsChanged 이벤트를 CGEventTap보다 먼저 인터셉트
    - 원인 2: `NSEvent(cgEvent:event)` nil fallback 시 `.deviceRightCommand` 비트 누락 → `toHotkeyString()` 오동작
* 구현:
    - `KeyCaptureManager.setKeyboardMaestroEnabled()`: `setenabled false` → `set enabled to false` (AppleScript 문법 수정)
    - `CGEventTapManager` flagsChanged else 분기: keyCode 54/60/61/62 기반 `correctedMods`에 deviceRight* 비트 삽입
## Issue164: [API] PATCH/PUT triggerKey 변경 후 TriggerKeyManager 미갱신 — 재시작 전까지 반영 안 됨 (등록: 2026-06-13, 완료: 2026-06-13) (Hash: ac5194d) ✅
* 목적: paidApp 설정 UI에서 트리거 키 변경 시 즉시 적용되지 않는 버그 수정
* 상세:
    - `handleV2PatchGeneral` 및 `handleV2PutGeneralTriggerKey` — `batchUpdate`로 `_config.yml`의 `snippet_trigger_key` 기록 후 `TriggerKeyManager.shared.reloadSettings()` 호출 없음
    - 결과: `_config.yml`은 갱신되나 cliApp 메모리의 트리거 키는 구 값 유지 → cliApp 재시작 전까지 새 키 미적용
* 구현:
    - `handleV2PatchGeneral`: `triggerKeyChanged` 플래그 추적 후 `batchUpdate` 완료 후 `TriggerKeyManager.shared.reloadSettings()` 호출
    - `handleV2PutGeneralTriggerKey`: 동일하게 `reloadSettings()` 호출 추가
## Issue163: [API/Index] 스니펫 생성 직후 GET /api/v2/folders/{name} 404·stale — rebuildIndex race (등록: 2026-06-12, 완료: 2026-06-12) (Hash: f600e0c, 8c3f357) ✅
* 목적: paidApp이 스니펫 저장 직후 목록 reload 시 일시적 404를 받아 빈 목록이 표시되는 race 제거
* 상세:
    - 재현: POST /api/v2/snippets 201 → 즉시(60ms) GET /api/v2/folders/ANsible → 404 (NOT_FOUND)
    - 원인 1: `handleCreateSnippet` → `SnippetFileManager.loadAllSnippets` → `SnippetRepository.loadAllSnippets` 말미 `SnippetIndexManager.rebuildIndex` 호출 → `clearIndex()` 후 재구축 — 재구축 동안 `entries`가 빈 상태(수백 ms 창)
    - 원인 2: `handleGetFolderDetail`이 `entries.filter(folderName).isEmpty`만으로 404 판정 — 인덱스 재구축 중이거나 빈 폴더면 실제 폴더가 존재해도 404
* 구현 명세:
    - `SnippetIndexManager.rebuildIndex`: `clearIndex()` 제거 — `_loadSnippets`의 `self.entries = newEntries` 원자적 교체만 사용 (빈 창 제거)
    - `handleGetFolderDetail`: folderEntries 빈 경우 디스크에 폴더 존재하면 200 + 빈 snippets 반환, 디렉토리 부재 시에만 404
* 검증: Release 재빌드·재배포 후 POST 201 → 즉시 GET 8연타 전부 200 (수정 전: 전부 404)
* 후속 (stale, 8c3f357): 404 제거 후에도 비동기 전체 재구축 완료 전 GET이 신규 항목 누락된 이전 entries 반환 (paidApp 목록에 새 스니펫 미표시, 폴더 재진입 시에만 반영)
    - 수정: `SnippetIndexManager.addOrUpdateEntrySync`/`removeEntrySync` 신설 (indexQueue.sync 단건 갱신) + `handleCreateSnippet`/`handleDeleteSnippet`이 응답 반환 전 호출
    - 검증: POST 201 → 즉시 GET에 신규 항목 포함 / DELETE 200 → 즉시 GET에서 제거 확인

## Issue162: [Core/KeyEvent] 모디파이어 트리거(오른쪽 ⌘)가 ⌘+Tab 앱 전환을 잡아먹음 — combo-breaker 누락 (등록: 2026-06-09, 완료: 2026-06-09) (Hash: 20e59d6) ✅
* 증상: 트리거 키를 `{right_command}`(오른쪽 ⌘)로 쓰는 환경에서 네이티브 ⌘+Tab 앱 전환이 동작하지 않음("alt_tab 잡아먹힘"). 오른쪽 ⌘로 Cmd+Tab 시 발생.
* 근본 원인:
    - 모디파이어 트리거는 modifier down(`.flagsChanged`) 시 `pendingModifierTriggerKeyCode` 설정 → modifier up 시 단독 탭이면 FIRE(확장)하는 구조.
    - combo-breaker(`pending` 취소)가 [CGEventTapManager.swift](cli/fSnippetCli/Core/CGEventTapManager.swift) line 306 위치 → **bufferClear(Tab/Space/Enter/`,`/`.`) 단축키 early-return(line 285)에 가려 도달 못 함**.
    - 결과: 오른쪽 ⌘ 누른 채 Tab → pending 취소 안 됨 → ⌘ 릴리스 시 spurious FIRE → 엉뚱한 확장/`isReplacing` → ⌘+Tab 전환 먹힘.
    - 실로그(18:16:44 `Pending Modifier Trigger Set: 54` → `FIRE`)로 메커니즘 존재 확인. left ⌘(55)는 트리거 아님 → 증상 발생 = 오른쪽 ⌘ 사용 확정.
* 구현 명세:
    - combo-breaker(`type == .keyDown && pendingModifierTriggerKeyCode != nil → cancelPendingModifierTrigger()`)를 **PID 필터 직후**(모든 단축키/bufferClear early-return 앞)로 이동.
    - 기존 line 306 블록은 주석으로 비움.
    - 정상 확장(텍스트 타이핑 후 ⌘ 단독 탭)은 pending 설정 전 keyDown만 존재하므로 영향 없음.
* 검증: Release 빌드 + brew 재배포 후 실제 오른쪽 ⌘+Tab → 앱 전환 정상(사용자 확인) + 로그 `FIRE Pending Modifier: 54` 0건.

## Issue161: [cliApp+paidApp] Create 버튼 → 스탠드얼론 스니펫 추가 창 (설정창 미경유, REST 저장) (등록: 2026-06-05, 완료: 2026-06-06) ✅
* 목적: 팝업 "Create 'xxx'" 클릭 시 paidApp 설정창이 아닌 독립 스니펫 추가 창으로 직접 진입
* 분담·종결 근거:
    - **cliApp 측 (본 레포): 코드 변경 없음** — Issue157(Hash b0b9872) 이 이미 `Create → handleNewSnippet() → PaidAppDetector.openNewSnippet()` 로 `fsnippet://command?action=new-snippet&keyword=…&source=cliApp` URL Scheme 을 발송. Issue161 의 cliApp 작업분(단축키 인식 → 설치 확인 → URL Scheme 발송)은 Issue157 로 충족. 별도 cliApp 변경 불필요
    - **paidApp 측 (prj15#Issue909): 사용자 직접 구현·테스트 완료** — `new-snippet` 수신 시 설정창 대신 `SnippetQuickAddWindow`(독립 플로팅 창) 표시 + `POST /api/v2/snippets` REST 저장. 동작은 paidApp 의 URL Scheme 핸들링이 결정하므로 목표 동작(독립창)은 paidApp 구현으로 실현
* 검증: 사용자 실 테스트 완료 ("테스트 완료함. paidApp은 내가 직접함")
* Hash: 코드 변경 없음 — 본 종결은 doc 커밋(Issue.md)으로 기록
* 의존: prj15#Issue909 (paidApp `SnippetQuickAddWindow` — 해소됨)

## Issue160: [Runtime/Snippet] `gcfg` 확장 시 값 중간 개행 오삽입 — file-ref placeholder trailing newline 미제거 (등록: 2026-06-05, 완료: 2026-06-05) (Hash: 053ec2a) ✅
* 증상: `gcfg` 확장 시 따옴표 값(`user.name`·`user.email`) 중간에 엔터가 끼어 한 줄이 여러 줄로 깨짐
* 근본 원인:
    - `Git/cfg===gcfg.txt` 본문은 CRLF 없이 깔끔(LF only). 값은 **파일 참조 placeholder** `{{~/.info/namee.txt}}`·`{{~/.info/mail1.txt}}`
    - 참조 파일이 trailing LF 보유: `namee.txt`=`Steve J. South\n`, `mail1.txt`=`nowage@gmail.com\n`
    - `SnippetExpansionManager.readFileContent` → `String(contentsOf:)` 가 trailing newline 포함 통째 반환 → file-ref 가 값 끝의 `\n` 을 그대로 inline → 따옴표 중간 개행
* 구현:
    - `cli/fSnippetCli/Core/SnippetExpansionManager.swift`: `stripTrailingNewlines()` 추가, `expandFileReferences` 의 재귀 resolve 직후 적용. trailing CR/LF만 제거(내부 개행·trailing space 보존)
    - **scope 결정**: file 참조(`{{~/path}}`) 경로만 strip. snippet 참조(`{{Folder/Snippet}}`) 는 composition 용도 — 멀티라인 의도 보존 위해 미적용 (회귀 방지). shell `$(cat file)` 의 trailing newline strip 관례와 일치
    - `cli/fSnippetCliTests/SnippetExpansionTrailingNewlineTests.swift` 신규 4 case (단일 값·gcfg 정확 레이아웃·내부 개행 보존·다중 trailing strip)
    - xcodeproj 재생성(xcodegen) — 새 테스트 파일 포함
* 검증:
    - XCTest 4/4 PASS (gcfg 정확 레이아웃 재현 케이스 포함)
    - brew local 재배포 9/9 PASS, REST 3015 정상, snippet 1963 로드
    - runtime 경로 확인: `TextReplacer.swift:1020` → `SnippetExpansionManager.shared.expand` (paste 시 동일 resolver)
* 참고: `/api/v2/snippets/expand` 엔드포인트는 SnippetExpansionManager 미경유(raw + 단순 placeholder) — 파일 참조 검증 불가, 실 검증은 unit test + runtime 경로 일치로 대체

## Issue159: [Runtime/Snippet] 세벌속기 자! 입력 시 ⌘; 글로벌 단축키 오발동 — 실제 원인은 스니펫 파일 부재 (등록: 2026-06-03, 완료: 2026-06-03) (Hash: 7e49d19) ✅
* 증상: 세벌속기 `자!`(물리 command+`;`·`'` 동시타) 입력 시 글자 미입력 + 클립보드 뷰어 `⌘;`(history.viewer.hotkey) 발동 (5회 반복). `cmd+o;`은 정상 → "콤보키에서만 오작동"처럼 보임
* 1차 가설(틀림): Karabiner 3set390 manipulator [183] command leak → ⌘; 오발동. flog 상 `{⌘;}` Registered Shortcut 발동은 사실이나 증상이었음
* 진짜 root cause: `자!` abbreviation 에 매칭되는 **스니펫 파일이 폴더에 존재하지 않았음**. 스니펫 부재 → `AbbreviationMatcher` 매칭 실패 → 확장 안 됨, ⌘; 발동은 매칭 실패의 부수 증상. **스니펫 생성으로 해결**
* 조치: 누락 스니펫 파일 생성 (cliApp 코드·Karabiner 룰 변경 불필요)
* 기록: `cli/_doc_base/debug_TECH.md` "세벌속기 자! 입력 시 ⌘; 글로벌 단축키 오발동" 사례 — 교훈: 단축키 충돌 증상이 스니펫 부재를 가림, 대상 스니펫 파일 존재 먼저 확인
* 참고: 조사 중 작성한 Karabiner 수정 가이드 `cli/_doc_work/z_htm/hub_htm_20260603_193247_a_issue159-guide.htm` (불필요해짐, 참고용 보존)

## Issue158: [cliApp] Placeholder 입력창 — 초기 선택 상태 텍스트가 paste 시 교체되지 않고 prepend됨 (등록: 2026-05-31) (✅ 완료, b0b9872) ✅
* 목적: PlaceholderInputWindow 첫 paste 시 초기값 전체 교체 (append 버그 수정)
* 수정: `initialValues` 스냅샷 추가 → `insertTextIntoFocusedField`에서 미편집 시 전체 교체 분기 (Method B)

## Issue157: [cliApp] 팝업 "Create" 버튼 → URL Scheme으로 paidApp 스니펫 추가 창 열기 (등록: 2026-05-31) (✅ 완료, b0b9872) ✅
* 목적: Create 버튼 → handleNewSnippet() → URL Scheme fsnippet://command?action=new-snippet&keyword=
* 수정: SnippetPopupView 버튼 액션 + PaidAppManager.handleNewSnippet() + PaidAppDetector.openNewSnippet()
* 연동: prj15#Issue907 (paidApp new-snippet 핸들러)
## Issue155 (3회 재오픈→완료): [Runtime/Match] folderPrefix shortcut 처리로 cleanBuffer 에서 prefix char 누락 — hasLongerMatches 변형 검사 추가 (등록: 2026-05-27, 완료: 2026-05-28) (✅ 완료, 82a7f8e + 3700aa3 + fc4c7cc + 24a546b + f6f4fe7) ✅
* 목적: fb1a9dc fix 후에도 라이브 `,ant + right_command` 회귀 → checkForSuffixMatches 경로 미보호 + modifier press/release 시 token 중복 누적 발견 → fix + XCTest 회귀 보호 추가
* 원인 (라이브 로그 01:57:27 추적):
    - **1차 (82a7f8e)**: modifier trigger 가 `case .triggerKey` 가 아닌 일반 key 경로로 진입 → processTriggerKey 미호출 → Issue155 fix 우회. checkForSuffixMatches 는 collision delay 없이 짧은 매칭 즉시 채택
    - **2차 (24a546b)**: modifier press(token literal 추가) → 첫 매칭 reject ✓. release(FIRE Pending → token literal 또 추가) 시 buffer=`,ant{right_command}{right_command}` 가 되어 cleanBuffer 추출 시 effectiveSuffix 1회 제거로는 `,ant{right_command}` 가 남아 collision 검사 무력 → expansion 진행 → `,antorch` 출력
* 구현:
    - **82a7f8e**: `checkForSuffixMatches` 의 `findBestMatch` 직후에 cleanBuffer prefix collision 검사 추가. matched.matchedLength < searchBuffer.count 인 short match 시 cleanBuffer 가 longer abbreviation prefix 면 candidate reject (continue)
    - **3700aa3**: testTable 38-case 확장 — case 36 (`{keypad_comma}test{keypad_comma}`), case 37 (`,test{keypad_comma}`), case 38 (`,,test{keypad_comma}`) 추가
    - **fc4c7cc**: `testIssue155RuntimeCollision` XCTest 추가 (3 시나리오)
    - **24a546b**: cleanBuffer 추출을 while loop 로 변경 — trailing trigger token 들을 모두 제거하여 진짜 raw buffer 도달. modifier press+release 중복 token 케이스 대응. XCTest 에 `,test{right_command}{right_command}` reject 케이스 추가
    - **f6f4fe7** (진짜 root cause): `AbbreviationMatcher.hasLongerMatches` 에 folderPrefix 변형 검사 추가. _emoji prefix `,` shortcut 처리 시 buffer 에서 `,` 가 제거되어 cleanBuffer=`ant` 가 되더라도, 모든 활성 룰의 prefix 변형 (`,` + `ant` = `,ant`) 로 snippetMap 검사 → `,ant{keypad_comma}` 발견 → reject. testTable case 39 (`,ant{keypad_comma}`) 추가 + XCTest 5번째 케이스 (`ant{right_command}` reject)
* 검증:
    - testAllFolderCases 39/39 PASS (abbreviation generation 포함 case 39)
    - testIssue155RuntimeCollision 5 assertion PASS — exact + 3 collision + 중복 token + folderPrefix 변형
    - brew local 재배포 9/9 PASS, REST API 정상


## Issue154: [Calculator/Rule] noteForHuman 오동작 — Initcap `_` strip + Initcap suffix 유지 + 룰 케이스 매칭 (등록: 2026-05-27, 완료: 2026-05-27) (Hash: 9144475) ✅
* 목적: noteForHuman.md x표시 라인 6건 중 4건 fix (line 14·20·21·22)
* 상세:
    - B1: `_FUNDAMENTAL/Cf_.txt`·`A_.txt`·`An_.txt` 등 `===` 없는 `_` suffix 파일이 keyword 에 `_` 포함 → `Cf_∆`·`A_∆`·`An_∆` 로 저장. 사용자 입력 `Cf∆`·`A∆`·`An∆` 와 불일치. 66개 파일 영향.
    - B2: 디스크 폴더 `ANsible` vs `_rule.yml` 룰 키 `Ansible` 케이스 불일치 → `RuleManager.getRule` nil 반환 → 디폴트 트리거 `{right_command}` 적용. doc 기대 `an!`·`An!` 미생성.
    - 추가: `===Name_.txt` Initcap 케이스의 suffix 누락 fix — 룰 suffix 유지 (트리거 동작 보장). `An!`·`Ag∆` 정상 생성.
* 구현 명세:
    - `cli/fSnippetCli/Data/AbbreviationCalculator.swift` else branch 에 Initcap `_` strip 로직 추가 (uppercase first char + `_` suffix → strip). Initcap suffix 유지로 변경 (`(rule.suffix == " ") ? "" : rule.suffix`).
    - `cli/fSnippetCli/_rule_for_import.yml` line 33 `Ansible` → `ANsible`
    - `~/Documents/finfra/fSnippetData/snippets/_rule.yml` line 44 `Ansible` → `ANsible`
    - brew 로컬 재배포 후 by-abbreviation API 검증: `Cf∆`·`A∆`·`an!`·`An!`·`Ag∆`·`ag∆` 모두 통과
    - 회귀 검증: case1~35 트리거 패턴 영향 없음

## Issue153: [cliApp] paidApp 설정창 열기 — DistributedNotification 채널 전환 (등록: 2026-05-27, 완료: 2026-05-27) (Hash: d2580d9) ✅
* 목적: paidApp 이미 실행 중일 때 URL scheme + activate() 경로가 unreliable (paidApp frontmost 상태에서 설정창 미표시). DistributedNotification 채널로 안정화.
* 상세:
    - `PaidAppManager.openSettings()` `.started` 분기: `activatePaidApp` + URL scheme → `DistributedNotificationCenter` post (`fSnippetOpenSettings`)
    - paidApp 측 `setupDistributedNotificationListeners` → `handleOpenSettingsNotification` → `showSettings` (policy restore + activation 자체 처리)
    - `PaidAppDetector.openSettings()`: Issue143 1초 디바운스 제거 (paidApp 측에서 자체 처리)
    - `activatePaidApp`: deprecated `activateIgnoringOtherApps` → `app.activate()`
* 구현 명세:
    - `.stopped` 분기는 `launchAndOpenSettings` 유지 (paidApp 미실행 시 URL scheme fallback 필요)
    - DistributedNotification name: `fSnippetOpenSettings`, deliverImmediately=true

## Issue152: [cliApp] Issue146 revert — appRootPath seed → ~/Documents/finfra/fSnippetData (등록: 2026-05-27, 완료: 2026-05-27) (Hash: 62853ff) ✅
* 목적: Issue146 (data root 를 `~/Library/Application Support/kr.finfra.fSnippetCli/data` 로 이전) 가 사용자 의도와 불일치. `~/Documents/finfra/fSnippetData/` 는 legacy 가 아닌 정식 SSOT 임을 확정.
* 상세:
    - `PreferencesManager.resolveAppRootPath()` seed → `~/Documents/finfra/fSnippetData`
    - `migrateLegacyData()` 함수 제거
    - UserDefaults `appRootPath` 가 deprecated Application Support 경로면 Documents 로 자동 재지정
    - Application Support 폴더 (`~/Library/Application Support/kr.finfra.fSnippetCli`) 수동 삭제 (사용자 직접)
* 구현 명세:
    - ENV `fSnippetCli_config` override / UserDefaults priority 유지
    - 마이그레이션 로직은 Documents → AS 단방향이 아닌 AS → Documents 자동 재지정으로 변경

## Issue151: [UI/Snippet] 스니펫 팝업 셀 단순화 — Issue140 클립보드 패턴 차용 (등록: 2026-05-26, 완료: 2026-05-26) (Hash: 60cb6e4) ✅
* 목적: 스니펫 팝업 셀이 2행 VStack (abbreviation+folder badge / displayName) 으로 빽빽함. Issue140 에서 클립보드 셀을 1행으로 정리한 것과 동일 패턴으로 스니펫 셀도 단순화하여 한 화면에 더 많은 항목 표시
* 참고: Issue140 (Hash: ba25957) — 클립보드 셀 단순화 (kindLabel·trash·timeString 제거, 1행, rowHeight 44→30, trash 버튼은 Preview 헤더로 이관)
* 구현 명세:
    - `SnippetRowView` 1행 HStack 으로 재구성: [icon] [abbreviation (mono semibold)] [displayName (truncate, secondary)] [folderBadge] [shortcut?] [pencil(selected/hover)]
    - VStack 내부 2행 구조 제거, abbreviation·displayName 같은 baseline 정렬
    - pencil 편집 버튼은 셀에 유지 (paidApp 안내 트리거 — 사용자가 자주 누르므로 Preview 헤더로 옮기면 발견성 저하). 단, hover/selected 시에만 표시 유지
    - 수정 파일: `cli/fSnippetCli/Views/Popup/SnippetRowView.swift`
* trade-off:
    - 1행 변경으로 긴 displayName 은 truncate. 사용자가 전체 description 보려면 우측 SnippetPreviewView 활용
    - rowHeight 는 `PopupUIConstants.rowHeight` (30) 유지 — 윈도우 높이 계산 영향 없음
* 검증: xcodebuild Release BUILD SUCCEEDED + brew local 9/9 PASS

## Issue150: [cliApp] pairApp 패턴 차용 — 권한 처리 simplify (등록: 2026-05-26) (✅ 완료, 2afc508) ✅
* 목적: pairApp(fWarrangeCli) 의 단순한 권한 처리 패턴(AccessibilityService + AccessibilityGuidePresenter)을 이식. 폴링·revoke·abortModal·마커 등 누적된 복잡성 제거
* 구현 명세:
    - 신규 `Services/AccessibilityService.swift` (protocol + SystemAccessibilityService impl)
    - 신규 `Services/AccessibilityGuidePresenter.swift` (NSAlert enum)
    - fSnippetCliApp.swift simplify — checkAccessibilityPermission 만 남김. polling timer/revoke handler/reinitialize/abortModal/suppressBootAlertOnce 마커 전부 제거
    - Issue42/117/148/149 명세 철회 — 동일 영역 누적된 복잡성 일괄 단순화
* trade-off: revoke 시 자동 cleanup 없음 → `handleTapDisabled` 자체 fallback 에 위임. 권한 부여 후 사용자가 cliApp 재시작 (brew services restart 또는 메뉴바) 필요
* 검증: 빌드·brew local 9/9 PASS

## Issue149: [cliApp] TCC mismatch — 시스템 설정 토글 ON 인데 alert 표시 + 토글 ON 직후 alert 자동 dismiss 미동작 (등록: 2026-05-26) (✅ 완료, fde04ae) ✅
* 목적: brew 재서명 후 TCC csreq 불일치로 토글 ON 상태에서도 alert 표시되는 문제 + 토글 OFF→ON 으로 권한 회복 시 alert 자동 닫힘 동시 해소
* 상세: Apple Development 인증서 ad-hoc 서명 → CDHash 매 빌드 변동 → TCC entry 와 csreq 매칭 깨짐. 시스템 설정 UI 는 ON 으로 보이지만 실제 매칭 X
* 구현 명세:
    - `pendingAccessibilityAlert` ivar 추가 — 표시 중인 NSAlert 보관
    - showAccessibilityAlert 메시지 보강: "brew 재배포 직후 권한 매칭이 깨졌을 수 있습니다. 토글 OFF → ON 다시 누르세요" 안내
    - polling grant 전이 시 `NSApplication.shared.abortModal()` + ivar clear → alert 자동 dismiss
* 검증: 빌드·brew local 9/9 PASS

## Issue148: [cliApp] 권한 OFF → revoke alert + launchd 재시작 boot alert 두 번 노출 (등록: 2026-05-26) (✅ 완료, 32a9591) ✅
* 목적: revoke alert 표시 후 cliApp terminate → launchd KeepAlive 재시작 → boot 시 showAccessibilityAlert 가 또 표시되는 두 alert 시퀀스 차단
* 상세: Issue147 은 키 이벤트 실패 경로 alert 만 차단. revoke + respawn 경로는 별개 — KeepAlive.SuccessfulExit=false 로 정상 종료도 재시작
* 구현 명세:
    - revoke 시 UserDefaults `suppressBootAlertOnce=true` 마커 세팅 후 terminate
    - boot 시 `checkAccessibilityPermission` 에서 마커 존재 + 권한 미승인이면 alert skip + 마커 clear
    - polling 그대로 시작. 사용자가 권한 재부여하면 grant 전이 감지하여 reinit
* 검증: 빌드·brew local 9/9 PASS

## Issue147: [cliApp] 권한 OFF 시 NSAlert 두 번 노출 — ErrorRecoveryManager alert 경로 제거 (등록: 2026-05-26) (✅ 완료, b52a39d) ✅
* 목적: 시스템 설정 접근성 권한 OFF 시 두 NSAlert 동시 노출 차단
* 상세: 경로 A(`fSnippetCliApp.handleAccessibilityRevoked` polling)와 경로 B(`ErrorRecoveryManager.showAccessibilityPermissionAlert` 키 실패 후 안내)가 동시 트리거되어 중복. Issue146 버전 가드는 부팅 첫 표시만 차단 — revoke 시 B 가 첫 표시면 통과
* 구현 명세:
    - `ErrorRecoveryManager.handleAccessibilityPermission()` 의 `showAccessibilityPermissionAlert()` 호출 제거, `logW` 만 유지
    - `showAccessibilityPermissionAlert()` 함수 삭제 (호출자 없음). Issue146 버전 가드 코드 정리
    - polling 경로 A 가 NSAlert SSOT. 부팅 시 미승인 안내 (경로 C) 는 그대로 유지
* 검증: 빌드 + brew local 재배포 정상, REST 3015 응답 OK, 9/9 PASS

## Issue146: [cliApp] 권한 다이얼로그 반복 노출 영구 fix — 데이터 폴더 이전 + 다이얼로그 표시 조건 완화 (등록: 2026-05-26) (✅ 완료, fc0905c, 143f4a8) ✅
* 목적: brew 재빌드·launchd respawn 시 Documents TCC 다이얼로그 + 접근성 NSAlert 반복 노출 차단
* 구현 명세:
    - **A안 (데이터 폴더 이전)**: `PreferencesManager.resolveAppRootPath()` seed → `~/Library/Application Support/kr.finfra.fSnippetCli/data`. legacy `~/Documents/finfra/fSnippetData` 존재 시 1회 copyItem + UserDefaults 재기록 (legacy 보존)
    - **B안 (다이얼로그 표시 조건 완화)**: `Info.plist` `NSDocumentsFolderUsageDescription` 추가. `ErrorRecoveryManager.handleAccessibilityPermission()` 버전별 1회 alert 가드 (UserDefaults `accessibilityAlertShownVersion`). polling 양방향 전이 감지는 `fSnippetCliApp.swift` 5초 polling 그대로 유지
    - **재진입 회피**: `resolveAppRootPath`/`migrateLegacyData` 내부 로그를 `NSLog`로 한정. Logger lazy init 도중 `logI` 호출 시 `AppSettingManager.shared` dispatch_once 재진입으로 SIGTRAP 발생하던 크래시 회피
* 검증:
    - brew local 재배포 후 cliApp 정상 기동, REST API 3015 응답 OK, snippet 2034개 로드
    - `brew services restart` 5회 연속 무크래시 (이전 빌드 18:10 SIGTRAP 이후 0건)
    - UserDefaults `appRootPath` → newSeed 자동 갱신, 로그 파일 새 경로(`~/Library/Application Support/...`)에서 활발히 기록 중

## Issue145: [cliApp] paidApp 실행 중 설정창 열기 실패 — .started 경로 5초 블로킹 해소 (등록: 2026-05-26) (✅ 완료, 2934048) ✅
* 목적: paidApp이 이미 실행 중일 때 메뉴바/단축키로 설정창을 즉시 열기
* 상세:
    - cliApp 재시작 후 paidApp은 re-register를 하지 않아 PaidAppStateStore.status()=nil
    - `.started` 경로에서 `waitForPaidAppRegistration()` 이 5초 대기 후 타임아웃 → 설정창 열리지 않는 문제
    - `activatePaidApp()` 누락으로 paidApp이 foreground로 올라오지 않는 문제 동시 해소
* 구현 명세:
    - `PaidAppManager.openSettings()` `.started` 케이스: `waitForPaidAppRegistration()` 제거, `activatePaidApp()` 추가
    - paidApp 이미 실행 중이므로 등록 대기 불필요 — PaidAppDetector.openSettings()가 1채널(bundlePath)/2채널(LaunchServices) 자동 선택
    - `activatePaidApp()` 안전: paidApp.applicationDidBecomeActive가 비어있음 (Issue144)

## Issue144: [cliApp] 설정창 무조건 열기 — consent 우회 + activatePaidApp 제거 (등록: 2026-05-26) (✅ 완료, 4a51b18) ✅
* 목적: 단축키/메뉴바로 설정창 열 때 autoLaunchConsent 플래그와 무관하게 무조건 settings 진입
* 상세:
    - `.stopped + autoLaunchConsent=false` → `showRequirePaidAlert()` 다이얼로그 block 해소
    - `launchAndOpenSettings()` 내 `activatePaidApp()` 제거 — activatePaidApp이 applicationDidBecomeActive를 미리 소비해 initialActivationHandled 소진, URL scheme 도달 전 paidApp settings 억제하는 race 해소
* 구현 명세:
    - `PaidAppManager.openSettings()` 신규: consent 체크 없이 fresh status 평가 후 분기
    - `launchAndOpenSettings()`: `activatePaidApp()` 호출 제거 (URL scheme activates=true 의존)
    - `SettingsWindowManager.showSettings()`: `handlePaidFeature()` → `openSettings()` 교체

## Issue143: [cliApp] openSettings() 중복 요청 방지 플래그 추가 (등록: 2026-05-26) (✅ 완료, f51f4e0) ✅
* 목적: paidApp Issue899와 연계하여 cliApp 측에서도 settings 열기 요청을 1회로 제한, 빠른 연속 클릭에 의한 paidApp 플래그 경쟁 조건 방지
* 상세:
    - `PaidAppDetector.openSettings()` 호출 시 1초 이내 중복 요청 무시
    - `lastSettingsOpenTime` 타임스탬프 기반 디바운스 구현
    - PaidAppDetector.swift: 1초 디바운스 가드 추가

## Issue142: [paidApp 연동] 첫 클릭 설정창 미표시 — `.started` 경로 URL scheme LaunchServices 폴백 신뢰성 (등록: 2026-05-25, 완료: 2026-05-25) (Hash: 4ab95f5) ✅
* 목적: cliApp 자동기동 직후 첫 클릭 시 설정창이 여전히 열리지 않는 문제 해소 (Issue141 cliApp-side fix 불완전)
* 상세:
    - Issue141 fix: `.started` case → `activatePaidApp()` 후 0.1s 고정 딜레이 + `PaidAppDetector.openSettings()`
    - paidApp 등록 미완료 상태(< ~3s)이면 `PaidAppStateStore.status()=nil` → LaunchServices 폴백(`NSWorkspace.open(schemeURL)`)
    - LaunchServices 폴백은 DerivedData/캐시된 경로 등 잘못된 앱 인스턴스로 라우팅될 수 있어 URL scheme 미전달 가능
    - `.stopped + autoLaunchConsent=true` 경로(`launchAndOpenSettings()`)는 `waitForPaidAppRegistration()` 적용됨 — `.started` 경로만 누락
* 구현 명세:
    - `PaidAppManager.handlePaidFeature()` `.started` case: 고정 0.1s asyncAfter → `waitForPaidAppRegistration()` 패턴으로 교체
    - `launchAndOpenSettings()`와 동일: global queue에서 `waitForPaidAppRegistration()` 대기 후 main queue에서 `openSettings()` 호출
    - registration 완료 시 1차 채널(bundlePath 직접 라우팅) 보장 → 신뢰성 향상
    - 수정 파일: `cli/fSnippetCli/Managers/PaidAppManager.swift`

## Issue141: [paidApp 연동] 메뉴/단축키 첫 클릭 시 설정창 미표시 — startup 자동기동 race (등록: 2026-05-25, 완료: 2026-05-25) (Hash: a88736a) ✅
* 목적: cliApp 시작 시 paidApp 자동 launch 직후 사용자가 메뉴바/단축키로 설정창을 열 때 첫 클릭에서 설정창 미표시 race 해소
* 구현 명세:
    - `PaidAppManager.handlePaidFeature()`: `AppStateManager.paidAppStatus` 캐시 → `isRunning()`/`isInstalled()` NSWorkspace 직접 조회로 freshStatus 결정. paidApp 실행 중이면 consent/launch 우회하고 `.started` 분기로 직행
    - `activatePaidApp()` 후 `openSettings()` 를 0.1s `asyncAfter` 지연 — activation 처리 전 URL scheme 수신 race 해소
    - `KeyEventProcessor.isPaidAppForeground()`: `WindowContextManager` 캐시 → `NSWorkspace.shared.frontmostApplication` 직접 조회로 전환 (동일 race 패턴)
    - 수정 파일: `PaidAppManager.swift`, `KeyEventProcessor.swift`

## Issue140: [UI/Clipboard] 클립보드 히스토리 셀 단순화 + 복사 누락 캡처 보강 (등록: 2026-05-25, 완료: 2026-05-25) (Hash: ba25957) ✅
* 목적:
    - (UI) 클립보드 히스토리 팝업 셀을 1행으로 단순화하여 한 화면에 더 많은 항목 표시
    - (Bug) Cmd+C 후 클립보드 히스토리에 항목이 등록되지 않는 누락 케이스 보강
* plan: `cli/_doc_work/plan/clipboard-cell-simplify_plan.md`
* 상세:
    - UI Part: kindLabel·trash 버튼·timeString 셀 내 제거, contentPreview 1줄+`+NL` 배지, rowHeight 44→30, trash 버튼은 HistoryPreviewView 헤더로 이동
    - Bug Part: `maxPollingInterval=10s` 백오프 + Cmd+C 감지 시 단발 `scheduleNextPoll(0.5)` → OS 페이스트보드 갱신 타이밍과 폴링 timer 어긋남 → 1회성 0.5s 폴링이 빈손으로 종료 후 backoff 진입하여 항목 누락 발생
* 구현 명세:
    - UI: HistoryRowView/PopupUIConstants/HistoryPreviewView/UnifiedHistoryViewer 수정 (계획서 Step 1~4)
    - Bug:
        * `maxPollingInterval` 10s → 2s 단축
        * Cmd+C/Cmd+X 감지 시 staggered `flushPendingChange()` 재폴링 (0.15s, 0.4s, 0.8s) + 백오프 즉시 리셋
    - 수정 파일: `cli/fSnippetCli/UI/History/HistoryRowView.swift`, `HistoryPreviewView.swift`, `UnifiedHistoryViewer.swift`, `cli/fSnippetCli/UI/PopupUIConstants.swift`, `cli/fSnippetCli/Managers/ClipboardManager.swift`

## Issue139: paidApp 꺼진 상태에서 설정창 첫 번째 열기 실패 (등록: 2026.05.24) (✅ 완료, cd95b0f) ✅
* 목적: cliApp이 paidApp을 시작하고 설정창을 열 때, 첫 번째 시도에서 설정창이 열리지 않는 문제 수정
* 상세: 
    - PaidAppDetector.openSettings() 1차 채널(NSWorkspace.open([schemeURL], withApplicationAt:))이 completionHandler: nil로 실패를 무시함
    - custom URL scheme을 NSWorkspace.open([url], withApplicationAt:)에 전달 시 실패할 수 있음 (파일 URL 용 API)
    - 실패가 묻혀 설정창이 미표시되는 silent failure 패턴
* 구현 명세:
    - PaidAppDetector.openSettings() 1차 채널에 completionHandler 추가
    - error 발생 시 logW 기록 후 2차 채널(LaunchServices NSWorkspace.open(schemeURL))로 자동 폴백
    - 수정 파일: cli/fSnippetCli/Utils/PaidAppDetector.swift



## Issue135: [paidApp 연동] folderExcludedFiles REST API 제공 검증 — prj15#Issue892(paidApp) 대응 (등록: 2026-05-20, 완료: 2026-05-20, 검증 완료) (Hash: 175a916)
* 목적: prj15#Issue892(paidApp)가 `folderExcludedFiles`를 REST 경유로 읽고 쓸 때 cliApp `/api/v2/settings/excluded-files/per-folder` 엔드포인트가 정상 응답하는지 검증.
* depends: prj15#Issue892 (paidApp, 구현 주체)
* 검증 결과 (cliApp 실행 중 curl, 엔진 코드 무수정):
    - **GET** `/per-folder` → raw map `{ "folderName": ["file.txt"] }` 반환. `openapi_v2.yaml` L539-542 (object + additionalProperties array of string) 와 일치
    - **PUT** `/per-folder/{folder}` body `["dummy.txt"]` → 200 + 응답 list. `_config.yml`의 `snippet_folder_excluded_files` 키에 `{"_qaTestFolder":["dummy.txt"]}` 반영 확인
    - **DELETE** `/per-folder/{folder}` → 204 + 키 제거 확인 (`snippet_folder_excluded_files: {}`)
    - 저장소: `PreferencesManager` → `_config.yml` `snippet_folder_excluded_files` (상수 `v2PerFolderExcludedKey`)
    - 테스트 데이터(`_qaTestFolder`)는 DELETE로 정리 완료
* 명세 정정: 등록 시 확인 항목에 적은 GET 응답 형식 `{ "data": {...} }`는 부정확 — 실제 구현·`openapi_v2.yaml` SSOT 모두 래퍼 없는 raw map. SSOT 기준이 정답
* 결론: cliApp 측 엔드포인트(GET 전체/단건·PUT·DELETE·POST) 정상 작동. prj15#Issue892(paidApp) 구현 시 즉시 사용 가능

## Issue138: [Test/Infra] qa 하니스 special-key 케이스 — 35/35 달성 (하니스 결함 수정) (등록: 2026-05-20, 완료: 2026-05-21) (Hash: 3fed3e3, 0a043a2)
* 목적: Issue137 `qa_run_batch.sh` 검증의 case20/21/22/23 FAIL 4건 원인 규명·처리.
* plan: `cli/_doc_work/plan/special-key-trigger-conflict_plan.md`
* ⚠️ 1차 결론 철회 (2026-05-21): 최초 "엔진 by-design 한계"로 종결(3fed3e3)했으나 **오류**. 사용자 수동 타이핑으로 case20~23 전부 정상 확장됨이 flog로 입증 → **엔진은 정상, 전부 하니스(Issue137 산출물) 결함**.
* 진짜 근본 원인:
    - **literal 키 전송 방식**: Quartz keycode-0 unicode가 sh 스크립트 경유 시 불안정. case별 입력 대상은 `testBoard.txt`를 `open`(context-change) + Enter(buffer-clear 키)로 엔진 buffer flush
    - **osascript ↔ Quartz 혼용 금지**: osascript subprocess 실행 후 같은 process의 Quartz `CGEventPost`가 무효화됨 — token(AppleScript) 직후 literal(Quartz)이 유실. abbreviation 단위로 경로를 하나만 선택하도록 분리
    - **keypad keycode**: `design_keyProcess.md` 표의 keypad_comma/num_lock keycode 뒤바뀜 → 표준 macOS 값(comma=95, num_lock=71)으로 정정. AppleScript `key code 95`는 US 키보드 미존재 키라 무시 → keypad_comma만 Quartz
    - **입력 소스**: 한글 IME 시 `keystroke`가 한글 렌더 → `force_ascii.py`(Carbon TIS)로 ASCII 강제
* 해결 (`0a043a2`): `qa_type.py` 경로 분리 — `{f1}/{f2}/{keypad_num_lock}` 포함 abbreviation은 전체를 한 osascript 세션, 그 외는 전체 Quartz. `qa_run_batch.sh`: testBoard.txt 대상 + Enter flush
* 검증: 전체 35-case **2회 연속 PASS 35/35**
* 관련: Issue137 (검증 하니스), Issue134 (XCTest 35/35 — 생성 레이어)

## Issue137: [Test/Infra] 실제 키보드 paste 확장 검증 — `qa_run_batch.sh` 키보드 자동화 하니스 (등록: 2026-05-20, 완료: 2026-05-20) (Hash: c6802e8)
* 목적: Issue134는 XCTest로 abbreviation 생성 로직만 검증. 실제 키 입력 → CGEventTap → 텍스트 확장 end-to-end 경로를 키보드 자동화로 검증.
* plan: `cli/_doc_work/plan/qa-keyboard-batch_plan.md`
* 구현: 신규 하니스 3종 (`cli/_tool/qa/`)
    - `keycode_map.py` — 특수 토큰 → keycode 매핑. `design_keyProcess.md` 표의 keypad_comma/num_lock keycode가 뒤바뀐 것 발견 → 표준 macOS 값(comma=95, num_lock/Clear=71)으로 정정
    - `qa_type.py` — Quartz CGEvent 키스트로크 타이퍼 (리터럴 unicode + modifier flagsChanged + plain key)
    - `qa_run_batch.sh` — orchestrator: healthz → testTable 파싱 → TextEdit 타이핑 → 확장 결과 비교 → result 리포트
* 검증: 35-case 실행 → **31/35 PASS**
    - 통과: case1~19, 24~35 — modifier 트리거(`{right_command}`/`{right_option}`/`{right_control}`), `{keypad_comma}`, 특수문자 prefix/suffix 전부 정상 확장. case13/14/27(`{right_command}`) 충돌 우려 재현 없음
    - 실패 4건: case20/21/22/23 — 단건 재실행에서도 일관 FAIL → 엔진 special-key 트리거 한계로 원인 규명
* 하니스 버그 수정 (실행 중 발견):
    - argparse가 `-` 시작 abbreviation(`-test`)을 옵션 오인 → `--` 구분자 추가
    - keypad keycode 뒤바뀜 → `keycode_map.py` 정정
    - flaky case2 → `SETTLE` 0.4→0.6, `EXPAND_WAIT` 0.7→1.0 상향
* 후속: case20/21/22/23 엔진 한계 → **Issue138** 분기
* result 리포트: `cli/_tool/qa/results/` (gitignored, 실행 산출물)

## Issue134: [Test] 35-case 스니펫 매트릭스 회귀 — XCTest 35/35 통과 (등록: 2026-05-20, 완료: 2026-05-20) (Hash: e61584b, 9640986)
* 목적: `_rule.yml` ↔ `testTable_org.md` 를 35-case 매트릭스로 동기화한 뒤 35개 케이스 abbreviation 확장 회귀 검증. 33-case 시점 우려된 case13/14/17/27 이상 해소 확인.
* 실행 방식: 명세의 `_tool/qa/qa_run_batch.sh` 키보드 자동화 스크립트는 부재 → Issue124 XCTest 인프라(`FolderTestRunnerTests.testAllFolderCases`)로 대체 실행. abbreviation 생성 로직 차원 검증 (실제 키 paste 확장은 범위 외)
* 구현:
    - `cli/fSnippetCliTests/FolderTest/testTable_org.md`: 33 → 35 case 동기화 (e61584b — Issue134 산출물)
    - `cli/fSnippetCliTests/FolderTest/FolderTestRunnerTests.swift`: L110 `XCTAssertEqual` 기대값 33 → 35 박제 수정 + 주석·실패 메시지 정합성 정정 (9640986)
* 검증: `xcodebuild test FolderTestRunnerTests/testAllFolderCases` → **35/35 PASS** (`** TEST SUCCEEDED **`)
    - `result_latest.md` `passed: 35/35`
    - 중점 케이스 전부 ✅: case13/14/27 (`{right_command}`), case17 (`{keypad_comma}`), case34/35 (`{right_control}`)
    - 33-case 시점 우려된 `{right_command}` 충돌·`testorch` 오확장 재현 없음
* 후속: 실제 키보드 paste 확장 검증(`qa_run_batch.sh` 신규 작성)이 필요하면 별도 이슈 — 본 이슈는 매트릭스 abbreviation 회귀까지

## Issue136: [API] `APIFolderSummary`에 `rule_managed` 필드 추가 — paidApp prefix/suffix 신뢰 판정 (등록: 2026-05-20, 완료: 2026-05-20) (Hash: b191a55)
* 목적: Issue133 후속. paidApp이 폴더의 `prefix`/`suffix`를 신뢰하고 표시하려면, 해당 값이 `_rule.yml`의 명시적 규칙에서 온 것인지 기본값(전역 트리거) 폴백인지 구분이 필요. 현재 `APIFolderSummary`는 둘을 구분 못 함.
* 구현:
    - `cli/fSnippetCli/Data/APIModels.swift`: `APIFolderSummary`에 `let ruleManaged: Bool` + CodingKey `rule_managed`
    - `cli/fSnippetCli/Managers/APIRouter.swift`: `handleGetFolders` 2개 호출부에 `ruleManaged: rule != nil` 전달
    - `api/openapi_v2.yaml`: `FolderSummary` 스키마에 `rule_managed` boolean 추가
* 검증: Release 빌드 통과
* 후속: paidApp 측에서 `rule_managed == false` 폴더의 prefix/suffix 표시 정책 결정

## Issue133: [API/Feature] `GET /api/v2/folders` 폴더 아이콘 노출 — `?icons=true` opt-in base64 (등록: 2026-05-20, 완료: 2026-05-20) (Hash: c976b6c)
* 목적: paidApp 폴더 목록(Snippets/Folders 탭)에 폴더 커스텀 아이콘 미표시. paidApp은 샌드박스(`com.apple.security.app-sandbox`, `files.user-selected.read-write`만, Documents 권한 없음)라 snippet 폴더(`~/Documents/finfra/fSnippetData/snippets`)에 파일시스템 직접 접근 불가(`lsof` 핸들 0). 유일한 통로인 REST API가 아이콘을 리턴하지 않아 paidApp `SnippetIconProvider`가 SF Symbol 폴백만 출력.
* 구현:
    - `cli/fSnippetCli/Data/APIModels.swift`: `APIFolderSummary`에 `var icon: String? = nil` + CodingKey `icon` (nil 시 응답 생략)
    - `cli/fSnippetCli/Managers/APIRouter.swift`: `handleGetFolders()` → `handleGetFolders(request:)`. `request.query["icons"] == "true"` 시 폴더별 `icon.png`를 `loadFolderIconDataURL`로 base64 data URL 인코딩. 기본 호출은 경량 유지(회귀 방지)
    - `api/openapi_v2.yaml`: `/folders` GET `icons` 쿼리 파라미터 + `FolderSummary`/`FolderListResponse` 스키마 신규 정의
* 선행 작업: 백업 폴더의 `Icon\r` 리소스 포크에서 icns 추출 → 현재 snippet 폴더 44개에 `icon.png`(256×256) 복원
* 검증: brew local 재배포 후 — 기본 호출 15KB(icon 없음), `?icons=true` 1.76MB(44/89 폴더 icon), AWS icon = valid PNG 39677B
* 후속: paidApp 측(메인 fSnippet 레포)에서 `?icons=true` 백그라운드 호출 + 로컬 캐시 + 기본 아이콘 폴백 구현 필요 — 메인 레포 Issue 등록·해결
* 잔여 스펙 갭: `openapi_v2.yaml`에 `FolderDetail`/`CreateFolderRequest` 등 폴더 엔드포인트 스키마가 `$ref`만 있고 정의 누락 — 별도 이슈 분리 권장

## Issue132: [Logging] cliApp 로그 파일명을 `flog_cliApp.log`로 변경 — paidApp(`flog_paidApp.log`)과 명명 대칭 (등록: 2026-05-18, 완료: 2026-05-18) (Hash: 6c2b806)
* 목적: cliApp 로그가 prefix 없는 `flog.log`로 출력되어 paidApp(`flog_paidApp.log`)과 식별 비대칭. cliApp도 `flog_cliApp.log`로 명명 통일.
* 구현:
    - `cli/fSnippetCli/Data/Logger.swift` L73: 실시간 로그 `flog.log` → `flog_cliApp.log`
    - `cli/fSnippetCli/Data/Logger.swift` L170: 세션 아카이브 `flog_{ts}.log` → `flog_cliApp_{ts}.log`
    - `cli/_tool/fsc-test.sh` L33: 테스트 LOG_FILE 경로 동기화
    - `cli/README.md`, `cli/README_ko.md`: 로그 경로 표 갱신
    - `.claude/rules/logging-rules.md`, `.claude/rules/path-rules.md`, `.claude/skills/dev/SKILL.md`: 로컬 룰·스킬 문서 동기화
* 검증: brew local 재배포 후 13:51 부팅 시 `flog_cliApp.log` + `flog_cliApp_2026-05-18_13-51-58.log` 생성, 기존 `flog.log`는 13:50에서 정지(미갱신)
* 옛 파일 정리: 사용자 수동 삭제 영역 (자동 마이그레이션 미적용 — over-engineering 회피)
* 관련: Issue884 (paidApp 로그 분리) 대칭 명명

## Issue131: [Bug/Critical] `appSetting.json` JSON 파싱 실패로 logFilter 전면 무력화 — description 내 unescaped newline (등록: 2026-05-18, 완료: 2026-05-18) (Hash: 6156c84)
* 목적: `cli/fSnippetCli/appSetting.json` `logFilter.description` 문자열에 escape되지 않은 raw newline이 포함되어 `JSONDecoder`가 파일 전체 파싱에 실패. 결과적으로 `AppSettingManager`가 `AppSetting.default`로 폴백하면서 `logFilter.enable = false`가 되어 `denyList: ["KeyEventHandler"]` 설정이 무력화됨. `KeyEventHandler.swift`의 `[Typing]` 키 타이핑 로그가 차단되지 않고 `flog.log`에 계속 출력됨.
* 근본 원인: JSON 표준(RFC 8259 §7)상 string literal 내부 unescaped newline은 invalid control character. catch 블록은 `Logger.error`만 남기고 `setting` 변경 없이 종료 → init 시점 `AppSetting.default` (enable=false) 유지 → silent failure
* 결정적 증거 (flog.log): `❌ ERROR: ⚒️ [AppSettingManager] Failed to load settings: Error Domain=NSCocoaErrorDomain Code=3840 "Unescaped control character around line 32, column 338."`
* 구현:
    - `appSetting.json` description 줄바꿈 제거 + 한 줄 통합, 오타 `Abbreviationatcher` → `AbbreviationMatcher` 교정, denyList 빈 문자열 항목 제거
    - 부수 발견: brew 배포 tarball이 `cli/fSnippetCli.app/`의 stale prebuilt app (5월 14일, appSetting.json 누락)을 그대로 패키징 중. DerivedData Release fresh app으로 교체 후 tarball 재생성
    - 검증: `python3 -m json.tool` 통과, brew local 재배포 후 cliApp 부팅 로그 82행 중 `[Typing]`/`KeyEventHandler` 출력 0건, `Failed to load settings` 부재
* 후속 검토 (별도 이슈 분리 권장):
    - Fix B (Defensive): `AppSettingManager.load()` catch에서 ① `logE` → `logC` 승격 ② JSON 파싱 실패 시 `setting.logFilter.enable = false` 명시 ③ Build-time JSON 검증 스크립트 + Pre-commit hook
    - brew tarball 구성 회귀: prebuilt app 자동 갱신 절차 부재 (수동 cp 의존)
* 관련: Issue125 (logFilter ↔ log_level 직교 가드 silent failure 카테고리), Issue126 (appSetting.json Bundle resource-only 전환 이후 첫 회귀), Issue120 (Release 빌드 사용자 가드 무력화 패턴)

## Issue124: [Test] FolderTest 33-case 회귀 실행 — 매트릭스 자체 정합성 통과 (등록: 2026-05-14, 완료: 2026-05-17) (Hash: f31b2f9)
* 목적: Issue123 복구 인프라로 33-case 매트릭스 재실행, 엔진 회귀 검증.
* 결과: **33/33 ✅** — 엔진 회귀 없음. `result_latest.md` 전 항목 통과.
* 구현:
    - `FolderTestRunnerTests.testAllFolderCases` 본격 구현: testTable_org.md 파싱 + `_rule.yml` 생성 + SnippetRepository 강제 리빌드 + 케이스별 abbreviation 검증 + 리포트 출력
    - `SingleInstanceGuard`: `XCTestConfigurationFilePath`/`XCTestBundlePath` env 감지 시 가드 비활성화 (XCTest 호스트 부팅 허용)
    - `project.yml`: `fSnippetCliTests` 빈 `CODE_SIGN_IDENTITY: ""` 제거 — Automatic 서명 상속으로 Hardened Runtime 호환
    - `Results/` gitignore 추가
* 매트릭스 ↔ 사용자 `_rule.yml` 차이 (분석만, 동기화 불필요):
    - `_case13/14/27`: matrix `{right_command}` vs user `◊` — 매트릭스가 자체 SSOT로 작동하므로 동기화 불필요 (matrix self-consistent)
    - `_case17` (matrix 존재) / `_case34` (user 존재): 환경별 case 추가 — 매트릭스 SSOT로 33-case 운영
* 후속: 엔진 회귀 발견 시 신규 이슈 분리 등록 (현재 없음)

## Issue123: [Test/Infra] FolderTest 재실행 인프라 복구 — paidApp→cliApp Facade 마이그레이션 (등록: 2026-05-14, 완료: 2026-05-17) (Hash: 698718c)
* 목적: 2026-03-26 이후 paidApp 압축 + 엔진의 cliApp Facade 재구성으로 깨진 FolderTest 33-case 재실행 인프라를 cliApp Tests로 이식. 본 이슈는 인프라 복구 + XCTest 빌드 통과까지. 실 33-case 실행·검증은 Issue124.
* plan: `cli/_doc_work/plan/folder_test_revival_plan.md`
* 채택: 옵션 B3 (SnippetRepository 테스트 후크) — Facade·Matcher 무수정, sandbox 격리 신뢰성 최고
* 변경:
    - `cli/fSnippetCli/Data/SnippetRepository.swift`: `#if DEBUG` 가드로 `swapRootForTests(_:)` + `clearSnippetMapForTests()` 추가
    - `cli/fSnippetCliTests/FolderTest/FolderTestRunnerTests.swift` 신규 (XCTestCase 스켈레톤 + setUp/tearDown)
    - `cli/fSnippetCliTests/FolderTest/FolderTestUtils.swift` 신규 (Sandbox 헬퍼)
    - `cli/fSnippetCliTests/FolderTest/testTable_org.md` 이식 (2026-03-26 기준)
* 검증: `xcodebuild -scheme fSnippetCli -configuration Debug build-for-testing` → **TEST BUILD SUCCEEDED**
* 후속: Issue124 (33-case 실 실행 + `_rule.yml` 동기화)

## Issue130: paidApp 포커스 복원 — 설정 단축키 CGEventTap pass-through (등록: 2026-05-17, 완료: 2026-05-17) (Hash: c5c3bf7)
* 목적: paidApp이 포그라운드일 때 ⌃⇧⌘; 단축키를 CGEventTap이 소비하지 않고 paidApp의 localHotkeyMonitor에 직접 전달. paidApp `.regular` 활성화 → Dock 노출, Cmd+Q 종료 가능. pairApp 구조와 일치.
* 변경:
    - `WindowContextManager`: `isPaidAppForeground` 추적 (bundleID `kr.finfra.fSnippet`)
    - `CGEventTapManager`: `isPaidAppForeground()` 프로토콜 + `settings.hotkey` pass-through
    - `KeyEventProcessor`: `isPaidAppForeground()` 구현
    - `TriggerKeyManager`: paidApp foreground 시 cliApp 설정 핸들러 스킵 (이중 오픈 방지)

## Issue129: [Bug] TriggerKeyManager NSEvent 모니터 ARC 버그 + 잘못된 설정 키 — paidApp 활성 시 설정창 단축키/메뉴 무반응 3차 재발 (등록: 2026-05-16, 완료: 2026-05-16) (Hash: cfdff95)
* 목적: paidApp이 활성화(foreground)된 상태에서 설정창 단축키(⌃⇧⌘;)와 메뉴 클릭이 작동하지 않는 문제. Issue855(paidApp AppDelegate) → Issue862(paidApp SettingsWindowManager) 재발 이후, 동일 ARC 버그 패턴이 cliApp TriggerKeyManager에 잠복해 있었음.
* 원인 1 (ARC 버그): `setupGlobalHotkeyMonitoring()`에서 `NSEvent.addGlobal/LocalMonitorForEvents()` 반환값 미저장 → ARC 즉시 해제 → 모니터 소멸 → 단축키 감지 불가
* 원인 2 (잘못된 키): `handleGlobalKeyEvent()`에서 `"settings.open.hotkey"` 참조 (존재하지 않는 키) → 매칭 항상 실패
* 구현: `private var globalHotkeyMonitor/localHotkeyMonitor: Any?` 추가, 반환값 저장, `deinit` 정리, 키 `"settings.hotkey"` 수정 (`cli/fSnippetCli/Managers/TriggerKeyManager.swift`)

## Issue128: [Clipboard/Perf] 클립보드 팝업 최신 항목 반영 지연 (3~5초) — 동적 폴링 backoff + show() 시 강제 flush 누락 (등록: 2026-05-16, 완료: 2026-05-16) (Hash: 30794af)
* 목적: 사용자가 텍스트/이미지를 복사한 직후 클립보드 히스토리 팝업(`⌃⌥⌘ ;`)을 띄우면 방금 복사한 항목이 최상단에 즉시 표시되지 않고 3~5초 후에야 반영됨. 원인은 (1) `ClipboardManager`의 동적 폴링 backoff 로직이 유휴 시 최대 10초까지 폴링 간격을 늘리고, (2) `HistoryViewerManager.show()`가 팝업 표시 직전에 `checkForChanges()`를 강제 호출하지 않아 DB가 아직 최신 변경분을 받지 못한 상태에서 `HistoryViewModel.fetchInitialDataSync()`가 실행되기 때문. 결과적으로 사용자가 "복사 → 즉시 팝업" 시퀀스를 수행할 때 시각적 지연이 발생함.
* 원인 분석 (코드 추적):
    - `cli/fSnippetCli/Managers/ClipboardManager.swift:28-30` — `currentPollingInterval=0.5s`, `minPollingInterval=0.5s`, `maxPollingInterval=10s`
    - 동 L160-181 `checkForChanges()` — 변경 없으면 `nextInterval = min(currentPollingInterval * 1.5, 10.0)` 로 backoff. 유휴 30초 후 약 7.6초 / 60초 후 10초 고정
    - 즉, "한참 만에" 복사한 직후 다음 폴링 tick까지 최대 ~10초 대기 발생. 사용자 체감 3~5초는 backoff 중간 단계(2.25/3.4/5.0초)에 해당
    - 추가로 `processCurrentPasteboard()` 는 `DispatchQueue.global(qos: .userInitiated).async` 로 비동기 실행(L171) → `ClipboardDB.shared.insertItem(item)` (L277, L334, L376) 까지 추가 지연
    - `cli/fSnippetCli/Managers/HistoryViewerManager.swift:39-159` `show()` — `viewModel!.refresh()` (L113) 만 호출. `ClipboardManager.shared.checkForChanges()` 를 깨우는 경로 없음. 따라서 DB가 최신 상태가 아닌 채로 `fetchInitialDataSync()` 가 동작
* 재현:
    1. 앱 시작 후 30초~수 분 클립보드 미사용 (backoff 가 10초까지 도달)
    2. 임의 텍스트 또는 이미지를 복사
    3. 즉시 `⌃⌥⌘ ;` 로 클립보드 팝업 열기
    4. 방금 복사한 항목이 최상단에 보이지 않음 → 1~10초 후 (다음 폴링 tick + DB insert + 다음 사용자 갱신 시점) 반영
* 구현 명세 (제안 — plan 단계에서 확정):
    1. **즉시 flush 후크 추가**: `HistoryViewerManager.show()` 의 `viewModel!.refresh()` 호출 직전에 `ClipboardManager.shared.flushPendingChange()` (신규 public 메서드) 를 호출. 내부적으로 `pasteboard.changeCount != lastChangeCount` 인 경우 **동기적으로** `processCurrentPasteboard()` 를 실행하여 DB insert 까지 완료시킨 뒤 리턴. 이후 `viewModel!.refresh()` 가 DB 에서 최신 상태를 읽도록 보장
    2. **폴링 간격 즉시 리셋**: flush 후 `scheduleNextPoll(interval: minPollingInterval)` 호출하여 backoff 0.5초 로 복귀
    3. **동기 처리 위험성 검토**: 이미지/대용량 파일 list 의 경우 메인 스레드에서 처리하면 팝업 지연이 발생할 수 있으므로 옵션 A(완전 동기) vs 옵션 B(메인 스레드 빠른 changeCount 갱신 + 백그라운드 insert + DB insert 완료를 기다리는 짧은 `DispatchSemaphore.wait(timeout: 0.3)`) 중 plan 에서 결정
    4. **NSApp.willBecomeActive 옵션 (보조)**: 향후 패스트보드 변경 감지를 OS 이벤트 기반으로 보강할지 검토 (현재 backoff 의존도 자체를 줄이는 방향)
* 검증:
    - 시나리오 1: 1분 유휴 후 즉시 복사 → 팝업 → 최상단 표시 0.3초 이내
    - 시나리오 2: 이미지 5MB 복사 → 팝업 → 표시 1초 이내 (옵션 B 채택 시)
    - 시나리오 3: 연속 5회 복사 후 팝업 → 모두 정확한 순서로 반영
    - flog.log 에 `📋 [HistoryViewModel] fetchHistory done` 직전 `📋 flush on show` 로그 1줄 추가
* 복잡도: **중간** — `ClipboardManager` public API 1건 추가 + `HistoryViewerManager.show()` 1줄 호출. 동기 vs 비동기 트레이드오프 결정 필요. plan 작성 권장
* 관련 영역: `cli/fSnippetCli/Managers/ClipboardManager.swift` (flushPendingChange 신규), `cli/fSnippetCli/Managers/HistoryViewerManager.swift:113` (호출 추가)
* 의존: 없음
* 후속: 사용자 환경에서 backoff 최대값(10s) 자체 조정이 필요할 경우 별도 이슈

## Issue127: [Regression] 기본 단축키(⌘S 등) 글로벌 등록 차단 회귀 — context-only 면제 박제 + 시작 시 검출 누락 (등록: 2026-05-16, 완료: 2026-05-16) (Hash: e78f9da)
* 목적: 기본 단축키(⌘S, ⌘C, ⌘V 등 macOS 표준 19종)가 cliApp 글로벌 hotkey 로 등록되어 macOS 표준 동작과 충돌. archive 라인업 Issue90 + Issue94 + Issue96_2 (`_doc_work/issue_OLD.md`) 에서 `ShortcutBlacklist` + `tryRegister()` 가드로 해결했으나 Issue115/116 의 context-only 면제 도입 + paidApp 외부 박제값으로 회귀. 앱 시작 시 검출 + 등록 거부 + 일괄 NSAlert 흐름 복구.
* archive 참조:
    - Issue90: `ShortcutBlacklist` 도입 + `tryRegister()` 가드 (19종 정의 — `ShortcutBlacklist.swift:26-46`)
    - Issue94: 차단 단축키 일괄 NSAlert + `blockedShortcutsBuffer`
    - Issue96_2: ⌘⇧S/⌘D/⌘E/⌘G 추가
    - Issue115 (3d236c3): `ConfigMigration` 측 context-only 면제 (`contextOnlyHotkeyKeys`) — 회귀 원인
    - Issue116 (d36c9d8): `ShortcutMgr.tryRegister()` 측 동일 면제 — 회귀 원인
* 회귀 원인 (확인됨):
    - **컨텍스트 면제 우회 경로**: `Issue115/116` 의 `contextOnlyHotkeyKeys` 면제로 `history.registerSnippet.hotkey: "{⌘S}"` / `history.preview.hotkey` 등이 `ShortcutBlacklist.isReserved()` 검사 우회 — 그대로 글로벌 등록됨
    - **사용자 _config.yml 박제**: Issue87 이전 default `⌘S` 시점에 박제된 값이 자동 정리 안 됨 (위 면제 때문)
    - **폴더 단축키 경로 미가드**: `registerFolderShortcuts()` 는 `tryRegister()` 미경유 → 폴더 prefix/suffix 가 `{⌘S}` 등으로 설정되면 무차단 등록
* 구현 명세:
    - **수정 1 — ConfigMigration**: `contextOnlyHotkeyKeys` 면제 제거 (L30-38, L109-114). 시스템 예약 매칭 시 컨텍스트 hotkey 라도 빈값으로 정정 + 백업. 박제된 `{⌘S}` 자동 정리
    - **수정 2 — ShortcutMgr.tryRegister()**: `isContextOnly` 가드 제거 (L368-377). `ShortcutBlacklist.isReserved()` 매칭이면 일괄 등록 거부
    - **수정 3 — registerFolderShortcuts()**: `tryRegisterFolder()` 헬퍼 추가. 폴더 prefix/suffix 가 예약 키 매칭 시 등록 거부 + `blockedShortcutsBuffer` 수집
    - **수정 4 — refreshAll() NSAlert 통합**: 차단 버퍼 비움 + NSAlert 호출을 `refreshAll()` 로 이동. app global + folder 차단 누적 후 사이클 종료 시 일괄 1회 표시
* 검증:
    - Release 빌드 PASS (`** BUILD SUCCEEDED **`)
    - SourceKit 진단 10건 false positive (실제 컴파일 통과)
    - 사용자 환경 검증은 brew 재배포 후 별도 확인
* 수정 파일: `cli/fSnippetCli/Data/ConfigMigration.swift`, `cli/fSnippetCli/Managers/ShortcutMgr.swift`

## Issue126: [Path/Leak] `appSetting.json` Release 환경 누출 — 사용자 데이터 폴더에 `_data/` 자동 생성 (등록: 2026-05-15, 완료: 2026-05-15) (Hash: 288849b)
* 목적: `appSetting.json`은 DEBUG/개발 전용 Bundle 리소스인데 Release(brew) 환경에서 `~/Documents/finfra/fSnippetData/_data/appSetting.json`을 자동 생성하여 사용자 데이터 폴더를 오염시킴. Issue122 SSOT 통합 직후 사용자 환경 검증 중 발견된 인접 누출 패턴.
* plan: `cli/_doc_work/plan/appsetting-release-isolation_plan.md`
* 근본 원인:
    - `AppSettingManager.getJSONFileURL()` Release 분기(L244-281)가 cwd가 "fSnippet" 미포함 시 `~/Documents/finfra/fSnippetData/_data/` 폴백 후 `FileManager.createDirectory(... withIntermediateDirectories: true)`로 디렉토리·파일 자동 생성
    - brew/launchd 환경의 cwd는 fSnippet 미포함이라 항상 폴백 분기 진입 → 사용자 폴더 누출
    - 추가 발견(T1): Xcode pbxproj에 `_data/appSetting.json` Bundle Resources 참조 0건 — `.app/Contents/Resources/_data/` 미존재. 현재 사용자 폴더 파일 = `AppSetting.default`(빈 값) 그대로 직렬화. 의도된 풍부한 값(`bufferClearKeys.keys`, `logFilter.denyList` 등)은 이미 작동 안 함
* 해결:
    - **T2**: `getJSONFileURL()` Release 분기 제거. `Bundle.main.url(forResource: "appSetting", withExtension: "json")` 단일 호출로 단순화. `PreferencesManager`의 `_config.yml`·`_rule.yml` 로드 패턴과 동일
    - **T3**: `save()`에 `#if DEBUG` 가드 추가. Release에서는 verbose 로그만 출력하고 디스크 쓰기 0건
    - `dataDirectory = "_data"` 상수 제거. cwd 추론·`createDirectory` 호출 모두 폐기
* 검증 (T4 통합):
    - `rm -rf ~/Documents/finfra/fSnippetData/_data` + `brew services restart fsnippet-cli` + 5초 대기 → `ls _data` = `cannot access` (재생성 안 됨, 핵심 합격 조건 통과)
    - Release brew 9 PASS / 0 FAIL
    - `RuleManager` DEBUG 로그 정상 출력 (Logger.shouldLog 회귀 없음)
    - v2 `GET /api/v2/settings/general/paths` 응답 `settingsFolder` 유지 (Issue122 SSOT 보존)
* 수정 파일:
    - `cli/fSnippetCli/Managers/AppSettingManager.swift` (`getJSONFileURL`·`save`·`dataDirectory` 상수)
* 후속 검토 후보 (별도 이슈 필요):
    - Xcode pbxproj에 `_data/appSetting.json`을 Copy Bundle Resources 단계에 추가 → 풍부한 값(`bufferClearKeys`, `logFilter.denyList` 등) 실제 작동 복원. 본 plan 범위 외이며, 추가 시 다른 fallback(`BufferClearKeyManager` 자체 기본값)과 우선순위 정리 필요

## Issue122: [Path/SSOT] `appRootPath` 해석기 3중 분기 — UserDefaults SSOT 깨짐, `defaults write` / API PATCH 미반영 (등록: 2026-05-14, 완료: 2026-05-15) (Hash: e151239)
* 목적: `path-rules.md §3`가 명시한 "UserDefaults `appRootPath` = SSOT, 하드코드는 초기 시드" 원칙이 깨져 있음. 사용자가 `defaults write kr.finfra.fSnippetCli appRootPath <path>` 하거나 REST API로 settingsFolder를 PATCH 해도 메인 엔진(Logger·SettingsManager·SnippetFileManager·AppSettingManager)이 변경값을 읽지 못함. 데이터 폴더 변경 기능 회복 + 단일 SSOT 통일.
* plan: `cli/_doc_work/plan/settings-folder-resolve_plan.md`
* task: `cli/_doc_work/tasks/settings-folder-resolve_task.md`
* design: `cli/_doc_arch/settings-folder-resolve.md`
* 근본 원인:
    - 3개 해석기 분기 공존: `PreferencesManager.resolveAppRootPath()` (ENV → 하드코드, UserDefaults 미참조) / `PaidAppStateLogger.resolveAppRootPath()` (UserDefaults → 하드코드, 단독 분리) / `APIRouter.currentSettingsFolder()` (`_config.yml` `app_root_path` → 하드코드)
    - 메인 엔진은 ①번을 호출하므로 ②·③의 사용자 변경값을 무시
    - 설계 의도(UserDefaults SSOT)와 코드가 불일치 — 설계 문서 `cli/_doc_arch/settings-folder-resolve.md` L42에 원칙은 이미 명시되어 있었으나 ①번이 키 조회 한 줄을 누락
* 해결:
    - **T1**: `PreferencesManager.resolveAppRootPath()` 재작성 — ENV(`fSnippetCli_config`, 테스트/CLI 오버라이드) → UserDefaults `appRootPath` → 시드(1회 영속화) 순. 시드 분기에서 `UserDefaults.standard.set(seed, ...)`로 영속화하여 이후 호출에서 UserDefaults 경로로 통일됨
    - **T2**: `APIRouter` 3곳 정정 (`buildV2General`·`handleV2PatchGeneral`·`handleV2PatchGeneralPaths`). `settingsFolder` 쓰기는 `UserDefaults.standard.set(_:forKey:"appRootPath")` 직접 호출로 변경. `_config.yml` `app_root_path` 사용 중단
    - **T3**: `PaidAppStateLogger.resolveAppRootPath()` 본문을 게이트웨이 위임으로 정정. `testableDefaultsOverride` 분기는 단위 테스트 격리용으로 보존 (게이트웨이로 hook hoisting은 후속 작업)
    - **T4**: `ConfigMigration.migrateAppRootPath(at:)` 추가 + `PreferencesManager.loadConfigInternal()`에서 호출. `_config.yml`에 `app_root_path` 키가 있고 UserDefaults가 비어있으면 1회 이전 후 YAML 키 제거. idempotent (외부 도구가 키 재추가해도 다음 부팅 자동 정리)
    - **T6**: `_public/.claude/rules/path-rules.md` §3.1 "우선순위 (Issue122)" 신규 + `_public/api/openapi_v2.yaml` `/settings/general/paths` GET/PATCH `settingsFolder` description에 SSOT 위치 명시
* 검증:
    - Release 빌드 5회 통과 (`** BUILD SUCCEEDED **` 매 task 단위)
    - 잔존 `app_root_path` 코드 hit 0건 (마이그레이션 로직 내부만)
    - brew 재배포(`/run`) 후 SSOT 1차 검증 통과: UserDefaults `appRootPath` = `/Users/nowage/Documents/finfra/fSnippetData`, REST `GET /api/v2/settings/general/paths` 응답 `settingsFolder` 동일, 새 바이너리 mtime 2026-05-15 09:54 확인
    - 시나리오 A/B/C(`defaults write` / v2 PATCH / ENV) 수동 dry-run은 task 파일에 명령어 명시. 회귀 발견 시 후속 등록
* 수정 파일:
    - `cli/fSnippetCli/Data/PreferencesManager.swift` (게이트웨이 재작성 + 마이그레이션 호출)
    - `cli/fSnippetCli/Data/PaidAppStateLogger.swift` (자체 함수 본문 위임으로 정정)
    - `cli/fSnippetCli/Data/ConfigMigration.swift` (`migrateAppRootPath` 추가)
    - `cli/fSnippetCli/Managers/APIRouter.swift` (3곳 정정)
    - `_public/api/openapi_v2.yaml` (settingsFolder description)
    - `_public/.claude/rules/path-rules.md` (§3.1 추가)
* 인접 발견:
    - Issue126 (📕 중요): `appSetting.json`이 Release 환경에서 사용자 데이터 폴더에 누출 — Issue122 검증 중 부수 발견. 동일 SSOT 게이트웨이 우회 패턴

## Issue125: [Logging/Bug] `logFilter.enable: false` 인데 RuleManager 등 일부 모듈 로그 누락 — logFilter ↔ log_level 직교 가드 책임 경계 불명확 (등록: 2026-05-14, 완료: 2026-05-14) (Hash: 1449700)
* 목적: `appSetting.json` 의 `logFilter.enable: false` 설정 시 사용자는 **모든 모듈 로그(타이핑·RuleManager·AbbreviationMatcher 포함)가 출력되리라 기대**. 그러나 실제로는 `RuleManager`, `AbbreviationMatcher` 등 denyList에 포함되어 있던 모듈 로그가 여전히 출력되지 않음. logFilter 가 제대로 비활성화돼도 log_level 가드가 별도로 적용되어 누락 발생. 사용자 멘탈 모델과 실제 동작 정렬.
* 사용자 보고 (2026-05-14):
    > `cli/fSnippetCli/_data/appSetting.json` L20 `"enable": false` 이면 필터링 안 되어 타이핑 로그(및 denyList 모듈 로그)가 나와야 하는데 안 나옴.
* 근본 원인 (코드 분석):
    - `AppSettingManager.shouldLog(file:)` (`cli/fSnippetCli/Managers/AppSettingManager.swift:109-126`) 정상 동작:
        ```swift
        guard setting.logFilter.enable else { return true }   // L110 — enable:false → 즉시 통과
        ```
        → logFilter 자체는 모든 모듈 통과 (denyList 무시)
    - 그러나 전역 `logV`/`logD`/`logI`/... 함수 (`cli/fSnippetCli/Data/Logger.swift:562-607`) 는 2단 가드:
        1. `AppSettingManager.shared.shouldLog(file:)` — logFilter 가드 (enable=false 시 통과)
        2. `logger.verbose(message)` 내부의 `currentLogLevel.rawValue <= LogLevel.verbose.rawValue` — **log_level 가드 (별도)**
    - 현재 환경: `_config.yml` `log_level: "DEBUG"` (= rawValue 1)
    - `RuleManager` 의 모든 핵심 로그가 `logV` (= VERBOSE, rawValue 0) 로 작성됨:
        * L57 `Cache Invalidated due to notification`
        * L144 `규칙 파일 변경 감지 - 재로드 시작`
        * L165 `YAML 파일 내용`
        * L211 `규칙 파일 로드 성공: N개 컬렉션`
        * L245/252/259/266 `[SECTION] xxx 섹션 진입`
        * L326+ parse 상세
    - 결과: logFilter 우회됨에도 log_level 가드에서 VERBOSE 컷 → **"logFilter.enable=false인데도 RuleManager 로그 안 나옴"** 으로 인지
* 설계 모호성:
    - logFilter (`enable`/`mode`/`allowList`/`denyList`) = "**어떤 모듈** 의 로그를 보는가" — 모듈 차원 필터
    - log_level = "**얼마나 상세하게** 로그를 보는가" — 상세도 필터
    - 두 가드는 직교적이나, `logFilter.enable: false` 의미가 "필터 없음 = 다 보임" 으로 해석되어 사용자 직관과 충돌
* 구현 명세 (옵션 비교):
    | 옵션                                                                     | 변경 범위                                                                                                              | 부작용                                                                           | 권장           |
    | :----------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------- | :------------- |
    | **A. RuleManager 핵심 로그 logV → logD 승격**                            | RuleManager.swift 가시성 필요 logV (L57/L144/L211/[SECTION] 등) → logD 5~8건                                           | DEBUG 레벨에서 모듈 가시성 회복. Issue119 패턴 (CGEventTapManager 3건 승격 선례) | ⭐ 1순위        |
    | B. `logFilter` 에 `forceAllLevels: true` 도입 → log_level 가드 우회 모드 | `LogFilterConfig` 신규 필드 + 전역 `logV`/`logD` 함수가 플래그 체크 시 level 가드 스킵                                 | 의미 복잡화. 무한 verbose 위험. 디버깅 전용 의도 명시 필요                       | 2순위 (선택적) |
    | C. 문서 명확화                                                           | `appSetting.json description` 갱신 + `cli/.claude/rules/logging-rules.md` 에 "logFilter 와 log_level 직교성" 섹션 추가 | 코드 무수정. 사용자 기대치 정렬                                                  | 동반 적용      |
    - **권장**: 옵션 A + C 동반 적용
        * A: RuleManager 핵심 로그(`Cache Invalidated`, `규칙 파일 변경 감지`, `규칙 파일 로드 성공`, `[SECTION] xxx`) 약 5~8건 logV → logD 승격. 노이즈 통제를 위해 L165 `YAML 파일 내용 전체` 같은 대용량은 logV 유지
        * AbbreviationMatcher 동일 분석 후 핵심 로그 logV → logD 승격 (적용 범위 plan 단계에서 확정)
        * C: `appSetting.json` description 갱신 + `logging-rules.md` 직교성 섹션 추가
* 검증:
    - `_config.yml log_level: "DEBUG"` + `appSetting.json logFilter.enable: false` 조합에서:
        * Release 빌드 + brew 재배포 후 RuleManager 핵심 로그가 `flog.log` 에 `🐛 DEBUG:` 레벨로 출력
        * 사용자 호소("RuleManager 로그 안 나옴") 해소 여부 직접 검증
* 사용자 가설 ("폴더 수정 영향") 검토:
    - Issue123 변경(SnippetRepository `#if DEBUG` 후크, FolderTest 신규 디렉터리, PaidAppAPIRouterTests fix) 모두 **Release 바이너리에 미반영**
    - `AppSettingManager` 로드 로직(L231-236) 은 "소스 디렉토리 → Bundle resource" 순. brew 바이너리는 Bundle 사용. 신규 `FolderTest/` 는 `fSnippetCli` 앱 타겟 sources 미포함 → Bundle 영향 없음
    - **결론**: 폴더 수정 영향 아님. log_level 가드 단독 문제
* 복잡도: **중간** — 옵션 A logV→logD 승격은 작지만 정책 결정(어느 로그 승격) 필요. 옵션 C 문서 보강 동반. plan 작성 권장.
* 관련 영역: `cli/fSnippetCli/Data/RuleManager.swift`, `cli/fSnippetCli/Core/AbbreviationMatcher.swift`, `cli/fSnippetCli/_data/appSetting.json`, `cli/.claude/rules/logging-rules.md`
* 의존: 없음
* 후속: 옵션 B (forceAllLevels 모드) 채택 시 별도 이슈
* 해결 (옵션 A + C 동반):
    - **옵션 A — logV → logD 승격 8건**:
        * `cli/fSnippetCli/Data/RuleManager.swift` 7건: L57 `Cache Invalidated` / L144 `규칙 파일 변경 감지` / L211 `규칙 파일 로드 성공: N개 컬렉션` / L459 `[ENHANCED_LOAD] 마지막 매핑 로드 성공` / L796 `Cache Miss - Recalculating Effective Rules` / L922 `Recalculation took` / L959 `_rule.yml 로드 성공`
        * `cli/fSnippetCli/Core/AbbreviationMatcher.swift` 1건: L66 `완전 일치 스니펫 발견`
        * 승격 제외 (빈번/노이즈): YAML 내용 dump (L165), COLLECTION_PARSE 라인별 (L411+), SUFFIX_MAPPING (L1004), SECTION 진입 4건 (L245/252/259/266)
    - **옵션 C — 문서 명확화**:
        * `cli/fSnippetCli/_data/appSetting.json` description 갱신 — log_level 가드와 직교성 명시 (gitignored였던 _data/ 도 본 커밋에서 추적 시작)
        * `_public/.claude/rules/logging-rules.md` 신규 — 2단 가드 구조·직교성·디버깅 가이드 (gitignored 로컬 SSOT)
    - 옵션 B (`forceAllLevels` 모드)는 본 라운드 미채택. 필요 시 별도 이슈
* 검증:
    - Release 빌드 통과 (`** BUILD SUCCEEDED **`)
    - brew 재배포 9/9 PASS (`/run` skill)
    - `flog.log` (15:46:47) 에서 `_config.yml log_level: "DEBUG"` + `logFilter.enable: false` 조합으로 RuleManager 핵심 로그가 `🐛 DEBUG:` 레벨로 출력 확인:
        * `규칙 파일 변경 감지 - 재로드 시작`
        * `규칙 파일 로드 성공: 43개 컬렉션`
        * `[RuleManager] _rule.yml 로드 성공`
        * `[RuleManager] Cache Invalidated due to notification`
    - 사용자 호소 ("logFilter.enable=false 인데 RuleManager 로그 안 나옴") 해소
* 수정 파일:
    - `cli/fSnippetCli/Data/RuleManager.swift` (logV→logD 7건)
    - `cli/fSnippetCli/Core/AbbreviationMatcher.swift` (logV→logD 1건)
    - `cli/fSnippetCli/Managers/AppSettingManager.swift` (주석 경로 정정)
    - `cli/fSnippetCli/_data/appSetting.json` (신규 추적 + description 갱신)
    - `_public/.claude/rules/logging-rules.md` (신규, gitignored — 로컬 SSOT)

## Issue121: [Cleanup] `_setting.yml` legacy 파일 잔존 — 자동 정리 마이그레이션 추가 (등록: 2026-05-14, 완료: 2026-05-14) (Hash: 8443022)
* 목적: `~/Documents/finfra/fSnippetData/_setting.yml`가 사용자 환경에 잔존하여 "자꾸 생성됨"으로 인지됨. Issue117(2026-05-10, hash 7ee78e9)에서 `SettingYmlLoader` 제거 + `_config.yml` SSOT 단일화 완료 후, 현재 바이너리는 이 파일을 생성·참조하지 않으나 **이전 버전이 만든 잔존물 자동 정리 절차가 누락**됨. 실제 파일은 2026-05-13 19:25 mtime으로 고정(자동 재생성 없음, atime만 갱신).
* 근본 원인:
    - 현재 cliApp 바이너리(`/opt/homebrew/opt/fsnippet-cli/...`, mtime: 2026-05-13 20:03) `strings` 검사 결과 `_setting.yml`/`settings_hotkey:`/`SettingYmlLoader` 모두 미참조
    - paidApp(`_org_before_cli/fSnippet.zip`) 바이너리도 미참조 + 현재 미실행
    - `_setting.yml` 내용: 단축키 1줄(`settings_hotkey: "^⇧⌘,"`) — `_config.yml`의 `settings.hotkey`로 이미 대체됨
    - 사용자가 파일을 삭제해도 다음 번 바이너리 업데이트 후에 잔존물 자동 정리 절차가 없어, 한 번이라도 구버전이 실행됐다면 파일이 남아 있음
* 해결:
    - `cli/fSnippetCli/Data/ConfigMigration.swift`:
        * `legacyFileNames` 정적 셋 신설 (현재 `_setting.yml` 1건, 향후 확장 가능)
        * `removeLegacyFiles(in directory:)` 정적 메서드 추가 — 발견 시 `<name>.legacy_<yyyyMMdd-HHmmss>` 으로 rename(백업 보존), 미존재 시 silent skip (idempotent)
    - `cli/fSnippetCli/Data/PreferencesManager.swift`:
        * `loadConfigInternal()` 진입부 `ConfigMigration.migrate()` 호출 직전에 `ConfigMigration.removeLegacyFiles(in: dataDir)` 호출 추가
        * 정리 발생 시 `⚙️ [Preference] Issue121 legacy files cleaned: N file(s)` INFO 로그
* 검증:
    - Release 빌드 성공 (`** BUILD SUCCEEDED **`)
    - brew 재배포(`/brew-apply` skill) + 서비스 시작 후:
        * `ls _setting.yml` → No such file (자동 삭제됨)
        * `ls _setting.yml.legacy_20260514-050315` → 백업 보존 확인
        * 로그: `[ConfigMigration] Legacy file removed: _setting.yml → _setting.yml.legacy_20260514-050315` + `[Preference] Issue121 legacy files cleaned: 1 file(s)`
    - `brew services restart` 재기동 후 추가 로그 없음 → **idempotent 정상 작동** 확인
* 수정 파일:
    - `cli/fSnippetCli/Data/ConfigMigration.swift` (legacyFileNames 셋 + removeLegacyFiles 메서드)
    - `cli/fSnippetCli/Data/PreferencesManager.swift` (loadConfigInternal에서 호출)
* 영향:
    - 향후 다른 폐기 파일(예: `config.yaml` 같은 legacy) 발생 시 `legacyFileNames`에 한 줄만 추가하면 자동 정리됨 — 확장 가능한 SSOT 구조

## Issue120: [Logger] `Logger.debug()` / `verbose()` 가 Release 빌드에서 `#if DEBUG` 가드로 무력화 — `_config.yml log_level` SSOT 깨짐 (등록: 2026-05-13, 완료: 2026-05-13) (Hash: d955324)
* 목적: `_config.yml` 의 `log_level: "DEBUG"` 설정이 Release 빌드(brew binary)에서 무시되어 `logD` / `logV` 호출이 모두 무력화. Issue119 fix(logV→logD 4건)도 Release 환경에서 효과 없었음. 설정 SSOT 회복.
* 근본 원인:
    - `cli/fSnippetCli/Data/Logger.swift` 의 `debug()` / `verbose()` 함수 본문 전체가 `#if DEBUG ... #endif` 컴파일 분기에 갇혀 있었음. Release 빌드 시 컴파일 자체에서 제거 → `currentLogLevel` 가드를 통과해도 출력 코드가 존재하지 않음
    - `warning()` / `error()` / `critical()` 은 `#if DEBUG` / `#else` 양쪽에 출력 처리(콘솔 print vs `os_log`)를 두어 Release에서도 동작했으나, debug/verbose만 `#else` 분기 없음 → Release 침묵
    - 결과: 사용자가 `log_level: "DEBUG"` 로 명시해도 brew binary 사용 시 logD 한 줄도 안 보임. Issue118 진단·Issue119 trace 강화·향후 회귀 분석 모두에 치명적
* 해결:
    - `Logger.debug()` / `Logger.verbose()` 본문 재배치:
        * `let logMessage = "..."` 메시지 구성은 가드 밖으로 이동
        * `print(logMessage)` 콘솔 출력은 `#if DEBUG` 안에 유지 (Release 보안)
        * `writeToLogFile(...)` 파일 쓰기는 가드 밖으로 이동 — Release에서도 호출
    - 파일 쓰기는 `writeToLogFile` 내부의 `isFileLoggingEnabled` 가드 ( = `_config.yml` 의 `debug_logging` 마스터 스위치) + Logger 레벨 가드(`currentLogLevel.rawValue <= ...`)가 이중 제어. spam 위험 없음
* 검증:
    - Release 빌드 + brew 재배포 후 신규 로그(`flog_2026-05-13_20-03-59.log`) 에서 `🐛 DEBUG:` 출력 5건 즉시 확인:
        * `[brew-sync] onAppStart skip` / `🌫️ 플레이스홀더 입력창 표시됨` / `🔔 [ChangeTracker]` / `🌐 API 요청: GET /` ×4
    - Fix 전 동일 환경에서는 `🐛 DEBUG:` 0건 → SSOT 회귀 정확히 해결됨
* 수정 파일:
    - `cli/fSnippetCli/Data/Logger.swift` (L336-358 debug/verbose 함수 본문 재배치)
* 영향:
    - Issue118·Issue119 의 trace logD 가 이제 Release 빌드에서도 정상 출력 → 사용자 호소 "타이핑 로그가 안 찍힘" 근본 해결
    - 향후 `logD` 사용 시 `_config.yml log_level` 설정만 적절히 두면 production 환경에서도 추적 가능

## Issue119: [Logging] 키 타이핑 trace 로그가 DEBUG 레벨에서 충분히 출력되지 않음 (등록: 2026-05-13, 완료: 2026-05-13) (Hash: c9c4308)
* 목적: CGEventTap callback의 트리거 매칭 흐름(`Registered Shortcut Detected`, `Fallback Trigger`, `Option Mapping`, modifier release fallback skip) 이 모두 `logV` 였던 탓에 `log_level: "DEBUG"` 에서도 trace 누락. Issue118 진단 과정에서 callback 진입·실패 경로 추적이 어려워 회귀 진단 부담이 큼. 핵심 trace 위치를 `logD` 로 이관하여 디버깅 가시성 확보.
* 해결:
    - `cli/fSnippetCli/Core/CGEventTapManager.swift` 3건 logV → logD:
        * `Registered Shortcut Detected (Blocking): {keySpec} [{type}]` — 통합 단축키 검출
        * `Passing through Fallback Trigger: {char} (Code: {keyCode})` — fallback 트리거 통과
        * `Option Mapping (SSOT): {mappedChar} (Pass-through allowed)` — Option 매핑 suffix
    - `cli/fSnippetCli/Core/KeyEventProcessor.swift` 1건 logV → logD:
        * `[Issue 603] Modifier Key Release ({keyCode}) - Skipping Trigger Fallback` — modifier 키 release 시 fallback 매칭 차단 (modifier 트리거 처리 흐름 추적 핵심)
* 검증:
    - Issue118 fix 검증 과정에서 동일 binary로 로그 확인. Right Command 누름·매칭·pending 설정 흐름이 모두 INFO/DEBUG 레벨로 trace 가능함.
    - `key_logging: true` (별도 KeyLogger 프로세스로 모든 키 이벤트를 `/tmp/fkey.log` 기록) 및 `log_level: "VERBOSE"` 옵션은 `cli/.claude/rules/logging-rules.md` 가이드 유지.
* 수정 파일:
    - `cli/fSnippetCli/Core/CGEventTapManager.swift`
    - `cli/fSnippetCli/Core/KeyEventProcessor.swift`
* 부수 정리: Issue118 임시 진단 logI(`[Issue865/...]`) 3건 제거 (production 깨끗 + git history + debug_TECH.md 로 회귀 추적 가능)

## Issue118: [Critical/Bug] KeyCaptureManager hot-path 회귀 — CGEventTap timeout 빈발로 트리거 키 산발적 작동 (등록: 2026-05-13, 완료: 2026-05-13) (Hash: c9c4308)
* 목적: commit 4fb2403(Issue863 key-capture REST API)이 도입한 CGEventTap callback 분기가 매 키 이벤트마다 `NSEvent(cgEvent:)` 생성 + `NSLock` 점유를 무조건 실행하여 callback 처리 시간이 macOS의 tap timeout 임계를 초과 → `kCGEventTapDisabledByTimeout` 잦은 발생 → 트리거 키(`{right_command}`) 가 대부분 작동 안 함. 회귀 차단.
* 근본 원인:
    - `CGEventTapManager.handleCallback` L201-211 의 KeyCaptureManager 분기가 idle/pending 무관하게 항상 NSEvent 생성 + NSLock 점유
    - 누적된 callback 비용이 macOS `kCGEventTap` 내부 timeout 임계 초과 → OS가 자동 disable
    - modifier 트리거는 누름·뗌 두 flagsChanged 이벤트가 모두 정확히 callback에 도달해야 FIRE되므로 손실에 더 취약 → "트리거 키만 안 됨" 으로 체감
* 해결:
    - `KeyCaptureManager` 에 lockless fast-path 플래그 `_isPendingFast` 도입. `startCapture()`/`stopCapture()`/`captureKeyIfActive(captured|timeout)`/`result(timeout)` 모든 state 전이에서 동기 갱신.
    - 공개 read-only getter `isPendingFast` 추가 (NSLock 미점유)
    - `CGEventTapManager.handleCallback` 의 KeyCaptureManager 분기를 `if KeyCaptureManager.shared.isPendingFast, ...` 로 게이팅 → idle 99% 케이스에서 NSEvent 생성 자체 회피
    - 트리거 흐름 추적 강화: `Registered Shortcut Detected`, `Passing through Fallback Trigger`, `Option Mapping (SSOT)` 3건의 logV → logD
* 검증:
    - Fix 전: brew 재배포 후 30분간 진단 logI(`[Issue865/...]`) **0건 출력** + `Event Tap Disabled` 6회
    - Fix 후 동일 환경에서:
        * Right Command 누름 시 진단 logI 3건(`CGEventTap`/`IsTriggerKey`/`Match`) 정상 출력
        * `Match: significant=0x100010 stored=0x100010 eq=true` — modifier 매칭 성공 확인
        * `Pending Modifier Trigger Set: 54` — pending 정상 설정
        * `Event Tap Disabled` 빈도 감소, 트리거 키 사용자 검증 완료 ("해결됨")
* 수정 파일:
    - `cli/fSnippetCli/Managers/KeyCaptureManager.swift` — `_isPendingFast` 플래그 추가
    - `cli/fSnippetCli/Core/CGEventTapManager.swift` — fast-path 게이팅 + logV→logD 3건
* 부수 발견:
    - Right Command 떼는 flagsChanged 이벤트 callback 도달 추적은 별도 회귀 검토 필요 (현 fix로 트리거는 회복했으나 trace 가시성 부족) → Issue119 로 분리
* 참고 문서:
    - `cli/_doc_base/debug_TECH.md` — "CGEventTap callback hot-path 비용 → tap timeout 빈발 ..." 사례 등록

## Issue117: [Critical/Bug] Accessibility 권한 런타임 박탈 시 시스템 슬로다운 — 감지·알림·종료 절차 도입 (등록: 2026-05-10, 완료: 2026-05-10) (Hash: 7ee74e9)
* 목적: 시스템 설정에서 fSnippetCli.app의 접근성 권한을 박탈하면 `CGEventTap` 재시도 루프(`handleTapDisabled` backoff)가 메인 큐를 점유하여 시스템 전반이 급격히 느려지던 회귀를 차단. 박탈 즉시 NSAlert로 안내 후 앱 자체 종료.
* 근본 원인:
    - 기존 `checkAccessibilityPermission()`은 시작 시 1회 검사 + grant-only 폴링(`startAccessibilityPolling`, 최대 10분)만 가동 — **revoke 전이 감지 경로 부재**
    - 권한 박탈 → CGEventTap 비활성화 → `handleTapDisabled` 재시도 루프(0.1×N backoff → cooldown 후 재귀 재시도)가 무한 반복 → 메인 큐 점유 → 시스템 입력/렌더링 지연
* 해결:
    - `accessibilityPollingTimer` (grant-only) → `accessibilityMonitorTimer` (양방향)으로 통합
    - `lastAccessibilityTrusted` 상태 추적 → grant(`false→true`)·revoke(`true→false`) 전이 모두 감지
    - 시작 상태(승인/미승인)와 무관하게 모니터 가동
    - 신규 `handleAccessibilityRevoked()`:
        1. `KeyEventMonitor.stopMonitoring()` + `cleanup()` → CGEventTap 재시도 루프 차단 (slowdown 방지의 핵심)
        2. `NSAlert` 표시 (`.critical` 스타일, [시스템 설정 열기] [종료])
        3. `NSApplication.shared.terminate(nil)` — 응답과 무관하게 자체 종료
    - `ko.lproj/Localizable.strings`에 키 3개 추가 (`Accessibility Permission Revoked`, 본문, `Quit`)
* 검증: Release 빌드 통과 (`** BUILD SUCCEEDED **`)
* 수정 파일:
    - `cli/fSnippetCli/fSnippetCliApp.swift`
    - `cli/fSnippetCli/ko.lproj/Localizable.strings`
* 부수 변경 (한 커밋 통합):
    - `Managers/SettingsWindowManager.swift` — `SettingYmlLoader` 제거 (`_config.yml` SSOT 단일화)
    - `Core/AppActivationMonitor.swift` — 윈도우 전환 verbose 로그 제거
    - `cli/fSnippetCli.xcodeproj/` — Xcode 자동 권장 빌드 설정 업그레이드 (`DEAD_CODE_STRIPPING` 등)

## Issue116: [ShortcutMgr] 컨텍스트 hotkey 등록 거부 면제 (Issue115 페어) (등록: 2026-05-10, 완료: 2026-05-10) (Hash: d36c9d8)
* 목적: Issue115에서 `ConfigMigration`은 컨텍스트 hotkey 정리 면제했으나, `ShortcutMgr.tryRegister()` 가 동일한 `ShortcutBlacklist.isReserved()` 검사로 등록을 별도 거부하던 문제 해결. YAML 보존 + 실제 hotkey 등록까지 정책 일관 적용.
* 해결:
    - `cli/fSnippetCli/Managers/ShortcutMgr.swift` `tryRegister()` 에 `ConfigMigration.contextOnlyHotkeyKeys` 면제 가드 추가
    - **SSOT 활용**: 별도 셋 신설하지 않고 Issue115에서 만든 `ConfigMigration.contextOnlyHotkeyKeys` 를 재사용 → 정책 단일 진실 원천 보장
* 검증:
    - paidApp 종료 + cliApp 단독 실행 상태에서 `_config.yml` 에 `history.registerSnippet.hotkey: "{⌘S}"` 주입 후 재시작
    - ConfigMigration 정리 로그 없음 (Issue115 ✅)
    - **ShortcutMgr 차단 로그 없음** (Issue116 ✅)
    - `🚀 총 등록된 단축키: 12개 "App Shortcuts (5) + ..."` — App Shortcuts 카운트 4 → 5 (registerSnippet 등록 성공)
* 부가 발견:
    - paidApp 측은 별도 경로(`SettingsManager.save()` + `PopupKeyShortcut.from(hotkeyString:)`)에서 동일 컨텍스트 hotkey 를 빈 값으로 덮어쓰는 문제가 잔존. 메인 fSnippet 레포 Issue864 로 등록되어 별도 추적 중.
* 수정 파일: `cli/fSnippetCli/Managers/ShortcutMgr.swift`

## Issue115: [ConfigMigration] 컨텍스트 hotkey가 매 시작 시 빈 값으로 초기화되는 버그 (등록: 2026-05-10, 완료: 2026-05-10) (Hash: 3d236c3)
* 목적: 사용자가 설정한 `history.registerSnippet.hotkey: "{⌘S}"` 값이 매 시작 시 `ConfigMigration.migrate()` 가 `ShortcutBlacklist`로 시스템 예약 매칭하여 빈 값으로 강제 정리되는 문제 해결.
* 해결:
    - `cli/fSnippetCli/Data/ConfigMigration.swift` 에 `contextOnlyHotkeyKeys` 셋 신설
        * `history.registerSnippet.hotkey`, `history.preview.hotkey` — 클립보드 히스토리 뷰어 활성 시에만 작동
    - `migrate(at:)` 시스템 예약 분기에 가드 추가: `if !contextOnlyHotkeyKeys.contains(key) && ...` — 컨텍스트 키는 블랙리스트 검사 우회
    - 글로벌 ⌘S(Save) 등과 충돌하지 않으므로 정리 대상에서 제외하는 것이 정확함
* 검증:
    - **격리 테스트로 root cause 분리 입증**:
        - paidApp + cliApp 동시 실행 → 재시작 → `{⌘S}` → `""` (실패)
        - paidApp 종료 + cliApp만 재시작 → `{⌘S}` 보존 (성공)
    - 새 백업 파일 생성되지 않음 (idempotent 보장)
* 부가 발견:
    - paidApp(메인 fSnippet 레포)도 동일 `_config.yml`을 SSOT로 공유하며 자체 save 경로에서 `history.registerSnippet.hotkey`와 `snippet_trigger_key` 를 빈 값으로 덮어씀
    - 메인 fSnippet 레포에 별도 이슈로 등록하여 추적 필요
* 수정 파일: `cli/fSnippetCli/Data/ConfigMigration.swift`

## Issue114: [Logging] _config.yml 로드 성공 로그를 logV → logI로 승격 (등록: 2026-05-10, 완료: 2026-05-10) (Hash: 3857ef6)
* 목적: 시작 시 `_config.yml` 로드 성공 여부를 표준 로그 레벨(INFO)에서 즉시 확인 가능하게 함. verbose 레벨에 묻혀 사용자가 "config 미로드"로 오인하는 문제 해소.
* 해결:
    - `cli/fSnippetCli/Data/PreferencesManager.swift` `loadConfigInternal()` L294-295의 `logV` → `logI` 승격
        * `⚙️ [Preference] 설정 로드 완료: <path>`
        * `⚙️ [Preference] 설정 로드 완료 (N keys)`
    - 동일 함수 내 키별 상세 진단(`Config Loaded snippet_trigger_key:` 등)은 `logV` 유지하여 노이즈 방지
* 검증: brew local 재배포 후 `flog_2026-05-10_14-51-31.log`에서 시작 직후 INFO 2줄 출력 확인
    ```
    14:51:31.534 ℹ️ INFO: ⚙️ [Preference] 설정 로드 완료: .../fSnippetData/_config.yml
    14:51:31.534 ℹ️ INFO: ⚙️ [Preference] 설정 로드 완료 (60 keys)
    14:51:31.938 ℹ️ INFO: fSnippetCli 시작 완료
    ```
* 수정 파일: `cli/fSnippetCli/Data/PreferencesManager.swift`

## Issue113: [cliApp] 메뉴바 Settings 클릭 시 paidApp 실행 및 설정창 foreground 표시 (등록: 2026-05-10, 완료: 2026-05-10) (Hash: 336f33a)
* 목적: cliApp 메뉴바 "Settings" 클릭 시 paidApp 실행 + 설정창 foreground 보장. paid_cli_protocol §4.2 정렬.
* 해결:
    - `.started` → `activatePaidApp()` (`NSRunningApplication.activate(.activateIgnoringOtherApps)`) 선행 후 `PaidAppDetector.openSettings()`. URL Scheme 단독 라우팅으로는 paidApp이 hidden/background 상태일 때 foreground 보장이 약했음.
    - `.stopped` → Issue112와 통합되어 `launchAndOpenSettings()` 호출. 백그라운드에서 `waitForPaidAppRegistration()` 폴링(PaidAppStateStore.status() 1차, isRunning() 2차, 최대 3s) → 메인 큐로 복귀하여 `activatePaidApp()` + `openSettings()` 순서 보장.
    - `.notInstall` → 기존 `showPaidOnlyAlert()` 유지 (회귀 없음).
* 검증: Release 빌드 통과 (`** BUILD SUCCEEDED **`).
* 수정 파일: `cli/fSnippetCli/Managers/PaidAppManager.swift`
* 영향: Issue112와 단일 커밋 통합 처리. 메인 레포 `_doc_arch/paid_cli_protocol.md` §4.2 SSOT 갱신과 `cli/_doc_arch/menuBar_enhance.md` Issue109 v1.3 표 갱신은 후속 이슈로 분리.

## Issue112: [정책/UX] paidApp .stopped 시 다이얼로그 제거 — 최초 1회 동의 후 자동 기동 (등록: 2026-05-10, 완료: 2026-05-10) (Hash: 336f33a)
* 목적: `.stopped` 상태에서 paid 기능 호출 시마다 표시되던 "fSnippet이 필요합니다" NSAlert를 1회 동의 후 자동 기동으로 전환. cliApp 시작 시 자동 기동 정책(paid_cli_protocol §4.2)과 일관된 UX 통합.
* 해결:
    - UserDefaults 키 `paidApp.autoLaunchConsent`(Bool, 기본 false) + `PaidAppManager.autoLaunchConsent` getter/setter 추가.
    - `handlePaidFeature()` 분기 재작성:
        - `.stopped` + `consent==false` → `showRequirePaidAlert()` 다이얼로그. [열기] 클릭 시 `consent=true` 영속 + `launchAndOpenSettings()` 진입.
        - `.stopped` + `consent==true` → 다이얼로그 생략, 즉시 `launchAndOpenSettings()` (`🏷️ [PaidApp] 동의 기반 자동 기동` 로그).
    - 다이얼로그 안내 문구에 "다음부터는 자동으로 실행됩니다" 명시 — 동의의 의미를 사용자에게 가시화.
    - `launchAndOpenSettings()`는 Issue113과 통합되어 launch → register polling → activate + openSettings 흐름을 일원화.
* 검증: Release 빌드 통과 (`** BUILD SUCCEEDED **`).
* 수정 파일: `cli/fSnippetCli/Managers/PaidAppManager.swift`
* 영향: 단일 파일 변경. 메인 레포 `_doc_arch/paid_cli_protocol.md` §1.2/§4.2 SSOT 동기화 및 `cli/_doc_arch/menuBar_enhance.md` Issue109 v1.3 표 갱신은 후속 이슈로 분리.

## Issue111: [Bug] cliApp Settings 단축키가 paidApp 설정창을 열지 못함 — URL Scheme이 LaunchServices 캐시로 죽은 앱에 라우팅 (등록: 2026-05-05, 완료: 2026-05-08) (Hash: 7e8b5e9)
* 목적: paid_cli_protocol §3 (실행 상태 감지) register 정보를 활용하지 않고 LaunchServices 기본 라우팅에 전적으로 의존하여, URL Scheme 핸들러가 옛 Bundle ID(예: Time Machine 백업의 `com.finfra.fSnippetCli`)로 매핑된 사용자 환경에서 settings 단축키가 paidApp을 열지 못하는 회귀를 차단함. §3.2/§3.5 1차 채널(REST register `bundlePath`)을 활용하여 LaunchServices 캐시 오염을 우회.
* 근본 원인:
    - `cli/fSnippetCli/Utils/PaidAppDetector.swift:40-58` `openSettings()`가 `NSWorkspace.shared.open(URL("fsnippet://..."))`만 호출 — 수신 앱을 지정하지 않으므로 LaunchServices가 기본 핸들러로 라우팅
    - `PaidAppStateStore.shared.status()`로 `bundlePath`를 이미 보유 중이지만 미사용
    - paid_cli_protocol §3.5 "REST register 1차 채널" 원칙 위반
* 해결:
    - `PaidAppDetector.openSettings()` 분기 추가:
        - 1차 채널: `PaidAppStateStore.shared.status()` 결과가 있고 `bundlePath` 실제 존재 → `NSWorkspace.shared.open(_:withApplicationAt:configuration:completionHandler:)`로 URL을 해당 번들에 강제 라우팅 (LaunchServices 캐시 우회)
        - 2차 안전망: 기존 `isRunning()`/`launch()` + LaunchServices 기본 라우팅 (Store 미보유 환경)
        - 롤백 플래그 `fsc.disableUrlScheme` 동작 유지
    - 로깅: 1차 채널 사용 시 `🪟 [Settings] register bundlePath 사용: <path>`, 폴백 시 `🪟 [Settings] LaunchServices 라우팅 폴백`
* 검증: Release 빌드 통과 (`** BUILD SUCCEEDED **`)
* 수정 파일: `cli/fSnippetCli/Utils/PaidAppDetector.swift`
* 영향: 단일 파일 변경. paid_cli_protocol §3.5 1차 채널 원칙 준수로 후속 회귀 차단.

## Issue110: [Refactor] PaidAppManager.handlePaidFeature를 AppStateManager.paidAppStatus 단일 진입점으로 통합 (등록: 2026-05-05, 완료: 2026-05-05) (Hash: ef2d6d6)
* 목적: Issue107 v1.2 설계가 paidAppStatus 3-state enum을 단일 진입점으로 정의했으나, `handlePaidFeature()`는 여전히 `isInstalled()` + `isRunning()` 2-flag 체크 사용. 추상화 일관성 확보 + 후속 변경 시 단일 진입점 보장
* 근본 원인:
    - `cli/fSnippetCli/Managers/PaidAppManager.swift:124-135`: `handlePaidFeature()`가 `guard isInstalled() else {...}` + `if isRunning() {...}` 패턴 사용
    - `AppStateManager.shared.paidAppStatus`는 동일 정보를 enum으로 보유하나 `handlePaidFeature` 미사용
    - 동작은 동등하나, 향후 paidAppStatus 전이 정책 변경 시 두 곳을 동시 수정해야 하는 위험
* 해결:
    - `handlePaidFeature()` 시그니처 유지, 내부 분기를 `switch AppStateManager.shared.paidAppStatus` 로 재작성
        - `case .started` → `PaidAppDetector.openSettings()`
        - `case .stopped` → `showRequirePaidAlert()`
        - `case .notInstall` → `showPaidOnlyAlert()`
    - 영향: paidApp 라이프사이클 NotificationCenter 갱신 → AppStateManager → handlePaidFeature 자동 동기화
* 검증: Release 빌드 통과 (`** BUILD SUCCEEDED **`)
* 수정 파일: `cli/fSnippetCli/Managers/PaidAppManager.swift`
* 영향: 기능 변경 없음. 코드 라인 수 감소 + 후속 이슈에서 paidAppStatus 정책 변경 시 단일 위치만 수정

## Issue109: [Bug/Design] Settings 라우팅 정책 불일치 — 옵션 B 채택, 설계 v1.3 갱신 (등록: 2026-05-05, 완료: 2026-05-05) (코드 변경 없음, 로컬 SSOT 문서)
* 목적: Issue107 v1.2 설계 문서가 "Settings는 항상 cliApp 자체 설정창"으로 명시했으나, 실제 코드는 `SettingsWindowManager.swift:18-21`에서 `showSettings()` → `PaidAppManager.handlePaidFeature()`만 호출하는 stub. cliApp 자체 Settings UI는 존재하지 않음 → 설계와 구현 정합성 회복
* 근본 원인:
    - `cli/fSnippetCli/Managers/SettingsWindowManager.swift:6-37`: `class SettingsWindowManager`가 stub. `showSettings()`/`toggleSettings()` 모두 `PaidAppManager.shared.handlePaidFeature()` 호출
    - **Issue105 fix는 placebo**였음: KeyEventHandler/MenuBarView 양쪽이 `SettingsWindowManager.toggleSettings()`로 통일됐지만 toggleSettings가 결국 handlePaidFeature를 호출
* 결정: **옵션 B 채택** (저비용 — 설계 갱신)
    - 옵션 A(cliApp 자체 Settings UI 신규 구현)는 ROI 낮음 — Configuration 서브메뉴 `Open Config File`로 _config.yml 직접 편집 가능
    - 옵션 C(혼합)는 중간 비용 + 사용자 혼란 우려 → 본 라운드에서는 미채택
* 해결:
    - `cli/_doc_arch/menuBar_enhance.md` v1.2 → v1.3 개정 (로컬 전용 SSOT)
    - 기본 방침 4번째 항목 재작성: "Settings는 paidApp 라우팅 + Configuration 서브메뉴 fallback" 명시
    - 유료 기능 클릭 처리 섹션에 "Settings 항목 라우팅 (Issue109 v1.3)" 하위 표 추가 — 3-state별 결과 명시
    - "Issue105 회고 노트" 섹션 추가 — placebo 사실 문서화
    - paidApp 없이 설정 변경 가이드: `⚙️ Configuration → Open Config File` 사용
* 영향: 코드 변경 없음 (문서 개선만). Issue110(handlePaidFeature 리팩터링)은 별도 진행

## Issue108: [Feat] cliApp 메뉴바 항목 다국어 지원 — Localizable.strings 정비 (ko) (등록: 2026-05-05, 완료: 2026-05-05) (Hash: cd4577e)
* 목적: pairApp Issue70(fWarrange) 동일 패턴의 cliApp 측 작업. Issue106 Quit 항목 정책 분리 후 메뉴 라벨이 영어 하드코딩 상태 → 시스템 언어 전환 시 메뉴 텍스트가 즉시 반영되도록 다국어 리소스 정비
* 키 전략: **영어 리터럴-as-key** 채택 (기존 `fSnippetCliApp.swift` 패턴 일관성 + 누락 시 영어 fallback + 정적 SwiftUI Label 자동 LocalizedStringKey 활용)
* 해결:
    - `ko.lproj/Localizable.strings` 전면 재작성 (16줄 → 39줄): About cli/paid, Snippet Popup, Show Clipboard History, Clipboard 서브메뉴(Pause/Resume/Clipboard to Snippet/Clear), Open Settings Window, Daemon 서브메뉴(Reload Snippets/Restart Daemon/Pause·Resume REST API), Configuration 서브메뉴(Open Config·Snippet·Data·Log Folder), Launch at Login, Quit fSnippet/All, Restart Daemon Failed
    - `MenuBarView.swift` ternary 분기 4곳 `LocalizedStringKey(...)` wrap: About cli/paid, Pause/Resume, Pause/Resume REST API, Restart Daemon Failed NSAlert(`NSLocalizedString`)
    - 정적 SwiftUI Label은 자동 LocalizedStringKey 처리에 위임 (코드 변경 없음)
    - `en.lproj` 생략 (개발언어 en 기본 fallback)
* 검증: Release 빌드 통과 (`** BUILD SUCCEEDED **`) + 번들 `Resources/ko.lproj/Localizable.strings` 포함 확인 + brew local 재배포 + 사용자 수동 검증 (메뉴 한글 표시 정상)
* 수정 파일: `cli/fSnippetCli/MenuBarView.swift`, `cli/fSnippetCli/ko.lproj/Localizable.strings`

## Issue107: [Docs] menuBar_enhance.md v1.2 개선 — paidAppStatus 3-상태·시작흐름·종료정책 명세 (등록: 2026-05-05, 완료: 2026-05-05) (코드 변경 없음, 로컬 SSOT 문서)
* 목적: paidApp Issue851(cliApp API ready 대기), Issue852(설정창 취소 사이드 이펙트) 후속 문서 정비. pairApp(fWarrange) `cli/_doc_arch/menuBar_enhance.md` v1.2 수준의 명세 보강
* 해결:
    - `cli/_doc_arch/menuBar_enhance.md` v1.1 → v1.2 개정 (로컬 전용 SSOT, gitignored)
    - `paidAppStatus` 3-상태(`notInstall`/`stopped`/`started`) 정의 추가 — Issue851 API ready 대기 로직 근거
    - 시작 흐름 차트 추가: paidApp → cliApp 감지(API v2 포트 3015 검증), cliApp → paidApp 감지(상태 전이)
    - 아이콘 매핑 3-상태 표 (`started`=전체, `stopped`/`notInstall`=잘린 아이콘)
    - 유료 기능 클릭 처리 분기표 + Settings 예외 명시 (Issue105)
    - 종료 항목 정책 4-상태 표 (Issue106 결과 명세화)
    - 단축키 표시 원칙 (`⌘Q`는 paidApp 활성 시 `Quit fSnippet` 항목 단독)
    - 메뉴 구조 트리 갱신: `[paidApp 활성 시] Quit fSnippet ⌘Q` + `[paidApp 활성 시] Quit All` + `[paidApp 비활성 시] Quit All` 3-라인 명시
    - About 메뉴 분기 명시 (Issue103) + Snippet Popup 알림 경로 (Issue104)
    - 다국어 정책 (현 시점 영어 하드코딩, 향후 도입 시 신규 키 정의)
    - 단축키 체계 표에 `_config.yml` 키 매핑 컬럼 추가
    - 관련 파일 목록 9개 → 11개로 확장 (PaidAppManager, AppStateManager 등 명시)
* 영향: 코드 변경 없음 (로컬 SSOT 문서 개선만). paidApp Issue851/852 후속 정비를 위한 참조 문서 정합성 확보. `cli/_doc_arch/`은 `_public/.gitignore`에 의해 의도적 비추적이므로 본 변경은 로컬에만 유지됨

## Issue106: [Feat] cliApp 메뉴바 Quit 항목 paidApp 정책 분리 — `Quit fSnippet ⌘Q` + `Quit All` (등록: 2026-05-04, 완료: 2026-05-04) (Hash: fddc8f4)
* 목적: `cli/_doc_arch/menuBar_enhance.md:53-54` 정책 — paidApp 활성 시 cliApp 메뉴에 paidApp 단독 종료(`Quit fSnippet ⌘Q`) + cliApp Quit All(`Quit All`, 단축키 없음) 두 항목 노출. paidApp 비활성 시 `Quit All` 단일 항목(단축키 없음). pairApp Issue70(fWarrange) 동일 패턴
* 근본 원인:
    - 기존 `MenuBarView.swift`에 `Quit ⌘Q` 단일 항목만 존재 → `NSApplication.shared.terminate(nil)` 호출 (cliApp + paidApp 동반 종료, 즉 Quit All만 수행)
    - paidApp 단독 종료 진입점 없음
    - menuBar_enhance.md SSOT가 정책을 명시하나 구현 미반영
* 해결:
    - `PaidAppManager.terminatePaidApp()` public 메서드 추가 — paidApp만 graceful terminate → 1초 대기 → forceTerminate fallback (cliApp은 잔존)
    - `MenuBarView.swift` Quit 영역 `isPaidMode` 분기:
        - paidApp 활성: `Quit fSnippet ⌘Q` → `PaidAppManager.shared.terminatePaidApp()` + `Quit All` (단축키 없음) → `NSApplication.shared.terminate(nil)`
        - paidApp 비활성: `Quit All` (단축키 없음) → `NSApplication.shared.terminate(nil)`
    - Divider 위치 정정: `Configuration → Divider → Launch at Login → Quit` → `Configuration → Launch at Login → Divider → Quit` (menuBar_enhance.md L52 정합)
    - 설계 문서 토큰 정정: `{menu.quit.fwarrange}` → `{menu.quit.fsnippet}`
* 검증: Release 빌드 통과 + brew local 재배포 9/9 PASS + 사용자 수동 검증 (메뉴 라벨·순서·단축키 정상)
* 수정 파일: `cli/fSnippetCli/Managers/PaidAppManager.swift`, `cli/fSnippetCli/MenuBarView.swift`, `cli/_doc_arch/menuBar_enhance.md`

## Issue105: [Bug] Settings 단축키 + 메뉴바 "Open Settings Window"가 paidApp 분기로 라우팅돼 cliApp 설정창 미열림 (등록: 2026-05-04, 완료: 2026-05-04) (Hash: e1984f6)
* 목적: 메뉴바 "🔧 Open Settings Window" 버튼과 단축키 `^⇧⌘;` 모두 `PaidAppManager.handlePaidFeature()`로 라우팅되어 paidApp 미설치/압축 상태에서 "Only support the paid version" alert이 뜸 → 두 경로 모두 cliApp 자체 설정창을 직접 열도록 일치
* 근본 원인:
    - 단축키 경로: CGEventTap → `KeyEventProcessor.handleAppShortcutSync` → `KeyEventHandler.didTriggerShortcut` → `handleAppShortcut` → `settings.hotkey` 분기에서 `PaidAppManager.handlePaidFeature()` 호출
    - 메뉴 경로: SwiftUI `MenuBarView.swift:71-77` 의 "🔧 Open Settings Window" Button action이 `PaidAppManager.handlePaidFeature()` 호출 (실제 사용 중인 메뉴는 SwiftUI 기반 `MenuBarView`이며 `MenuBarManager.swift`는 dead code)
    - `ShortcutMgr.executeAction`은 동일 ID에 대해 `SettingsWindowManager.shared.toggleSettings()`를 호출(정상)하지만 CGEventTap 경로는 이를 거치지 않음
    - "Issue8: 설정창은 유료 버전 전용 기능" 정책이 paidAppMenuDel 브랜치 도입 후에도 단축키·메뉴 양쪽에 잔존
* 해결:
    - `cli/fSnippetCli/Core/KeyEventHandler.swift:612-614` `settings.hotkey` 분기 → `SettingsWindowManager.shared.toggleSettings()` 직접 호출
    - `cli/fSnippetCli/MenuBarView.swift:71-77` "🔧 Open Settings Window" 버튼 action → `SettingsWindowManager.shared.toggleSettings()` 직접 호출
    - 단축키·메뉴 양쪽이 동일하게 cliApp 자체 설정창을 열도록 일치
* 검증: Release 빌드 통과 (`** BUILD SUCCEEDED **`) + 사용자 수동 검증 (메뉴 클릭·`^⇧⌘;` 두 경로 모두 cliApp 설정창 표시, paidApp alert 미표시)

## Issue104: [Bug] Snippet Popup 메뉴/단축키 작동 안 함 — fSnippetShowPopup observer 누락 (등록: 2026-05-04, 완료: 2026-05-04) (Hash: 0f57ebc)
* 목적: 메뉴바 "⚡ Snippet Popup" 클릭과 `^⇧Space` 단축키 모두 무반응 → 정상 작동 복구
* 근본 원인: `MenuBarView.swift:31` + `ShortcutMgr.swift:671` 가 `fSnippetShowPopup` 알림 발행하나, `KeyEventMonitor.setupObservers()` 에 해당 observer 미등록 (Issue429 위임 도입 시 수신부 누락). PopupController는 singleton 아님 → 외부 직접 호출 불가
* 해결:
    - `KeyEventHandler.showSnippetPopupRequest()` 신설 — 빈 candidates+검색어로 popup 호출 (PopupController가 Top 10 자동 표시), `deleteLength: 0` (외부 앱 버퍼 미소비)
    - `KeyEventMonitor.setupObservers()` 에 `fSnippetShowPopup` observer + `handleShowPopupRequest()` 핸들러 추가, main 스레드에서 KeyEventHandler 호출
* 수정 파일: `cli/fSnippetCli/Core/KeyEventHandler.swift`, `cli/fSnippetCli/Core/KeyEventMonitor.swift`
* 검증: Release 빌드 통과 (`** BUILD SUCCEEDED **`) + 사용자 수동 검증 (메뉴 클릭·단축키 두 경로 모두 팝업 표시·expansion 정상)

## Issue103: [Menu] paidApp 동작 시 About 메뉴를 fSnippet 모드로 전환 (등록: 2026-05-04, 완료: 2026-05-04) (Hash: 505e55d)
* 목적: paidApp 동작 중일 때 cliApp 메뉴바 About 라벨/창 내용을 fSnippet 제품 기준으로 분기
* plan: `cli/_doc_work/z_done/plan/about-paidapp-mode_plan.md`
* 구현:
    - `MenuBarView.swift`: `@StateObject AppStateManager` 의존, `paidAppStatus == .started`로 라벨 토글 + `showAbout(isPaidAppMode:)` 호출
    - `AboutWindowManager.swift`: `showAbout(isPaidAppMode:)` 시그니처 도입, 윈도우 title/`AboutView` 분기
    - `AboutView`: 모드별 제품명("fSnippet"/"fSnippetCli")·버전 출처(PaidAppStateStore.status().version vs Bundle) 분기
* 검증: Release 빌드 통과 (`** BUILD SUCCEEDED **`)
* 수정 파일: `cli/fSnippetCli/MenuBarView.swift`, `cli/fSnippetCli/Managers/AboutWindowManager.swift`
* 부수 변경: MenuBarView "Launch at Login" 라벨에 🚀 prefix, Issue.md z_old 아카이브 노트 위치 정정

## Issue102: [Verify] Issue101/paidApp Issue849 검증 — paidApp/cliApp 종료 시 zombie process 제거 확인 (등록: 2026-05-03, 완료: 2026-05-03) (Hash: 24f2a1b)
* 목적: Issue101 수정 후 실제 zombie process가 제거되는지 검증
* 검증 결과:
    - paidApp + cliApp 동시 실행 후 cliApp SIGTERM
    - flog.log: `paidApp 종료 신호 전송 (PID: 76791)` → `paidApp graceful 실패 — forceTerminate (PID: 76791)`
    - 종료 후 잔여 프로세스 0개 확인 ✅
    - NSWorkspace bundleIdentifier 정확 매칭으로 self-match 버그 해소

## Issue101: [Cleanup] 앱 종료 시 쓰레기 프로세스 남음 — cliApp ↔ paidApp 양방향 종료 신호 구현 (등록: 2026-05-03, 완료: 2026-05-03) (Hash: 24f2a1b)
* 목적: paidApp/cliApp 종료 시 잔여 프로세스(좀비) 제거. cliApp 메뉴바 Quit 시 paidApp 동반 종료
* 근본 원인:
    - pgrep substring 매칭 → cliApp(`fSnippetCli`)이 자기 자신도 매칭하여 자살 (`pgrep -f kr.finfra.fSnippet`도 `kr.finfra.fSnippetCli` 매칭)
    - 다중 PID 출력 시 `pid_t(pidStr)` 파싱 실패 → silent return → paidApp 미종료
* 해결:
    - `terminatePaidApp()` 재구현 — `NSWorkspace.shared.runningApplications` + `bundleIdentifier == "kr.finfra.fSnippet"` 정확 매칭
    - `app.terminate()` (graceful) → 1초 대기 → `app.forceTerminate()` (SIGKILL) fallback
* 수정 파일: `cli/fSnippetCli/fSnippetCliApp.swift`
* 검증: Issue102에서 실측 통과

> 누적된 완료 이슈는 [z_old/old_issue.md](z_old/old_issue.md)로 아카이브됨 (2026-05-03 1.0.1 release 시점 분리).

# ⏸️ 보류

## Issue205: [Settings] cliApp UI 미러의 전체 덤프로 REST 로 저장한 history 설정이 소실됨 (등록: 2026-08-31, 보류 이동: 2026-09-01)
* 목적: REST 로 `history.*` 설정을 바꾼 뒤 특정 필드가 낀 PATCH 가 한 번 더 들어오면 **앞서 바꾼 값이 앱 시작 시점 값으로 소실**된다. 사용자 증상은 "검색창 입력 언어 강제" 가 원복되는 것으로 나타났다 (메인 레포 fSnippet#Issue972 의 잔여 원인 ②)
* ⏸️ **착수 보류 — App Store 제출 후 처리 (런타임 동작 변경)**: `release/1.1.1` 심사 전 런타임 동작 변경을 피한다. Issue203·fSnippet#Issue968 과 동일 정책. 제출·심사 통과 후 착수. (2026-08-31 사용자 판정)
* **원인 확정** (prj15 2026-09-01 실측 — 본 이슈의 정본 근거):
    - cliApp `SettingsObservableObject` 가 history 미러를 **앱 시작 시 1회만 로드**하고 REST PATCH 로는 갱신하지 않는다
    - `APIRouter.handleV2PatchHistory`(L2942~2947, Issue900) 가 `showStatusBar`·`showPreview`·`imageDetailIsFloating` **3개만** 미러에 대입하는데, 이 셋은 `didSet → syncHistorySetting()` 을 갖고 그 함수가 **stale 구조체 전체를 `_config.yml` 에 덤프**한다 (L1100~1135)
    - 따라서 **위 3개 중 하나가 낀 PATCH 가 트리거**이고, 덤프되는 값은 *앱 시작 시점* 스냅샷이다
* 실측 근거 (prj15, cliApp 단독 · paidApp 종료):
    - `PATCH {force:US}` 1회 후 **추가 요청 없이 20초 관찰 → 유지**
    - `PATCH {force:US, moveDuplicatesToTop}` 후 20초 → 유지. 이어서 `PATCH {showStatusBar:true}` 1개만 → **t=1s 즉시 원복**
    - 필드별 예측 **6/6 적중** — 위 3개가 낀 PATCH 만 오염되고 `moveDuplicatesToTop`·`ignoreImages`·`viewerHotkey` 는 유지
    - **결정적 대조**: `force=US` 저장 후 **cliApp 재시작**(미러가 US 를 로드) → 동일한 `showStatusBar` PATCH 로 **원복되지 않음**
* ⚠️ **영향 범위는 forceInputSource 에 국한되지 않는다 — 심각도 상향**: `retentionDays.plainText` 를 45 로 PATCH 후 `showStatusBar` PATCH → **90 으로 소실**. **REST 로 변경한 history 설정 전부**가 대상이다
* ⚠️ **폐기된 가설 2건 — 다시 조사하지 말 것**:
    - 등록본(2026-08-31): "PATCH 가 부분 갱신이 아니라 stale 스냅샷 전체 flush" → **전체 덤프라는 방향은 옳았으나 위치가 틀렸다**. `handleV2PatchHistory` 의 `if let v = patch.X` 부분 갱신과 `PreferencesManager.batchUpdate` 는 둘 다 정상이며, 범인은 그 밖의 `SettingsObservableObject` 다
    - 1차 정정본(2026-08-31, prj25): "추가 요청 없이 시간 경과만으로 t=3s 에 자동 원복된다(지연 flush)" → **반증됨**. 20초 관찰에서 유지된다. 당시 관측은 **직전 실험의 `showStatusBar` PATCH 로 조건이 오염된 상태**에서 나온 것이었다
* 구현 명세:
    - `SettingsObservableObject` 의 history 미러가 **저장 직전 최신 상태를 반영**하도록 고친다. 선택지는 ① `syncHistorySetting()` 이 덤프 대신 변경 필드만 반영 ② PATCH 경로에서 미러 전체를 재동기화 ③ 미러 제거 — 셋 중 택일하되 **전체 덤프를 남긴 채 필드만 추가하는 미봉책은 금지**(대입 필드가 늘 때마다 같은 버그가 재발한다)
    - 검증은 **필드 교차 조합**으로 한다: `retentionDays.plainText`·`forceInputSource` 등을 바꾼 뒤 `showStatusBar`·`showPreview`·`imageDetailIsFloating` 각각으로 PATCH → 전부 유지되어야 함
    - ⚠️ 단일 PATCH 후 시간 관찰만 하는 검증은 **이 버그를 못 잡는다** — 트리거가 시간이 아니라 특정 필드이기 때문이다. 1차 시도(fSnippet#Issue972 의 `ef45f2dc` → revert `1c285c33`)가 그 함정에 빠졌다
* 재확인 (2026-09-01, brew 1.1.1 신규 빌드 · 타 세션 관찰): PUT `/settings/snapshot`(Issue203) 경유 실측에서도 동일 재현 — **history 키(`retentionDays.plainText` 45→90)만 원복**되고 popup(`snippet_popup_rows`)·performance(`performance.key_buffer_size`) 키는 t=15s 까지 유지됨. 되쓰기 범위가 **history 미러에 국한**됨을 지지하는 관찰이며, 위 원인 확정(`SettingsObservableObject` 의 history 미러 전체 덤프)과 정합한다
* 관련: 메인 레포 fSnippet#Issue972 — 원인 ①(paidApp 읽기 누락)은 `721c74e5` 로 해결 완료. 본 이슈가 잔여 ②이며, Issue972 본문은 `da082083` 에서 위 실측으로 2차 정정 완료

## Issue156: [Runtime] bufferClear `.` 충돌로 마침표 포함 abbreviation 14건이 확장 불가 (등록: 2026-05-27, 대상 교체: 2026-09-01)
* 목적: `appSetting.json` 의 bufferClearKeys 에 `.` 가 포함되어, abbreviation 에 마침표를 쓰는 스니펫은 사용자가 `.` 를 누르는 순간 버퍼가 클리어되어 **구조적으로 확장이 불가능**하다. `_한글속기` 13건 + `_symbol` 1건, 합계 **14건**이 대상이다.
* **보류 사유 교체 (2026-09-01)**: 종전 보류 사유였던 "Karabiner 외부 설정 조사 미완" 은 **해소**되었다(아래 실측에서 전수 확인 완료). 대신 **App Store 제출 후 처리** 로 보류 사유를 교체한다 — 키 입력 판정 변경이므로 `release/1.1.1` 심사 전 착수하지 않는다. Issue203·Issue205 와 동일 정책.
* **대상 교체 이력 (2026-09-01)**: 등록본은 증상을 `..0{keypad_comma}` 입력 차단 / 대상을 `_Bullets/0===0.txt` 로 기술했으나 **실측에서 전부 반증**되었다. 진단 방향(`.` bufferClear 충돌)만 유효하여 대상을 위와 같이 교체했다.
* **실측 근거** (2026-09-01, cliApp 1.1.1 가동 중 · 스니펫 2006건 로드):
    - `appSetting.json` bufferClearKeys = `["\r", "\n", "\t", " ", "."]` — **`.` 포함 확인. 쉼표(`,`)는 없음**
    - 디스크 전수(스니펫 파일 2011개)에서 파일명 keyword 부에 `{period}` 토큰 보유 = **14건**
        - `_한글속기` 13건: `h{period}`, `j{period}`, `k{period}`, `ky{period}`, `{period}{slash}`, `j{comma}{period}`, `j{period}j`, `j{period}{apostrophe}`, `j{period}j{apostrophe}`, `j{comma}{period}j`, `j{comma}{period}{apostrophe}`, `j{comma}{period}j{apostrophe}`, `z_old/{period}{slash}`
        - `_symbol` 1건: `{period}==={comma}..txt`
    - `_한글속기` 는 룰 prefix 가 백틱(`` ` ``)이므로 실제 abbreviation 은 `` `h. `` 형태 — 마침표가 abbreviation 중간·끝에 놓이는 순간 매칭이 깨진다
    - ⚠️ **REST `/api/v2/snippets` 는 기본 50건만 반환**한다. 그 표본에서는 `.` 포함 abbreviation 이 0건으로 나와 "피해 없음" 으로 오판할 수 있다. **반드시 디스크 전수로 확인할 것**
* ⚠️ **폐기된 가설 3건 — 다시 조사하지 말 것**:
    - "매칭 대상 abbreviation 은 `,,0{keypad_comma}` (룰 suffix=`{keypad_comma}`)" → **반증**. `_Bullets` 룰은 prefix=`,,`, **suffix=`{right_command}`** (REST `/api/v2/folders` 실측). 실제 abbreviation 은 `,,0{right_command}` 이며 정상 등록되어 있다(`id=_Bullets/0===0.txt`, content=`◦ `). 쉼표는 bufferClearKeys 에 없으므로 **차단 메커니즘 자체가 성립하지 않는다**
    - "noteForHuman.md line 31 표기가 `..0{keypad_comma}`" → **해소됨**. 현재 표기는 `,,0{right_command}  : _Bullet` 로 실제 규칙과 일치한다. 또한 이 파일은 `_public` 에서 **gitignored**(`.gitignore` 17행)라 라인 번호 고정 참조는 시간이 지나면 검증 불가가 된다
    - "doc `..` 은 Karabiner remap (`.` → `,`) 의 입력 시각화" → **근거 없음**. `~/.config/karabiner/karabiner.json` 전수 확인 결과 `.` → `,` 단순 remap 은 존재하지 않는다. period 관련 규칙은 전부 simultaneous(동시타)이며, `12Key2Knob` 의 `4`→comma·`6`→period 는 별개 노브 장치용이다
* **구현 명세 — 폴더별 bufferClear 예외** (2026-09-01 사용자 결정):
    - `_rule.yml` 에 **폴더 단위 bufferClear 면제** 필드를 두어, 해당 폴더의 abbreviation 매칭 중에는 지정 문자를 버퍼 클리어로 취급하지 않는다. 적용 대상은 `_한글속기`·`_symbol`
    - 전역 `bufferClearKeys` 에서 `.` 를 제거하는 안은 **채택하지 않는다** — 마침표로 버퍼를 끊던 전역 동작이 바뀌어 문장 입력 중 의도치 않은 매칭이 늘어난다
    - 스니펫 keyword 를 마침표 없는 키로 옮기는 안도 **채택하지 않는다** — 사용자가 익힌 입력 습관을 깨뜨린다
    - 판정 지점이 늘어나므로 `TextBuffer`(L112·L166·L196)·`KeyEventHandler`(L298) 의 `AppSettingManager.shared.bufferClearKeys` 참조 4곳이 **동일한 폴더 컨텍스트 판정을 공유**하도록 단일 지점화한다. 참조처마다 따로 분기를 넣는 미봉책은 금지 — 참조가 늘 때마다 같은 버그가 재발한다
    - 검증은 14건 중 폴더별 대표 케이스로 한다: `_한글속기` 의 `` `h. ``(끝 마침표) · `` `j.j ``(중간 마침표) · `_symbol` 의 단독 마침표. 각각 확장 성공 + **일반 문장 입력에서 마침표 버퍼 클리어가 여전히 동작**함을 함께 확인
* 관련: 부수 발견으로 메인 레포 `.claude/rules/config-rules.md` 18행이 bufferClear 기본값에 실재하지 않는 쉼표(`,`)를 포함한다고 서술함 — 이 오기가 본 이슈의 최초 오독을 유발한 요인. prj15 별도 이슈로 등록
## Issue73: [Refactor] PopupController 책임 분리 — UI 위젯 직접 소유 해소 (등록: 2026-04-25, 보류: 2026-04-26)
* 목적: `Core/PopupController.swift`가 UI 위젯(`SnippetNonActivatingWindow`)을 직접 소유 + 상태 관리 + Core 콜백 수신까지 수행 → 책임 분리로 SRP 준수 및 테스트성 확보
* 복잡도: **복잡** (설계 결정이 KeyEventMonitor/TextReplacer 콜백 경로에 영향 → plan + task + report 전체 사이클)
* 보류 사유: 기능 동작 이상 없음 (순수 리팩토링). Phase1~3 전이 시 KeyEventMonitor/KeyEventHandler 콜백 경로 동시 수정 필요로 회귀 위험 내포. 다른 기능 이슈가 없을 때 재개.
* 상세:
    - **현황**: `Core/PopupController.swift` (539줄) 단일 클래스가 다음을 모두 수행:
        1. UI 위젯 소유: `private let popupWindow = SnippetNonActivatingWindow()` — Core 폴더 소속 파일이 UI를 직접 생성·관리
        2. Core 콜백 수신: `showPopup(with:searchTerm:cursorRect:onSelection:)` — KeyEventMonitor/TextReplacer로부터 호출
        3. 설정 실시간 반영: `SettingsManager.shared.load()` + `popupSearchScopeDidChange` 관찰
        4. 상태 보관: `isVisible`, `mode`, `allCandidates`, `currentSearchTerm`
        5. 부수 효과: `InputSourceManager.applyForceInputSource()`, `ClipboardManager.chvMode = .deactive`, `MouseUtils.ensureMouseOutside(...)`, `SettingsWindowManager.temporarilyHide()`
    - **문제점**:
        1. **계층 경계 모호**: Core 폴더 파일이 AppKit 윈도우 위젯을 직접 소유
        2. **테스트 어려움**: 단위 테스트 시 NSWindow 모킹 필수 → Headless CI 불가
        3. **확장 비용**: 팝업 UI 교체(스타일/애니메이션) 또는 대체 프레젠터 추가 시 Core 콜백 경로까지 영향
    - **해결책** (3-layer 분해):
        1. `UI/PopupPresenter.swift` (신규) — `SnippetNonActivatingWindow` 소유·표시·닫기·검색어 갱신 전담
        2. `Core/PopupCoordinator.swift` (신규) — KeyEventMonitor/TextReplacer 콜백 수신 + 부수 효과 오케스트레이션 + PopupPresenter 호출
        3. `Models/PopupState.swift` (신규) — `isVisible`, `mode`, `currentSearchTerm` 등 @Published 상태 객체
        4. `Core/PopupController.swift` (유지) — 기존 공개 인터페이스 유지하는 파사드로 축소 (호출 측 변경 최소화)
    - **API 계약 영향**: 없음 (내부 구조 변경만, REST API/OpenAPI 스펙 영향 없음)
    - **기대 효과**:
        - UI 교체 비용 축소 (PopupPresenter만 교체)
        - PopupCoordinator 단위 테스트 가능 (Presenter mock 주입)
        - 히스토리 윈도우 등 유사 UI에 Presenter 패턴 재사용
* 구현 명세:
    - 신규 파일: `UI/PopupPresenter.swift`, `Core/PopupCoordinator.swift`, `Models/PopupState.swift`
    - 수정 파일: `Core/PopupController.swift` (파사드화), `Core/KeyEventMonitor.swift`·`TextReplacer.swift` (의존성 주입 경로 조정)
    - 전이 전략: Phase1 = Presenter 분리 → Phase2 = Coordinator 분리 → Phase3 = State 분리
    - 테스트: Presenter/Coordinator 각각 독립 단위 테스트 작성
* 배경: fSnippet paidApp 레포에서 graphify God Nodes 분석 시 `popupcontroller_ui` Hyperedge로 Core-UI 경계 모호성 식별

## Issue74: [Refactor] APIModels CodingKeys 중앙화 — snake_case ↔ camelCase 자동 변환 (등록: 2026-04-25, 보류: 2026-04-26)
* 목적: `Data/APIModels.swift`에서 각 응답 구조체마다 반복 정의되는 CodingKeys를 JSONEncoder/Decoder의 `keyEncodingStrategy = .convertToSnakeCase` + `keyDecodingStrategy = .convertFromSnakeCase`로 대체 → 코드량 감소 + 명세 변경 영향도 축소
* 복잡도: **중간** (API 계약 불변 전제 시 plan 필수, task/report는 가치 판단)
* 상세:
    - **현황**: 10+ 구조체(`APIMetadata`, `HealthResponse`, `APISnippetSummary`, `APISnippetDetail`, `APIExpandData`, `APIClipboardItem`, `APIClipboardItemDetail`, `APIFolderSummary` 등)가 각각 CodingKeys 블록 소유
        - 예: `case durationMs = "duration_ms"`, `case contentPreview = "content_preview"`, `case snippetCount = "snippet_count"`
        - 단순 snake→camel 매핑이 대부분 (예외: 특수 필드 거의 없음 확인 필요)
    - **해결책**:
        1. `JSONEncoder`/`JSONDecoder` 팩토리 추가 (`APICoderFactory`) — `convertToSnakeCase`/`convertFromSnakeCase` 적용된 공용 인스턴스 제공
        2. `APIServer`/`APIRouter` 및 CLI `Commands/*` 가 동일 팩토리 사용하도록 전환
        3. 각 구조체의 단순 매핑 CodingKeys 제거 (예외 필드는 CodingKeys로 잔존)
        4. 스냅샷 테스트: 기존 JSON 응답과 바이트 레벨 동치 확인
    - **API 계약 영향**:
        - **불변 유지 필수**: JSON 응답 키는 현재와 동일(snake_case) 유지
        - `openapi_v2.yaml` 스펙 변경 없음 (v1은 `410 GONE` — 실측 2026-04-26 확인)
        - paidApp `RESTClient`/MCP 서버 호환성 영향 없음
    - **기대 효과**:
        - 각 구조체당 평균 5~10줄 CodingKeys 제거 → 총 ~80줄 감소 추정
        - 신규 API 응답 타입 추가 시 CodingKeys 작성 불필요
* 구현 명세:
    - 신규: `cli/fSnippetCli/Utils/APICoderFactory.swift`
    - 수정: `cli/fSnippetCli/Data/APIModels.swift` (단순 매핑 CodingKeys 제거)
    - 수정: `cli/fSnippetCli/Managers/APIRouter.swift`, `APIServer.swift` (팩토리 주입)
    - 수정: `cli/fSnippetCli/CLI/Commands/*` (클라이언트 측 디코더)
    - 테스트: `/api/v2/*` 응답 스냅샷 비교 (v1은 `410 GONE` — curl 회귀 대상 제외)
* 보류 사유: 감소 효과(~56줄, 전체 8%) 대비 수정 범위(4개 파일)와 `convertToSnakeCase` 자동 변환 예외 검증 비용이 더 큼. CodingKeys는 명시적 타입 안전망 역할도 하므로 v2 API가 안정화된 이후 재검토
* 참조: `.claude/rules/api-rules.md` (SSOT OpenAPI 스펙 불변)

## Issue72: 코드 주석 언어 통일 — 영어 표준화 (등록: 2026-04-25, 보류: 2026-04-25)
* 목적: `_public/` 공개 레포 기준에 따라 모든 Swift/Shell/Python 코드 주석을 영어로 통일 (Issue59 언어 규약 "코드 주석은 English only")
* 복잡도: 중간 (4명 Haiku 에이전트 병렬 작업 기획)
* 상세:
    - 범위: `cli/fSnippetCli/` 소스 + `cli/_tool/` 스크립트
    - 현황: 전체 약 5,000줄 한글 주석 (Core 770개, Script 795개, Logic/Data/Services 등 3,400+개)
    - 대응: 팀 기반 병렬 처리 기획 (Core-Reviewer, Script-Reviewer, UI-Reviewer, Logic-Reviewer)
* 보류 사유: 대규모 변환 작업으로 인한 merge conflict 위험 → command_eng 브랜치로 격리
* 참조: `.claude/rules/language-rules.md` (공개 레포 코드 주석 영어만)

# 🚫 취소

> 취소된 이슈는 [z_old/old_issue.md](z_old/old_issue.md)로 아카이브됨.

# 📜 참고
