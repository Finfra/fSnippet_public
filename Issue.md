---
name: Issue
description: fSnippetCli 이슈 관리
date: 2026-04-07
---

# Issue Management

- Issue HWM: 31
- Save Point: - 2026-04-13 (ed3ae75)

# 🤔 결정사항

# 🌱 이슈후보
1./Users/nowage/_git/__all/fWarrange/_public/cli/_doc_work/api_cmd_testScript_plan_for_v2.md 참고해서 api와 cli 테스트 스크립트 업데이트. 29완료후. 
2. all clear test할 것. _config.yml기본 값 확인
# 🚧 진행중

## Issue30: v1/v2 API 테스트 스크립트 전면 재작성 — 디렉터리 분리 + 커버리지 확장 (등록: 2026-04-13)

* 목적: 현재 flat 구조(`cli/_tool/apiTest/00~80.sh`)를 v1/v2 디렉터리로 분리하고, Issue29에서 미커버된 v2 엔드포인트 테스트 스크립트를 일괄 추가함. 구현 명세: `cli/_doc_work/apiTest_plan_v1v2.md`
* 의존성: Issue29 완료 (APIRouter v2 전 엔드포인트 구현) ✅
* 구현 단계 (apiTest_plan_v1v2.md §"3단계 구현 계획" 순서):
    1. **Phase 1 — 디렉터리 분리**: 기존 `00~29.sh` → `v1/` 이동, `30~80.sh` → `v2/` 이동 + 번호 재정렬
        - `v1/`: 00~29 정상, E01~E08 에러 (총 37개)
        - `v2/`: 00~60 정상, E00~E07 에러 (기존 이동분 + 신규 합산)
        - `apiTestDo.sh` 업데이트: `v1|v2|all|NN` 인자 지원, 각 디렉터리 분기 실행
    2. **Phase 2 — 신규 v2 스크립트 추가**: apiTest_plan_v1v2.md §"신규 v2 스크립트" 우선순위 순
        - General 하위 경로: `v2/05~09.sh` (language/appearance/paths/trigger-key/trigger-bias)
        - History: `v2/15~16.sh` (GET + clear POST)
        - Advanced API: `v2/18.sh` (/settings/advanced/api GET/PATCH)
        - Snapshot restore: `v2/61.sh` (PUT 실제 복원 검증)
        - Language/Appearance: `v2/70~72.sh`
        - 에러 케이스 보강: `v2/E00~E07.sh`
        - **주의**: General 하위, History, Advanced/API 신규 스크립트는 해당 API 구현 선행 필요
    3. **Phase 3 — 문서화 + 전체 실행**: README 업데이트, `apiTestDo.sh all` PASS 확인
* 구현 명세: [`cli/_doc_work/apiTest_plan_v1v2.md`](cli/_doc_work/apiTest_plan_v1v2.md) (스크립트 목록, 번호 매핑, runner 설계 포함)
* 검증:
    - `apiTestDo.sh v1` — v1 전체 PASS
    - `apiTestDo.sh v2` — v2 전체 PASS (구현된 엔드포인트 대상)
    - `apiTestDo.sh all` — 전체 PASS
    - Release 빌드 경고 0

# 📕 중요

# 📙 일반

## Issue31: CLI 바이너리 v2 settings 서브커맨드 구현 (등록: 2026-04-13)

* 목적: `fsnippetcli settings` 서브커맨드를 추가하여 터미널에서 v2 Settings CRUD를 직접 제어할 수 있도록 함. 현재 `CLI/Commands/`는 `/api/v1/`만 호출하므로 v2 엔드포인트 접근 불가.
* 상세:
    - `CLI/Commands/SettingsCommand.swift` 신규 생성:
        - `settings get [key]` — v2 GET 엔드포인트 호출, key 생략 시 전체 설정 출력
        - `settings set <key> <value>` — v2 PATCH 엔드포인트 호출 (ex: `popup.popupRows 10`)
        - `settings reset [--confirm]` — `POST /api/v2/settings/actions/reset-settings` + confirm 토큰 전달
        - `settings snapshot [export|import] [file]` — GET/PUT snapshot, json 파일 입출력
    - `CLI/CLIRouter.swift` — `settings` 케이스 분기 추가
    - `CLI/CommandParser.swift` — settings 서브커맨드 파싱 로직 추가
    - `cli/_doc_design/cmd_design.md` — `settings` 커맨드 스펙 섹션 추가
    - cmdTest 확장 — `cli/_tool/cmdTest/` (또는 Issue30 이후 `cmdTest/v2/`) 에 settings 시나리오 추가
