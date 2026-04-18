---
name: Issue
description: fSnippetCli 이슈 관리
date: 2026-04-07
---

# Issue Management

- Issue HWM: 39
- Save Point: - 2026-04-13 (ed3ae75)

# 🤔 결정사항

# 🌱 이슈후보
1. 클립보드 히스토리 기능 중에서 고급 기능은 Paid 앱이 활성화 되어 있어야 실행 가능하게끔 해 줘 활성화 되어 있지 않다면 활성화 창[기존 코드 찾아서] 열게 해야함. 
    - Paid 앱의 기능이 모듈로 구성되어 있는지 확인
# 🚧 진행중

# 📕 중요

# 📙 일반

# 📗 선택

# ✅ 완료

## Issue39: [Doc/Code] paidApp_version.md 문서 현행화 및 PaidAppManager 정리 (등록: 2026-04-18, 해결: 2026-04-18, commit: a7089d3) ✅

* 목적: `cli/_doc_design/paidApp_version.md`를 현재 `PaidAppManager.swift` 구현(NSAlert 4버튼)과 일치시키고, dead parameter·파일명 오류 등 소스 결함 정리
* 완료 내용:
    - 📄 문서 갱신: 5.1절 (토스트 → NSAlert 모달), 5.3절 (위치조정 제거), 7절 (향후 고도화 완료 반영), 8.1절 (Issue823 연계 명시), 9절 (메서드명 showPaidOnlyToast → showPaidOnlyAlert), 10절 (NSAlert 패턴 유지)
    - 🔧 코드 정정:
        - `PaidAppManager.handlePaidFeature()`: dead parameter `relativeTo frame` 제거
        - 파일명 정정: `config.yaml` → `_config.yml` (line 159)
        - 호출부 2곳 인자 제거: HistoryPreviewView (line 197), HistoryViewer (line 282-283)
* 검증:
    - ✅ Release 빌드: BUILD SUCCEEDED
    - ✅ config.yaml 리터럴 제거: PaidAppManager에서만 처리 (마이그레이션 로직은 유지)
    - ✅ handlePaidFeature 호출부 정정: 인자 완전 제거
* 연계:
    - paidApp Issue823: `fsnippet://` URL Scheme 등록 — Issue39 이후 추가 구현 예정
    - paidApp Issue824: 메인 `_doc_design/` 동기화 (본 이슈 완료 후)

## Issue38: KeyRenderingManager visual_key_definitions.json 번들 누락 — 시작 로그 워닝 제거 (등록: 2026-04-17, 해결: 2026-04-17, commit: 7f8adfd) ✅

* 목적: `visual_key_definitions.json`이 fSnippetCli 번들에 포함되지 않아 앱 시작 시 WARNING 로그(`🎨 [KeyRenderingManager] visual_key_definitions.json not found in Bundle.`)가 항상 출력되는 문제 해결
* 구현:
    - `cli/fSnippetCli/visual_key_definitions.json` 추가 (fSnippet 원본 복사, 472B)
    - `cli/fSnippetCli.xcodeproj/project.pbxproj`에 3개 위치 등록 (PBXBuildFile / FileReference / Resources 빌드 단계)
    - 기존 `_config.yml`/`_rule.yml` 등록 패턴 준수
* 검증:
    - Release 빌드 BUILD SUCCEEDED
    - 번들 내 `fSnippetCli.app/Contents/Resources/visual_key_definitions.json` 포함 확인

## Issue35: UI 전체 다국어(i18n) 누락 — PlaceholderInputWindow·SnippetPopup·HistoryViewer 문자열 미등록 (등록: 2026-04-17, 해결: 2026-04-17, commit: 0043003) ✅

* 목적: `LocalizedStringManager.strings` 딕셔너리에 토스트 메시지만 등록되어 있고, UI 전반의 문자열 키가 누락되어 key 원문이 그대로 화면에 표시되는 문제 해결
* 해결:
    - `LocalizedStringManager.swift`에 전역 `L10n()` 헬퍼 함수 추가
    - en/ko/ja 3개 언어 50+ UI 키 등록 (placeholder, popup, history, viewer, alert 카테고리)
    - 7개 UI 파일에서 `Text("key")`/`NSLocalizedString`/하드코딩 영문 → `L10n()` 패턴으로 통일
    - 수정 파일: `LocalizedStringManager.swift`, `PlaceholderInputWindow.swift`, `HistorySearchBar.swift`, `UnifiedSnippetPopupView.swift`, `SnippetPopupView.swift`, `HistoryViewer.swift`, `UnifiedHistoryViewer.swift`
