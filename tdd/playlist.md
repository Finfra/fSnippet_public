---
title: fSnippetCli TDD 재생목록
description: prj25 fSnippetCli 의 TDD 목표를 재생 순서로 나열한 목록 (prj6#Issue16)
date: 2026.09.26
---

# 무엇을 지키나

키 이벤트 워치독이 권한을 잘못 판정해 재시작하거나 키보드를 잠그지 않게 하고, 스니펫 확장과 REST 설정 영속성을 지킨다

* 기존 러너: `bash cli/_tool/fsc-test.sh (12단계 통합: 빌드→ZTest 확장→apiTestDo.sh→cmdTestDo.sh→로그 검사) / XCTest 타깃 cli/fSnippetCliTests (xcodebuild test 명령은 문서에 없음)`
* 목표 10개 중 기존 테스트로 덮인 것 6개 · 신규 4개

# 재생목록

위에서 아래로 돈다 — 빠르고 기초적인 것이 먼저, 통합·E2E 가 뒤다. 앞 항목이 깨지면 뒤 항목의 실패는 원인이 아니라 결과일 수 있다.

| # | id | 목표 | 근거 | 실행 | 상태 |
| :- | :- | :- | :- | :- | :- |
| 1 | `config-migration-idempotent` | 설정 마이그레이션은 블랙리스트 단축키와 폐기 키를 제거하고, 두 번 돌려도 결과가 같다 | cli/fSnippetCliTests/ConfigMigrationTests.swift (testMigrateRunTwiceIsIdempotent·testMigrateBlacklistedHotkey·testMigrateObsoleteKey) | `cli/fSnippetCliTests/ConfigMigrationTests.swift` | ✅ 기존 |
| 2 | `shortcut-blacklist` | 예약 단축키(Cmd+S/C 등)는 대소문자나 중괄호 표기와 관계없이 등록이 거부된다 | cli/fSnippetCliTests/ShortcutBlacklistTests.swift (21개 테스트) | `cli/fSnippetCliTests/ShortcutBlacklistTests.swift` | ✅ 기존 |
| 3 | `expansion-trailing-newline` | 파일 참조 스니펫을 확장할 때 끝 줄바꿈은 지우고 본문 안의 줄바꿈은 남긴다 | cli/fSnippetCliTests/SnippetExpansionTrailingNewlineTests.swift | `cli/fSnippetCliTests/SnippetExpansionTrailingNewlineTests.swift` | ✅ 기존 |
| 4 | `paidapp-register-api` | paidApp 등록 API는 존재하지 않는 PID나 fSnippet이 아닌 PID에 403, 중복 세션에 409, 모르는 세션 해제에 404를 돌려준다 | cli/fSnippetCliTests/PaidAppAPIRouterTests.swift, PaidAppPhaseATests.swift | `cli/fSnippetCliTests/PaidAppAPIRouterTests.swift` | ✅ 기존 |
| 5 | `watchdog-swallowed-events-not-counted` | tap이 삼킨 이벤트는 tap 카운터에 세지 않아서, 권한이 살아 있을 때는 비대칭 워치독이 권한 상실로 판정하지 않는다 | Issue233(📕 진행 전): Issue229~231이 세 번 재발한 원인이 CGEventTapManager 카운팅 지점 결함임 | — | ⬜ 신규 |
| 6 | `watchdog-same-key-repeat` | 같은 키를 오래 반복하거나(distinct keyCode 1개), 비대칭 창이 한 번만 나오거나, cliApp 자체 창에서 타이핑해도 재시작 안내가 뜨지 않는다 | Issue229(자체 GUI 창 오판)·Issue230(연속 2회 창)·Issue231(distinct keyCode 기준). 세 이슈 모두 osascript로 직접 재현하지 못했다고 기록함 | — | ⬜ 신규 |
| 7 | `history-settings-persist` | REST로 바꾼 history.* 설정(예: retentionDays.plainText=45)이 뒤이은 다른 필드 PATCH 뒤에도 원래 값으로 돌아가지 않는다 | Issue205: SettingsObservableObject의 history 미러 전체 덤프 때문에 REST 저장값이 소실됨 | — | ⬜ 신규 |
| 8 | `brew-service-label` | brew 서비스 라벨을 sh.brew.*와 homebrew.mxcl.* 두 규약 모두로 인식해서, launchd 인스턴스가 스스로 종료하거나 인스턴스가 두 개 뜨지 않는다 | Issue206(라벨 규약 변경 미반영)·Issue209(부팅 시 인스턴스 2개)·Issue210(brew services stop 자멸) | — | ⬜ 신규 |
| 9 | `ztest-e2e-expansion` | 빌드·배포 뒤 TextEdit에서 트리거를 입력하면 testBoard 내용이 정의된 치환 결과와 같고, 로그에 ERROR/CRITICAL이 없다 | cli/_tool/fsc-test.sh (Step 3~8, Step 11), cli/_tool/testBoard.txt | `bash cli/_tool/fsc-test.sh` | ✅ 기존 |
| 10 | `rest-api-v2-contract` | REST API v2 엔드포인트(port 3015)가 openapi_v2.yaml 명세대로 응답한다 | api/openapi_v2.yaml(SSOT), cli/_tool/apiTestDo.sh, api/test-api.sh | `bash cli/_tool/apiTestDo.sh all` | ✅ 기존 |

# 규약

* **목표는 «검증 가능한 성질»** 이다 — *"잘 동작한다"* 는 목표가 아니다
* 새 버그를 고치면 **재현 테스트를 먼저** 여기 한 줄로 올리고(⬜), 테스트가 생기면 실행 열을 채워 ✅ 로 바꾼다
* 실패를 삼키는 패턴(`2>/dev/null || true` 등)을 테스트 안에 쓰지 않는다 — 실패는 실패로 드러나야 한다
* 판정 출처: prj6 `_doc_work/report/tdd-coverage_report.md` (이 프로젝트가 왜 TDD 대상인가)
