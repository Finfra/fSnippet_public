---
name: Issue
description: fSnippetCli 이슈 관리
date: 2026-04-07
---

# Issue Management

* Issue HWM: 128
* Save Point :
      - 2026.05.16: e78f9da (Fix(Issue127): 기본 단축키 글로벌 등록 차단 회귀 복구 — context-only 면제 제거 + 폴더 단축키 가드)
      - 2026.05.16: 30794af (Fix(Issue128): 클립보드 팝업 최신 항목 반영 지연 — show() 동기 flush 추가)


# 🤔 결정사항
* `~/_git/__all/fSnippet/_doc_arch/paid_cli_protocol.md` 기준 진행(상위 메인 레포, paidApp앱과 연동)
* `cli/_doc_arch/menuBar_enhance.md` 기준 진행(메뉴바, 로컬 SSOT — gitignored)

# 🌱 이슈후보

# 🚧 진행중

# 📕 중요

# 📙 일반

## Issue123: [Test/Infra] FolderTest 재실행 인프라 복구 — paidApp→cliApp 의존성 마이그레이션 (등록: 2026-05-14, 갱신: 2026-05-14)
* 목적: 2026-03-26 이후 paidApp 압축 + 엔진의 cliApp 이전으로 인해 메인 fSnippet 레포의 `_tool/verify/run_folder_tests.sh`가 컴파일하는 의존 소스 25개 중 5개가 paidApp 경로(`fSnippet/fSnippet/`)에서 사라짐. 핵심 엔진 파일은 모두 `_public/cli/fSnippetCli/`로 이전됐으나 **cliApp 측에서 Facade 패턴으로 재구성**됨이 사후 분석에서 확인. 33-case 매트릭스 회귀 인프라를 cliApp Facade 구조에 맞게 재구축. 본 이슈는 **인프라 복구 + XCTest 빌드 통과**까지만 다룸. 실제 33-case 실행 및 결과 검증은 Issue124로 분리.
* plan: `cli/_doc_work/plan/folder_test_revival_plan.md`
* 누락/이동 현황 (메인 fSnippet 레포 기준):
    - **누락 (paidApp 경로에서 소실, cliApp 경로에는 존재)**:
        * `fSnippet/fSnippet/Data/SnippetFileManager.swift` → `_public/cli/fSnippetCli/Data/SnippetFileManager.swift`
        * `fSnippet/fSnippet/Data/RuleManager.swift` → `_public/cli/fSnippetCli/Data/RuleManager.swift`
        * `fSnippet/fSnippet/Managers/PSKeyManager.swift` → `_public/cli/fSnippetCli/Managers/PSKeyManager.swift`
        * `fSnippet/fSnippet/Core/AbbreviationMatcher.swift` → `_public/cli/fSnippetCli/Core/AbbreviationMatcher.swift`
        * `fSnippet/fSnippet/Managers/DeleteLengthManager.swift` → `_public/cli/fSnippetCli/Managers/DeleteLengthManager.swift`
    - **폴더 이동 (paidApp 잔존본)**: `NotificationNames.swift`, `KeyEventInfo.swift` 모두 `Core/` → `Data/`
* cliApp Facade 구조 (사후 분석으로 발견):
    - `SnippetFileManager`(cliApp/Data) → Facade. 내부 `SnippetRepository.shared` + `AbbreviationCalculator.shared` 위임. **`init(rootURL:)` 생성자 없음** → 메인 레포 호출 `SnippetFileManager(rootURL: sandbox)` 그대로 못 씀
    - `SnippetRepository.init(rootURL: URL? = nil)` 생성자 보유 → sandbox URL 주입 가능 (실 진입점)
    - `AbbreviationMatcher.init(snippetFileManager: SnippetFileManager = .shared)` — 시그니처 동일, 단 sandbox용 Repository로 조립한 Matcher 생성 불가 → **소스 1줄 수정 또는 테스트 후크 필요**
    - `PreferencesManager`에 `mockBasePath` 없음. 환경변수 `fSnippetCli_config` 후크는 살아있음 (`resolveAppRootPath` L29-30)
* 호환 API (그대로 사용 가능):
    - `SnippetRepository.init(rootURL:)`, `loadAllSnippets(reason:force:)`, `getSnippetFolders()`
    - `RuleManager.shared.loadRuleFile(at:)` — 동일
    - `AbbreviationCalculator.shared.getAbbreviation(for:)` — 신규 진입점 (구 SnippetFileManager.getAbbreviation 대응)
    - `AbbreviationMatcher.findSnippetCandidates(searchTerm:)` — 동일
* 옵션 재구성 (Facade 발견 반영):
    | 옵션                                                                                          | 작업량 | cliApp 소스 수정 | 위험도 | 미래성      |
    | :-------------------------------------------------------------------------------------------- | :----- | :--------------- | :----- | :---------- |
    | A. 메인 레포 `run_folder_tests.sh` 경로 재매핑 + FolderTestRunner cliApp Facade 호출로 재작성 | 중간   | ❌                | 중간   | 낮음        |
    | **B1. cliApp XCTest 이식 — `AbbreviationMatcher.init(repository:)` 편의 생성자 1건 추가**     | 작음   | ⚠️ 1건            | 낮음   | 높음 ⭐ 권장 |
    | B2. cliApp XCTest 이식 — Mock Facade 우회                                                     | 작음   | ❌                | 중간   | 중간        |
    | B3. cliApp XCTest 이식 — `SnippetRepository.swapRootForTests(_:)` 테스트 후크 추가            | 작음   | ⚠️ 1건            | 낮음   | 높음        |