* 검증: Release 빌드 성공 (경고 0)

## Issue36: /run 커맨드에 full 옵션 추가 — ZTest 스니펫 확장 통합 테스트 자동화 (등록: 2026-04-14, 해결: 2026-04-17, commit: 8b236b9) ✅

* 목적: `/run full` 실행 시 testForCli 환경에서 ZTest 스니펫 확장까지 자동으로 검증하는 통합 테스트 흐름 구현
* 해결:
    - `cli/_tool/run.sh`에 `full` 분기 구현 (Step 0~9: kill → 환경변수 → 빌드·배포·실행 → ZTest 생성 → 키 입력 → 검증 → 알림 → 원복)
    - `cli/_tool/kill.sh`, `cli/_tool/send_right_cmd.py` 보조 스크립트 추가
    - `_config.yml`, `_rule.yml`, `_rule_for_import.yml` 번들 리소스 등록 (신규 환경에서 자동 복사)
    - `_config.yml` 기본 `log_level` "critical" → "info" 수정
    - `PreferencesManager.getDefaults()` fallback 기본값 "VERBOSE" → "info" 변경
    - TextEdit 포커스 경쟁 방지 + "Save Anyway" 다이얼로그 자동 처리

## Issue37: nPTiR 환경 정비 — 폴더 구조·SCAR 빈 파일·.gitignore 정비 (등록: 2026-04-14, 해결: 2026-04-14, commit: 6458058, 03c3bbd) ✅

* 목적: nPTiR 체계 원활 작업을 위한 사전 정비 (check-nNPTiR 리포트 기반)
* plan: `cli/_doc_work/plan/start-nPTiR_plan.md`
* task: `cli/_doc_work/tasks/start-nPTiR_task.md`
* 구현:
    - `cli/_doc_work/_rlease/` 오타 폴더 삭제
    - `cli/_doc_work/` 루트 파일 3개 → `plan/`, `report/` 하위 이동
    - `Issue.md` Issue29 참조 경로 업데이트
    - `z_done/` 완료 task 보관소로 활용 결정 (issue33_task.md 이동)
    - `.claude/commands/dev.md` 개발 주기 상세 내용 추가
    - `.gitignore` 중복 라인 제거

## Issue34: 스니펫 확장 후 포커스가 이전 앱으로 잘못 이동하는 버그 수정 (등록: 2026-04-14, 해결: 2026-04-14, commit: 8ab4824, 1ba0d59, 3c48133) ✅

* 목적: 스니펫 확장(특히 비팝업 직접 트리거) 후 현재 작업 앱(iTerm2 등)이 아닌 더 이전 앱(Sublime Text 등)으로 포커스가 이탈하는 버그 수정
* 원인:
    - 원인1 — stale `inputApp`: `AppActivationMonitor.inputApp`이 팝업 종료 시 초기화되지 않아 이전 앱 참조가 유지됨
    - 원인2 — `show_in_app_switcher` 미분기: paid 미설치 시에도 stale `inputApp.activate()`가 호출되어 잘못된 앱으로 포커스 이동
* 구현:
    - `cli/fSnippetCli/Core/KeyEventMonitor.swift`: `onExpansionSuccess`에서 `hidePopup(hideApp: false)`로 변경 (비팝업 확장 시 불필요한 activation 제거)
    - `cli/fSnippetCli/Core/PopupController.swift`: `wasVisible` 캡처 + paid/switcher 분기 — paid+switcher=true 시 `NSApp.hide(nil)`, 그 외 `NSWorkspace.shared.frontmostApplication?.activate()`로 stale inputApp 대체
    - `cli/fSnippetCli/UI/SnippetNonActivatingWindow.swift`: `NSApp.hide(nil)` 호출을 paid+show_in_app_switcher 조건으로 게이팅
* 검증: Release 빌드 경고 0 (BUILD SUCCEEDED)

## Issue33: v1 제거 대비 v2 슈퍼셋 전환 (스니펫/클립보드/통계/CLI 엔드포인트 v2 편입) (등록: 2026-04-13, 해결: 2026-04-13, commit: 74c2482) ✅