* 의존성:
    - Issue29 완료 ✅ (APIRouter v2 쓰기 엔드포인트 구현)
    - Issue30 완료 권장 (cmdTest 디렉터리 구조 확정 후 통합 용이)
* 검증:
    - `fsnippetcli settings get general` → JSON 응답 출력
    - `fsnippetcli settings set popup.popupRows 10` → 설정 반영 확인
    - `fsnippetcli settings reset --confirm` → 403 없이 정상 리셋
    - cmdTest settings 시나리오 전체 PASS
    - Release 빌드 경고 0

# 📗 선택

## Issue28: expand 응답 제어문자 이스케이프 처리 — jq 호환성 (등록: 2026-04-08, 해결: 2026-04-09, commit: a4556d2) ✅

* 목적: expand API 응답에서 제어문자가 포함될 때 jq 파싱이 실패하는 문제 해결
* 구현 명세:
    - `APIRouter.jsonResponse()`: Data→String→Data 왕복 변환 제거, 원본 Data 직접 전달
    - `APIServer.HTTPResponse`: `bodyData` 프로퍼티 추가
* 검증:
    - apiTest 30/30 PASS, jq/python3 JSON 파싱 정상

# ✅ 완료

## Issue29: v2 API 전체 구현 — openapi_v2.yaml 38 paths / 59 operations (등록: 2026-04-13, 해결: 2026-04-13, commit: 2f015b1, a59926c, f7d4a11, 7b31e2b, 783edb7, d89d9fc, a946e3f, ed3ae75) ✅

* 목적: `api/openapi_v2.yaml` 38 paths / 59 operations를 `APIRouter.swift` + `APIModels.swift`에 구현. 명세-구현-테스트 3-way 불일치 해소.
* 완료 보고서: [`cli/_doc_work/issue29_completion_report.md`](cli/_doc_work/issue29_completion_report.md)
* 구현 명세:
    - Step1+2: Foundation 보강 + Writable Simple PATCH (`2f015b1`)
    - Step3a: Shortcuts GET/PUT/DELETE + 409 충돌 감지 (`a59926c`)
    - Step3b: Snippet Folders GET/PATCH + rebuild POST (`f7d4a11`)
    - Step3c: Excluded Files per-folder + global CRUD (`7b31e2b`)
    - Step4: Danger Zone actions + ConfirmRequest guard (`783edb7`)
    - Step5: Alfred Import async job (202 + jobId) (`d89d9fc`)
    - Step6: Snapshot PUT (구조 검증) (`a946e3f`)
    - Step7: API v2 문서화 (`ed3ae75`)
* 구현율: 39/63 endpoints (General 하위·History·Snapshot 복원 등 24개는 후속 이슈 대상)
* 검증:
    - v2 apiTest 스크립트 25개 PASS (30~34, 40~44, 45~53, 60~62, 70~71, 80, E10, E20~E25)
    - Release 빌드 경고 0

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

## Issue24: paid_version.md에 따라 유료 전용 코드 삭제 (등록: 2026-04-08, 해결: 2026-04-09, commit: a4556d2) ✅

* 목적: `cli/_doc_design/paid_version.md`에 정의된 유료 전용 기능의 불필요한 코드를 fSnippetCli에서 제거
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
    - `paid_version.md` 참조 링크 추가
* 검증:
    - 문서 내용 확인 완료

## Issue10: 유료 기능 목록 문서화 (등록: 2026-04-08, 해결: 2026-04-08, commit: 97da9b7) ✅

* 목적: Issue7, Issue8, Issue9를 포함한 유료 버전 전용 기능 목록을 `cli/_doc_design/paid_version.md`에 정리
* 구현 명세:
    - 유료 전용 기능 3개 (⌘S Save, 설정 단축키, Tab 편집) 목록화
    - 각 기능별 차단 파일, 안내 방식, 관련 이슈 기록
    - 유료 버전 연동 설계 (앱 탐지 경로 3개, URL Scheme/CLI Args 전달 방식)
* 검증:
    - `paid_version.md` 생성 확인, Issue7/8/9 참조 포함

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
