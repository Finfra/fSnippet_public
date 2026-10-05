---
title: fSnippetCli TDD 재생목록
description: prj25 fSnippetCli 의 TDD 목표를 재생 순서로 나열한 목록 (prj6#Issue16)
date: 2026.09.26
---

# 무엇을 지키나

키 이벤트 워치독이 권한을 잘못 판정해 재시작하거나 키보드를 잠그지 않게 하고, 스니펫 확장과 REST 설정 영속성을 지킨다

* 기존 러너: `bash cli/_tool/fsc-test.sh (12단계 통합: 빌드→ZTest 확장→apiTestDo.sh→cmdTestDo.sh→로그 검사) / XCTest 타깃 cli/fSnippetCliTests (xcodebuild test 는 아래 목표 목록 참고)`
* 목표 19개 — #1~18 ✅ (#1~16 prj5#Issue99 2026-09-27 jma 실행 · #17 Issue238 jm4 → Issue241 jma · #18 Issue242 jm4) · #19 Issue245. 유닛: `xcodebuild test -project cli/fSnippetCli.xcodeproj -scheme fSnippetCli -destination 'platform=macOS'`

# 재생목록

위에서 아래로 돈다 — 빠르고 기초적인 것이 먼저, 통합·E2E 가 뒤다. 앞 항목이 깨지면 뒤 항목의 실패는 원인이 아니라 결과일 수 있다.

| # | id | 목표 | 근거 | 실행 | 상태 |
| :- | :- | :- | :- | :- | :- |
| 1 | `config-migration-idempotent` | 설정 마이그레이션은 블랙리스트 단축키와 폐기 키를 제거하고, 두 번 돌려도 결과가 같다 | cli/fSnippetCliTests/ConfigMigrationTests.swift (testMigrateRunTwiceIsIdempotent·testMigrateBlacklistedHotkey·testMigrateObsoleteKey) | `cli/fSnippetCliTests/ConfigMigrationTests.swift` | ✅ 기존 |
| 2 | `shortcut-blacklist` | 예약 단축키(Cmd+S/C 등)는 대소문자나 중괄호 표기와 관계없이 등록이 거부된다 | cli/fSnippetCliTests/ShortcutBlacklistTests.swift (21개 테스트) | `cli/fSnippetCliTests/ShortcutBlacklistTests.swift` | ✅ 기존 |
| 3 | `expansion-trailing-newline` | 파일 참조 스니펫을 확장할 때 끝 줄바꿈은 지우고 본문 안의 줄바꿈은 남긴다 | cli/fSnippetCliTests/SnippetExpansionTrailingNewlineTests.swift | `cli/fSnippetCliTests/SnippetExpansionTrailingNewlineTests.swift` | ✅ 기존 |
| 4 | `paidapp-register-api` | paidApp 등록 API는 존재하지 않는 PID나 fSnippet이 아닌 PID에 403, 중복 세션에 409, 모르는 세션 해제에 404를 돌려준다 | cli/fSnippetCliTests/PaidAppAPIRouterTests.swift, PaidAppPhaseATests.swift | `cli/fSnippetCliTests/PaidAppAPIRouterTests.swift` | ✅ 기존 |
| 5 | `watchdog-swallowed-events-not-counted` | tap이 삼킨 이벤트는 tap 카운터에 세지 않아서, 권한이 살아 있을 때는 비대칭 워치독이 권한 상실로 판정하지 않는다 | Issue233(✅ 0efcafc): Issue229~231이 세 번 재발한 원인이 CGEventTapManager 카운팅 지점 결함임 | `cli/fSnippetCliTests/TapAsymmetryCounterTests.swift` | ✅ jma |
| 6 | `watchdog-same-key-repeat` | 같은 키를 오래 반복하거나(distinct keyCode 1개), 비대칭 창이 한 번만 나오거나, cliApp 자체 창에서 타이핑해도 재시작 안내가 뜨지 않는다 | Issue229·230·231. 판정을 `InputAsymmetryJudge` 로 추출해 osascript 재현 없이 검증 (prj5#Issue99) | `cli/fSnippetCliTests/InputAsymmetryJudgeTests.swift` | ✅ jma |
| 7 | `history-settings-persist` | REST로 바꾼 history.* 설정(예: retentionDays.plainText=45)이 뒤이은 다른 필드 PATCH 뒤에도 원래 값으로 돌아가지 않는다 | Issue205. 수정(resync) 제거 mutant 에서 5/5 red 확인 | `cli/fSnippetCliTests/HistorySettingsPersistTests.swift` | ✅ jma |
| 8 | `brew-service-label` | brew 서비스 라벨을 sh.brew.*와 homebrew.mxcl.* 두 규약 모두로 인식해서, launchd 인스턴스가 스스로 종료하거나 인스턴스가 두 개 뜨지 않는다 | Issue206·209·210 | `cli/fSnippetCliTests/BrewServiceLabelTests.swift` | ✅ jma |
| 9 | `ztest-e2e-expansion` | 빌드·배포 뒤 TextEdit에서 트리거를 입력하면 testBoard 내용이 정의된 치환 결과와 같고, 로그에 ERROR/CRITICAL이 없다 | cli/_tool/fsc-test.sh (격리 인스턴스 :3115 · 테스트 루트 자동 준비·매회 초기화, prj5#Issue99) | `bash cli/_tool/fsc-test.sh` | ✅ jma 4회 연속 |
| 10 | `rest-api-v2-contract` | REST API v2 엔드포인트(port 3015)가 openapi_v2.yaml 명세대로 응답한다 | api/openapi_v2.yaml(SSOT). test-api.sh 를 v2 경로로 이관 + `uptime_seconds`·빈 body 400 케이스 추가 | `bash cli/_tool/apiTestDo.sh all` · `bash api/test-api.sh --server=http://localhost:3115` | ✅ jma 20/20 |
| 11 | `test-host-isolation` | XCTest 호스트·격리 테스트 인스턴스는 사용자 데이터 루트·REST 포트·brew 서비스·paidApp 을 건드리지 않는다 | prj5#Issue99: 테스트 호스트가 사용자 `fSnippetData` 를 쓰고 두 번째 CGEventTap·3015 를 잡았음 | `cli/fSnippetCliTests/RuntimeIsolationTests.swift` | ✅ jma |
| 12 | `alfred-import-relative-base-path` | `snippet_base_path` 가 상대경로(번들 기본값 `./snippets`)여도 Alfred import 대상은 앱 루트 기준 절대경로다 | prj5#Issue99 (#10 실행 중 발견): v2 alfred-import 가 `/snippets` 를 만들려다 folder_creation_failed | `cli/fSnippetCliTests/SnippetBasePathResolutionTests.swift` | ✅ jma |
| 13 | `trigger-regression-table` | prefix·suffix·양쪽·없음·키패드콤마·우측Control·대문자 폴더 7종 규칙에서 생성된 약어가 자기 파일로 정확히 매칭된다 | prj15#Issue986 이관(prj15 #2 · RegressionCases·UppercaseTrigger·RightControlTrigger·KeypadCommaPrefix) | `cli/fSnippetCliTests/TriggerRegressionTableTests.swift` | ✅ jma |
| 14 | `trigger-priority-greedy-delete-length` | 규칙 tier 우선순위·최장 일치(greedy)·특수키 토큰은 visual count 로 삭제 길이를 센다 | prj15#Issue986 이관(prj15 #3 · Issue562·563·DeleteLengthSpecialKeys). Issue718·`68eb3435` 이후 동작 기준으로 단언 갱신 | `cli/fSnippetCliTests/TriggerPriorityGreedyDeleteLengthTests.swift` | ✅ jma |
| 15 | `folder-rule-table` | 폴더 규칙 표 35행 전부에서 약어 생성·역조회·typed 매칭이 표와 일치한다 | prj15#Issue986 이관(prj15 #4 · FolderTestRunner + testTable_org.md) | `cli/fSnippetCliTests/FolderRuleTableTests.swift` | ✅ jma |
| 16 | `accessibility-boot-listing` | 미승인으로 부팅한 새 프로세스는 시스템 권한 요청을 정확히 1회 보내 손쉬운 사용 목록에 올라가고, 승인 상태로 부팅하면 아무것도 묻지 않는다 | Issue237(jma 에서 목록 미등록 → 매번 수동 추가. Issue227 전제 정정) | `cli/fSnippetCliTests/fSnippetCliTests.swift` (AccessibilityBootListingTests) | ✅ jma |
| 17 | `official-build-marker` | 공식 빌드(`FSNIPPET_OFFICIAL_BUILD=YES`)에만 `resources/official/` 표식과 약관 문서(배포본 약관은 영문·한국어본 둘 다)가 서명 전에 번들되고, publish 게이트도 같은 약관 목록을 요구하며, `--version` 에 `Finfra Official Build` 가 찍힌다. 소스 빌드에는 표식이 없고, 같은 DerivedData 에서 뒤이은 소스 빌드는 남은 표식을 지운다 | Issue238(DISTRIBUTION-TERMS v1.2 §1(b) — 표식이 없으면 법무가 공식 빌드와 소스 빌드를 구별 못 함) · Issue241(§10 한국 거주 개인에게 한국어본 동등 효력인데 동봉·게이트 목록이 영문뿐이었음 — 게이트 목록 대조 검사 0b 추가) | `cli/fSnippetCliTests/OfficialBuildTests.swift` · `bash cli/_tool/fsc-official-build-check.sh` | ✅ jma (유닛 9/9 · 빌드 35/35, 서명 3건 SKIP — Issue241) |
| 18 | `official-app-icon` | 앱 아이콘은 공식 빌드에만 들어간다 — 공식 빌드는 `cli/resources/official/AppIcon.iconset` 으로 만든 `Resources/AppIcon.icns` 를 싣고, 소스 빌드는 아이콘이 전혀 없어(`AppIcon.icns`·Assets.car 아이콘·`CFBundleIconName` 모두 없음) macOS 기본 앱 아이콘을 쓴다. 공개 `Assets.xcassets` 에는 AppIcon 이 없다 | Issue242(NOTICE 는 아이콘을 Official Build Components 로 선언하는데 실물이 Apache 트리 `Assets.xcassets` 에 있어 소스 빌드도 공식 아이콘을 씀 — Issue238 잔여, 사용자 결정) | `cli/fSnippetCliTests/OfficialBuildTests.swift` · `bash cli/_tool/fsc-official-build-check.sh` | ✅ jm4 (유닛 9/9 · 빌드 31/31) |
| 19 | `typing-folder-table-e2e` | 폴더 규칙 표(`testTable_org.md`) 전 행의 약어를 TextEdit 에 실제 키 입력(특수키 토큰 `{right_option}`·`{right_command}`·`{right_control}`·`{keypad_comma}`·`{keypad_num_lock}`·`{f1}`·`{f2}` 포함)하면 그 행 폴더의 스니펫 본문으로 정확히 치환된다. 픽스처가 없는 행은 실패다 | Issue245 — jma 스니펫 타이핑 테스트(prj15 `qa-type-jma-mgr` · 본 repo Issue137·138 하니스)를 편입. 1.1.2 출고 테스트(2026-09-29 jma)에서 픽스처 부재로 0/35 였고 하니스는 픽스처 없음을 SKIP·exit 0 으로 삼켰음. #15 는 약어 생성·매칭까지, 실입력·삭제 길이·붙여넣기는 이 행만 본다 | `bash cli/_tool/fsc-typing-test.sh` (jma GUI tmux · 격리 :3115 · 픽스처 자동 생성) | ⬜ 신규 |

# 규약

* **목표는 «검증 가능한 성질»** 이다 — *"잘 동작한다"* 는 목표가 아니다
* 새 버그를 고치면 **재현 테스트를 먼저** 여기 한 줄로 올리고(⬜), 테스트가 생기면 실행 열을 채워 ✅ 로 바꾼다
* 실패를 삼키는 패턴(`2>/dev/null || true` 등)을 테스트 안에 쓰지 않는다 — 실패는 실패로 드러나야 한다
* 판정 출처: prj6 `_doc_work/report/tdd-coverage_report.md` (이 프로젝트가 왜 TDD 대상인가)