* 태스크 파일: [`cli/_doc_work/tasks/issue33_task.md`](cli/_doc_work/tasks/issue33_task.md)
* 목적: 향후 v1 API 제거 시 클라이언트가 v2로 마이그레이션 가능하도록, v2를 v1의 슈퍼셋으로 전환
* 구현 명세:
    - `api/openapi_v2.yaml`: v1 데이터 엔드포인트 19개 경로 추가 (tags 9개 포함) — 1,089 → 1,887줄
    - `cli/fSnippetCli/Managers/APIRouter.swift`: `/api/v2/` prefix 데이터 라우트 28개 추가 (기존 핸들러 재사용), var→let 경고 1건 수정
    - `cli/_tool/cmdTest/v2/`: 테스트 스크립트 17개 추가 (20~36번, snippet/clipboard/folder/stats/trigger/cli/reload)
* 검증:
    - Release 빌드 경고 0 (BUILD SUCCEEDED)

## Issue32: _tool 폴더 v1/v2 구조 정비 및 cmdTest v2 스크립트 신규 작성 (등록: 2026-04-13, 해결: 2026-04-13, commit: 47bcd29) ✅

* 목적: `cli/_tool` 폴더를 `cli/_doc_work/plan/api-v2_plan.md` 기준 및 fWarrange 레퍼런스 구조에 맞게 정비
* 구현 명세:
    - `apiTest/apiTest_plan_v1.md` (v1/ → 루트 이동), `apiTest_plan_v2.md` 신규 작성
    - `cmdTest/` flat 구조 → `v1/` (기존 스크립트 이동) + `v2/` (settings 신규) 분리
    - `cmdTest/cmdTest_plan.md` → `cmdTest_plan_v1.md` rename, `cmdTest_plan_v2.md` 신규
    - `cmdTest/v2/`: 00~11 정상 케이스 + E01~E03 에러 케이스 (settings 서브커맨드 기반)
    - `cmdTestDo.sh`: v1|v2|all|단건 인자 지원으로 업데이트 (apiTestDo.sh 동일 패턴)
* 검증:
    - 전체 48 files changed, 628 insertions, 103 deletions
    - git rename 정상 감지 (R 표시)

## Issue31: CLI 바이너리 v2 settings 서브커맨드 구현 (등록: 2026-04-13, 해결: 2026-04-13, commit: fda3595) ✅

* 목적: `fsnippetcli settings` 서브커맨드 추가 — 터미널에서 v2 Settings CRUD 직접 제어
* 구현 명세:
    - `CLI/Commands/SettingsCommand.swift` 신규: get/set/reset/snapshot 서브커맨드
    - `CLIAPIClient.swift`: PATCH, PUT, DELETE 메서드 추가
    - `CLIRouter.swift`: settings 케이스 분기 추가
    - `CommandParser.swift`: set/reset/snapshot 서브커맨드 인식 추가
    - `HelpCommand.swift`: settings 커맨드 설명 추가
    - `cmdTest/20~23`: settings cmdTest 시나리오 4개 추가
* 검증:
    - cmdTest 20~23 전체 PASS
    - Release 빌드 경고 0

## Issue30: v1/v2 API 테스트 스크립트 전면 재작성 (등록: 2026-04-13, 해결: 2026-04-13, commit: 436951f) ✅

* 목적: flat 구조 apiTest를 v1/v2 디렉터리로 분리, 미커버 v2 엔드포인트 구현 + 테스트 추가
* 구현 명세:
    - Phase 1: v1/(37개) + v2/(34개) 디렉터리 분리, 번호 재정렬
    - Phase 2: PATCH /settings/general, GET/PATCH /settings/history 신규 구현
    - Phase 2: 신규 테스트 스크립트 05/15/16 + 에러 케이스 E00~E06 재작성
    - Phase 3: apiTestDo.sh v1|v2|all|NN 인자 지원 추가
* 검증:
    - apiTestDo.sh v1 PASS, apiTestDo.sh v2 PASS
    - Release 빌드 경고 0

## Issue29: v2 API 전체 구현 — openapi_v2.yaml 38 paths / 59 operations (등록: 2026-04-13, 해결: 2026-04-13, commit: 2f015b1, a59926c, f7d4a11, 7b31e2b, 783edb7, d89d9fc, a946e3f, ed3ae75, 436951f) ✅