* 구현 명세 (옵션 B1 권장):
    - **소스 수정 1건**: `cli/fSnippetCli/Core/AbbreviationMatcher.swift` — `init(repository: SnippetRepository)` 편의 생성자 추가 (정확한 필드 구조는 plan에서 결정)
    - **신규 테스트 자산** (`_public/cli/fSnippetCliTests/FolderTest/`):
        * `FolderTestRunnerTests.swift` — XCTestCase (메인 레포 `@main FolderTestRunner.swift` 변환)
        * `testTable_org.md` — 메인 레포로부터 복사
        * `Results/` — gitignored 결과 보관
    - **공용 헬퍼**: `_public/cli/fSnippetCliTests/TestUtils.swift` — Sandbox 생성/정리·`_rule.yml` 생성
    - Mock 5개 이식 불필요 — cliApp 실제 클래스(`RuleManager.shared`, `AbbreviationCalculator.shared`) 사용
    - **빌드 통합**: `cli/project.yml`의 `fSnippetCliTests` 타겟이 디렉터리 흡수 → 추가 설정 불필요
    - **본 이슈 완료 조건**: `xcodebuild test -scheme fSnippetCli` 컴파일 통과 (FolderTestRunnerTests 실행 결과 검증은 Issue124)
* 복잡도: **중간** — cliApp 소스 1건 미세 수정 + 신규 파일 3개. plan 작성 후 진행.
* 관련 영역: `cli/fSnippetCli/Core/AbbreviationMatcher.swift` (1건 수정), `cli/fSnippetCliTests/FolderTest/` (신규)
* 의존: 없음
* 후속: Issue124

## Issue124: [Test] FolderTest 33-case 회귀 실행 + `testTable_org.md` ↔ 현행 `_rule.yml` 동기화 (등록: 2026-05-14)
* 목적: Issue123에서 복구된 인프라로 33-case 매트릭스를 재실행하여 마지막 실행(2026-03-26 `result_latest.md` 전 항목 ✅) 대비 회귀 여부를 검증. 동시에 사용자 환경 `_rule.yml`(`~/Documents/finfra/fSnippetData/snippets/_rule.yml`, 2026-03-29 갱신)과 테스트 매트릭스 `testTable_org.md`(2026-03-26 기준)의 차이를 분석·동기화하여 회귀 신뢰성 확보.
* 의존: Issue123 (인프라 복구) 선행 필수
* 사전 발견된 매트릭스↔환경 불일치 (현재 IDE에 열린 `_rule.yml` 실측 기반):
    - `_case17`: 현재 `_rule.yml`에서 **누락** (`_case16` 다음에 `_case18`로 점프). `testTable1.md`는 `_case17` 정의 보유 (`suffix: {keypad_comma}`). → 매트릭스에 추가하거나 테스트에서 제외할지 결정 필요.
    - `_case13` / `_case14`: 현재 `_rule.yml`은 suffix/prefix가 `◊`. `testTable1.md`는 `{right_command}`. → 환경 변경에 매트릭스 동기화 필요.
    - 그 외 cases는 현재 yml과 일치 여부 전수 비교 필요 (`_case34` 등 추가 case 가능)
* 구현 명세:
    - 1단계 (실행): `_public/cli/_tool/folderTest/run_folder_test.sh` 1회 실행. 결과를 `_public/cli/fSnippetCliTests/FolderTest/Results/result_latest.md` 및 `result_<YYYYMMDD-HHmmss>.md`로 저장
    - 2단계 (회귀 분석): 33-case 중 실패 case 식별. 실패 분류:
        * **테스트 입력 자체 오류**: testTable_org.md ↔ 현행 `_rule.yml` 불일치 → 매트릭스 갱신
        * **엔진 회귀**: 동일 입력에서 매칭 실패 → 별도 후속 이슈로 분리 등록
    - 3단계 (동기화): 사용자 확인 후 `testTable_org.md` 업데이트 — `_case17` 처리, `_case13/14` suffix `{right_command}` → `◊` 갱신, 누락 case 추가 (`_case34` 등). 갱신 시 시계열 보관: `testTable_org_<YYYYMMDD>.md`
    - 4단계 (재실행): 동기화된 매트릭스로 재실행 → 전 항목 ✅ 통과 확인
    - 사용자 환경 비파괴: `setupSandbox()` 임시 폴더 사용으로 `~/Documents/finfra/fSnippetData/snippets/`는 미영향 (FolderTestRunner.swift L8 검증 완료)
* 검증:
    - `result_latest.md` 전 항목 ✅
    - 매트릭스 변경 시 git diff로 갱신 사유 명시
    - 엔진 회귀 발견 시 별도 이슈 번호 부여
* 복잡도: **중간** — 실행 자체는 자동이나 차이 분석·동기화에 설계 결정 포함. plan 작성 권장 가능. report는 결과가 회귀 또는 매트릭스 변경을 동반할 경우 권장.
* 관련 영역: `_public/cli/fSnippetCliTests/FolderTest/testTable_org.md` (또는 메인 레포 원본), `_public/cli/fSnippetCliTests/FolderTest/Results/`, `~/Documents/finfra/fSnippetData/snippets/_rule.yml` (참조)
* 후속: 엔진 회귀 발견 시 신규 이슈 분리 등록

# 📗 선택

# ✅ 완료

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
    - `cli/_doc_work/debug_TECH.md` — "CGEventTap callback hot-path 비용 → tap timeout 빈발 ..." 사례 등록

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