* 목적: `api/openapi_v2.yaml` 38 paths / 59 operations 구현. Issue30 테스트로 검증 완료.
* 완료 보고서: [`cli/_doc_work/report/issue29_completion_report.md`](cli/_doc_work/report/issue29_completion_report.md)
* 구현율: 39/63 endpoints (나머지 24개는 후속 이슈 대상)
* 검증:
    - v2 apiTest 스크립트 전체 PASS (v2/ 디렉터리 기준)

## Issue28: expand 응답 제어문자 이스케이프 처리 — jq 호환성 (등록: 2026-04-08, 해결: 2026-04-09, commit: a4556d2) ✅

* 목적: expand API 응답에서 제어문자가 포함될 때 jq 파싱이 실패하는 문제 해결
* 구현 명세:
    - `APIRouter.jsonResponse()`: Data→String→Data 왕복 변환 제거, 원본 Data 직접 전달
    - `APIServer.HTTPResponse`: `bodyData` 프로퍼티 추가
* 검증:
    - apiTest 30/30 PASS, jq/python3 JSON 파싱 정상
## Issue27: CRUD API 엔드포인트 추가 — 폴더/스니펫 생성/삭제 (등록: 2026-04-08, 해결: 2026-04-09, commit: a4556d2) ✅

* 목적: REST API를 통한 폴더 및 스니펫의 CRUD(생성/삭제) 기능 추가
* 구현 명세:
    - `POST /api/v1/folders`: 폴더 생성 (`handleCreateFolder`)
    - `DELETE /api/v1/folders/{name}`: 폴더 삭제 (`handleDeleteFolder`)
    - `POST /api/v1/snippets`: 스니펫 생성 (`handleCreateSnippet`)
    - `DELETE /api/v1/snippets/{id}`: 스니펫 삭제 (`handleDeleteSnippet`)
    - `APIModels.swift`: CRUD 요청/응답 모델 추가
    - `openapi.yaml`: 5개 엔드포인트 명세 동기화 완료
* 검증:
    - CRUD 시나리오 테스트 전체 PASS (폴더 생성→스니펫 생성→삭제→폴더 삭제)

## Issue26: POST /api/v1/reload 엔드포인트 추가 (등록: 2026-04-08, 해결: 2026-04-09, commit: a4556d2) ✅

* 목적: 테스트 자동화 및 설정 변경 반영을 위한 reload API 엔드포인트 추가
* 구현 명세:
    - `APIRouter.handleReload()`: settings/rules/snippets/index/triggers 5개 컴포넌트 리로드
    - `APIModels.swift`: `APIReloadResponse`, `APIReloadData` 모델 추가
    - `openapi.yaml`: `/reload` 엔드포인트 명세 추가
* 검증:
    - reload API 호출 시 5개 컴포넌트 정상 리로드 (2.6ms)

## Issue25: 스니펫 파일 삭제 시 캐시 즉시 무효화 — FSEvents 파일 레벨 감지 (등록: 2026-04-08, 해결: 2026-04-09, commit: a4556d2) ✅

* 목적: 스니펫 파일이 삭제되었을 때 SnippetFileManager 캐시가 즉시 무효화되도록 FSEvents 파일 레벨 감지 구현
* 구현 명세:
    - `SnippetFolderWatcher`: `kFSEventStreamCreateFlagFileEvents` 플래그 추가
    - `FileChangeEvent` 구조체: isRemoved/isFile/isCreated/isModified/isRenamed 프로퍼티
    - `fileEventCallback`: 파일 레벨 이벤트 즉시 전달 (디바운스 없이)
* 검증:
    - reload 후 snippet_count 즉시 반영 확인

## Issue24: paidApp_version.md에 따라 유료 전용 코드 삭제 (등록: 2026-04-08, 해결: 2026-04-09, commit: a4556d2) ✅

* 목적: `cli/_doc_design/paidApp_version.md`에 정의된 유료 전용 기능의 불필요한 코드를 fSnippetCli에서 제거
* 구현 명세:
    - `SettingsDraftManager.swift` 제거
    - 드래프트 모드 관련 코드 제거
    - 유료 안내 토스트만 유지
* 검증:
    - Release 빌드 성공 (error 0)

## Issue14: 다국어 설정(language: "kr") 미적용 (등록: 2026-04-08, 해결: 2026-04-09, commit: a4556d2) ✅

* 목적: `_config.yml`의 `language: "kr"` 설정이 fSnippetCli에 적용되지 않는 문제 해결
* 구현 명세:
    - `LocalizedStringManager`: 딕셔너리 기반 다국어 문자열 관리자 구현 (en/ko/ja)
    - `PreferencesManager.language`: config에서 언어 코드 읽기
    - 국가 코드 정규화 (kr→ko, jp→ja 등)
    - 토스트 메시지 4개 파일에서 `LocalizedStringManager.shared.string()` 사용
* 검증:
    - `/api/v1/settings` 응답에 config 정상 포함

## Issue13: 설정 저장 시 오른쪽 수식어 키({right_command}) 검증 실패 (등록: 2026-04-07, 해결: 2026-04-09, commit: a4556d2) ✅

* 목적: 오른쪽 수식어 트리거 키 사용 시 설정 저장(Apply)이 실패하는 버그 수정
* 구현 명세:
    - `SettingsObservableObject.validateSymbol()`: `{...}` 형식 허용 로직 추가
    - 에러 메시지 구분: 빈값/길이초과 분리 표시
* 검증:
    - Release 빌드 성공, `{right_command}` 검증 통과

## Issue12: [Alfred Import] 폴더 아이콘(icon.png) 임포트 전수 누락 (등록: 2026-04-07, 해결: 2026-04-09, commit: a4556d2) ✅

* 목적: Alfred Import 실행 시 원본 컬렉션의 icon.png가 fSnippet 스니펫 폴더에 복사되지 않는 문제 해결
* 구현 명세:
    - `AlfredImporter.importFromDB()`: `importIcons()` 호출을 스니펫 파일 쓰기 후로 이동 (line 358)
    - 대상 폴더 미존재 시 `createDirectory` 자동 생성
    - `SnippetIconProvider.shared.clearCache()` 호출로 즉시 반영
* 검증:
    - Release 빌드 성공

## Issue11: Alfred Import 기능을 fSnippetCli에서 구현 (등록: 2026-04-07, 해결: 2026-04-09, commit: a4556d2) ✅

* 목적: Alfred 스니펫 데이터베이스(.alfdb) 임포트 기능을 fSnippetCli에서 실행되도록 완성
* 구현 명세:
    - `AlfredImporter.swift`: `pickAndImport()`, `importFromDB()` 구현
    - `AlfredLogic.swift`: 파일명 생성/affix 제거/특수문자 변환 로직
    - `APIRouter.handleAlfredImport()`: `POST /api/v1/import/alfred` 엔드포인트
    - `openapi.yaml`: import/alfred 명세 동기화
* 검증:
    - apiTest 18.import-alfred PASS

## Issue20: 메뉴바에 설정/About 버튼 추가 및 유료 버전 분기 처리 (등록: 2026-04-08, 해결: 2026-04-09, commit: a4556d2) ✅

* 목적: MenuBarView에 설정(Settings) 버튼과 About 버튼을 추가하여 메뉴바에서 접근 가능하게 함
* 검증:
    - 사용자 확인 완료

## Issue23: API/CLI 테스트 체계 구축 — apiTest 30개 + cmdTest 26개 + openapi 교차 검증 (등록: 2026-04-08, 해결: 2026-04-08, commit: 3af08b7) ✅

* 목적: apiTest와 동일한 체계로 CLI 커맨드 테스트 자동화 + openapi.yaml 파라미터 교차 검증
* 구현 명세:
    - apiTest: 26 정상 + 4 에러 (curl 기반, optional 파라미터 커버 포함)
    - cmdTest: 20 정상 + 6 에러 (CLI 바이너리, exit code 검증)
    - apiTest_plan.md / cmdTest_plan.md: 교차 비교 테이블 포함
    - CRUD 시나리오 검증 (파일시스템 + API 조합)
    - _rule.yml prefix/suffix 검증 (`/run run-only`로 앱 재시작 후 확인)
    - validation_strategy.md: API 업그레이드 시 참조 가이드
* 검증:
    - apiTest 전체 PASS, cmdTest 26/26 PASS
    - openapi.yaml 전 엔드포인트 커버 확인

## Issue22: About 창 hang — MenuBarExtra 바인딩 피드백 루프 (등록: 2026-04-08, 해결: 2026-04-08, commit: 3ed36ff) ✅

* 목적: About 창 열기/닫기/링크 클릭 시 앱이 hang되는 문제 해결
* 상세:
    - 원인1: `fSnippetCliApp`에서 `@ObservedObject` + `@Published`의 `$appState.showMenuBar`를 `MenuBarExtra(isInserted:)`에 직접 바인딩 → `MenuBarExtraController` KVO가 setter 호출 → `@Published` 트리거 → SwiftUI 그래프 업데이트 → `makeMainMenu` 무한 루프
    - 원인2: `MenuBarView`의 `@State` + `onAppear` + `onReceive`가 메뉴 재빌드 시 상태 갱신 루프 유발
    - 원인3: `AboutWindowManager`에서 `NSLocalizedString` 사용했으나 CLI 번들에 `.lproj` 없어 키 노출
* 구현 명세:
    - `fSnippetCliApp.swift`: 커스텀 `Binding`으로 변경하여 KVO 피드백 루프 차단
    - `MenuBarView.swift`: `@State` + `onAppear` + `onReceive` 제거, 직접 읽기로 변경
    - `AboutWindowManager.swift`: `NSLocalizedString` → 직접 문자열
    - `CGEventTapManager.swift`: `RunLoop.main.perform` → `DispatchQueue.main.async`
* 검증:
    - About 창 열기/닫기/링크 클릭 정상 동작 확인
    - `sample` 명령으로 `makeMainMenu` 루프 해소 확인

## Issue21: 앱 검색 시 Xcode DerivedData 빌드 제외 — Release 앱만 탐지 (등록: 2026-04-08, 해결: 2026-04-08, commit: b25067a) ✅

* 목적: NSWorkspace.urlForApplication이 LaunchServices에 등록된 Xcode 디버그 빌드(DerivedData)를 반환하여 잘못된 앱을 실행하는 문제 수정
* 구현 명세:
    - PaidAppManager: `isReleaseAppURL()` 헬퍼 추가, `Library/Developer`·`DerivedData` 경로 필터링
    - SettingsWindowManager: `isPaidVersionInstalled()`, `openPaidAppSettings()` 동일 필터 적용
* 검증:
    - DerivedData 경로의 앱 URL은 무시되고 knownPaths 또는 정상 설치 경로만 사용됨

## Issue17: 메뉴바 "활성 스니펫: 0개" 항상 0 표시 버그 수정 (등록: 2026-04-08, 해결: 2026-04-08, commit: 9ffb457) ✅

* 목적: MenuBarView의 activeSnippetCount가 SnippetFileManager와 연동되지 않아 항상 0으로 표시되는 버그 수정
* 구현 명세:
    - `.onAppear`에서 `SnippetFileManager.shared.snippetMap.count` 조회
    - `NotificationCenter` 구독으로 실시간 갱신
    - 관련 파일: `MenuBarView.swift`
* 검증:
    - 사용자 확인 완료

## Issue16: CLI 커맨드라인 인터페이스 구현 — Phase 1~3 전체 (등록: 2026-04-08, 해결: 2026-04-08, commit: 93706f9) ✅

* 목적: 터미널에서 fSnippetCli를 직접 제어할 수 있는 CLI 커맨드 추가
* 구현 명세:
    - `main.swift`: CLI 인자 유무로 GUI/CLI 모드 분기 (하위 호환 유지)
    - `CLI/CLIRouter.swift`: 인자 파싱 및 커맨드 분기
    - `CLI/CommandParser.swift`: 커맨드/옵션 파싱
    - `CLI/CLIAPIClient.swift`: 동기식 REST API 호출 클라이언트
    - `CLI/OutputFormatter.swift`: text/json 출력 (한글 너비 처리 포함)
    - `CLI/Commands/`: 10개 커맨드 (help, version, status, snippet, clipboard, folder, stats, trigger, config, import)
* 검증:
    - Xcode Debug 빌드 성공 (경고 0개)
    - API 경로 정합성 확인 (모든 커맨드가 `/api/v1/` prefix 사용)

## Issue19: 메뉴바 아이콘을 번개 모양(bolt.fill)으로 변경 (등록: 2026-04-08, 해결: 2026-04-08, commit: a987aae) ✅

* 목적: 메뉴바 아이콘을 기존 text.cursor에서 번개 모양(bolt.fill)으로 변경
* 구현 명세:
    - `fSnippetCliApp.swift`의 MenuBarExtra systemImage를 `"text.cursor"` → `"bolt.fill"` 변경
* 검증:
    - Debug 빌드 성공, 앱 실행 확인

## Issue18: Homebrew Formula service 블록 제거 — 자동 시작은 앱(SMAppService) 전담 (등록: 2026-04-08, 해결: 2026-04-08, commit: 7879ac2) ✅

* 목적: Homebrew는 설치만 담당하고 자동 시작 관리는 앱 내 AutoStartManager(SMAppService)가 전담하도록 역할 분리
* 구현 명세:
    - `cli/Formula/fsnippetcli.rb`: service 블록 전체 제거, caveats를 앱 설정 안내로 변경
    - AutoStartManager.swift(SMAppService 기반) 유지
* 검증:
    - Formula에서 service 블록 제거 확인
    - AutoStartManager 코드 및 pbxproj 참조 정상 유지

## Issue15: cmd_design.md 업데이트 — Issue7~10 반영 (등록: 2026-04-08, 해결: 2026-04-08, commit: 400e265) ✅

* 목적: `cli/_doc_design/cmd_design.md`가 Issue7 이전에 작성되어 최신 변경사항 미반영
* 구현 명세:
    - `config` 커맨드: 설정 GUI 제거 반영, 읽기 전용 명시 (Issue5)
    - 유료 전용 기능 제한 섹션 추가 (Issue7~9)
    - `paidApp_version.md` 참조 링크 추가
* 검증:
    - 문서 내용 확인 완료

## Issue10: 유료 기능 목록 문서화 (등록: 2026-04-08, 해결: 2026-04-08, commit: 97da9b7) ✅

* 목적: Issue7, Issue8, Issue9를 포함한 유료 버전 전용 기능 목록을 `cli/_doc_design/paidApp_version.md`에 정리
* 구현 명세:
    - 유료 전용 기능 3개 (⌘S Save, 설정 단축키, Tab 편집) 목록화
    - 각 기능별 차단 파일, 안내 방식, 관련 이슈 기록
    - 유료 버전 연동 설계 (앱 탐지 경로 3개, URL Scheme/CLI Args 전달 방식)
* 검증:
    - `paidApp_version.md` 생성 확인, Issue7/8/9 참조 포함

## Issue9: 스니펫 팝업 Tab 키 편집 기능 유료 버전 전용 안내 (등록: 2026-04-08, 해결: 2026-04-08, commit: 1d536c5) ✅

* 목적: 스니펫 팝업창에서 Tab 키 입력 시 스니펫 편집/생성 기능이 유료 버전 전용임을 안내
* 구현 명세:
    - `SnippetPopupView.swift`의 `onEdit` 클로저: Tab 키 편집/생성 → 유료 안내 토스트
    - `handleEdit()` 함수: 행 편집 → 유료 안내 토스트
    - "Create New Snippet" 버튼 → 유료 안내 토스트
* 검증:
    - 사용자 확인 완료

## Issue7: ⌘S Save To Snippet 유료 버전 전용 안내 (등록: 2026-04-08, 해결: 2026-04-08, commit: 3d82f42) ✅

* 목적: 클립보드 히스토리에서 ⌘S 시 유료 버전 전용 기능임을 큰 토스트로 안내
* 상세:
    - HistoryViewer (list 모드) 및 HistoryPreviewView (preview 모드)의 ⌘S 핸들러 수정
    - ToastManager/OnScreenNotificationView에 fontSize 파라미터 추가 (동적 크기 조정)
    - 하단 shortcut 텍스트에 "(Paid Only)" 표시 추가
* 검증:
    - Release 빌드 성공 및 앱 배포 완료

## Issue8: 설정 단축키(^⇧⌘;) 유료 버전 전용 안내 (등록: 2026-04-08, 해결: 2026-04-08, commit: 260083e) ✅

* 목적: 설정 글로벌 단축키 입력 시 유료 버전 전용 기능임을 안내
* 구현 명세:
    - `KeyEventHandler.swift`의 `item.id == "settings.hotkey"` 분기에서 `toggleSettings()` → 유료 안내 토스트로 변경
* 검증:
    - Release 빌드 성공

## Issue6: 스니펫 팝업창 미동작 수정 (등록: 2026-04-08, 해결: 2026-04-08, commit: f00a4bd) ✅

* 목적: 스니펫 팝업창이 표시되지 않는 문제 해결
* 상세:
    - 팝업 호출 흐름: KeyEventMonitor → KeyEventHandler → PopupController.showPopup()
    - PopupController, UnifiedSnippetPopupView, SnippetPopupView 코드 존재 확인

## Issue5: 설정창 GUI 코드 제거 (등록: 2026-04-08, 해결: 2026-04-08, commit: f00a4bd) ✅

* 목적: 설정창 GUI는 fSnippet 메인 앱 기능이므로 fSnippetCli에서 제거
* 상세:
    - fSnippet 메인 앱(`../fSnippet/`)에 이미 동일 설정창 존재 확인됨
    - 제거 대상 파일: `Views/Settings/` 전체, `SettingsWindowManager.swift`, `SettingsObservableObject.swift`, `SettingsDraftManager.swift`
    - `PreferencesManager.swift`는 유지 (CLI 설정 로드에 필요)
    - `MenuBarView.swift`에서 설정 열기 메뉴 항목 제거

## Issue4: Homebrew Formula 서비스 관리 구현 (등록: 2026-04-08, 해결: 2026-04-08, commit: 92c01c2) ✅

* 목적: `brew services start/stop/restart fsnippetcli` 형태로 서비스 관리 가능하게 함
* 상세:
    - Formula 파일명 `fsnippet-cli.rb` → `fsnippetcli.rb` (Homebrew 소문자 정규화 규칙 준수)
    - 클래스명 `Fsnippetcli`, 서비스명 `fsnippetcli`
    - `service do` 블록: `opt_prefix`, `keep_alive`, `process_type :interactive` 설정
    - 코드 사이닝 스킵 (`CODE_SIGN_IDENTITY=-`, `CODE_SIGNING_REQUIRED=NO`)
    - 로컬 tap 생성 후 install/start/stop 전체 검증 완료
    - 관련 문서 전체 참조 업데이트 (README, CLAUDE.md, rules, agents, commands)
* 검증:
    - `brew install fsnippetcli` 성공 (41초, 10.7MB)
    - `brew services start/info/stop` 전체 정상 동작

## Issue3: GET /settings API 엔드포인트 추가 (등록: 2026-04-08, 해결: 2026-04-08, commit: f000b5c) ✅

* 목적: 설정 경로 및 _config.yml 내용을 API로 조회 가능하게 함
* 상세:
    - `GET /api/v1/settings` 엔드포인트 신규 추가
    - 응답에 appRootPath, configPath, _config.yml 파싱 값 포함
    - openapi.yaml 명세 동기화
    - 테스트 스크립트 `02.settings.sh` 추가

## Issue2: openapi.yaml 기반 API 테스트 스크립트 구현 (등록: 2026-04-07, 해결: 2026-04-08, commit: f000b5c) ✅

* 목적: openapi.yaml의 전체 엔드포인트를 curl 기반 shell 스크립트로 테스트 자동화
* 상세:
    - `cli/_tool/apiTest/` 디렉토리에 19개 테스트 스크립트 (0.hello.sh ~ 18.import-alfred.sh) 생성
    - 에러 케이스 4개 (E1 ~ E4) 추가
    - `apiTestDo.sh` 실행기로 전체/단건 실행 지원
    - Swift API 구현(APIRouter.swift)과 openapi.yaml 명세 일치 검증
* 구현 명세:
    - Shell Programmer 1: Status(0,1), Snippets(2-6), Clipboard(7-9)
    - Shell Programmer 2: Folders(10,11), Stats(12,13), Triggers(14), CLI(15-17), Import(18), Error(E1-E4)
    - Swift Programmer 1-3: openapi.yaml ↔ APIRouter.swift 엔드포인트 일치 검증

## Issue1: md-rule-apply 적용 - frontmatter 및 마크다운 규칙 정비 (등록: 2026-04-07, 해결: 2026-04-07, commit: f000b5c) ✅

* 목적: _public 전체 마크다운 파일에 md-rule-apply 규칙 적용
* 구현 명세:
    - 64개 파일에 frontmatter 추가 및 Outline/Bullet/Table 규칙 정비
    - README, API 문서, 매뉴얼, Gemini skills/workflows 등 전반적 정비
    - openapi.yaml 확장 (285줄 추가)
* 검증:
    - 마크다운 규칙 준수 확인

# ⏸️ 보류

# 🚫 취소

# 📜 참고
