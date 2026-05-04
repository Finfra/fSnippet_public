---
name: Issue
description: fSnippetCli 이슈 관리
date: 2026-04-07
---

# Issue Management

* Issue HWM: 104
* Save Point :
      - 2026.05.04: 505e55d (Feat(Issue103): paidApp 동작 시 About 메뉴를 fSnippet 모드로 분기)
      - 2026.05.03: 24f2a1b (Fix(Issue101): NSWorkspace bundleIdentifier 매칭으로 zombie process 제거)
      - 2026.05.02: 2804aaa (Docs: Close Issue99 — menuBar_enhance.md 반영)
      - 2026.04.27: 0cacd11 (Feat(Cli): Issue84 — registerSnippet 단축키 메뉴 노출 + 등록 로직)

# 🤔 결정사항
* _doc_design/paid_cli_protocol.md 기준 진행(paidApp앱과 연동)
* _doc_design/menuBar_enhance.md 기준 진행(메뉴바)

# 🌱 이슈후보

# 🚧 진행중

## Issue104: [Bug] Snippet Popup 메뉴/단축키 작동 안 함 — fSnippetShowPopup 알림 수신자 누락 (등록: 2026-05-04)
* 목적: 메뉴바 "⚡ Snippet Popup" 클릭과 `^⇧Space` 단축키 모두 무반응. `fSnippetShowPopup` 알림 발행처(`MenuBarView`, `ShortcutMgr`)는 있으나 `KeyEventMonitor`/Handler 측 observer가 등록되어 있지 않아 위임 체인이 끊김 (Issue429 도입 시 수신부 누락)
* 근본 원인:
    - `MenuBarView.swift:31`, `ShortcutMgr.swift:671` 가 `NotificationCenter.post(name: "fSnippetShowPopup")` 발행
    - 그러나 `KeyEventMonitor.setupObservers()` (line 154~168) 에 해당 알림 observer 등록 누락 — 발행만 되고 수신 없음
    - PopupController는 singleton 아님 (`KeyEventMonitor.init` 에서 인스턴스 생성·주입) → 외부 직접 호출 불가
* 구현 명세:
    - `KeyEventHandler.swift`: `showSnippetPopupRequest()` public 메서드 추가 — 빈 candidates + 빈 searchTerm 으로 popupController.showPopup 호출 (line 158 분기 → Top 10 자동 표시), onSelection 에서 expansionCoordinator 통한 expansion
    - `KeyEventMonitor.swift`: `setupObservers()` 에 `fSnippetShowPopup` observer 등록 + `@objc handleShowPopupRequest` 핸들러 추가, main thread 에서 `keyEventHandler.showSnippetPopupRequest()` 호출
    - 검증: Release 빌드 통과 + 메뉴 클릭/단축키 둘 다 팝업 표시 확인

# 📕 중요

# 📙 일반

# 📗 선택

# ✅ 완료

## Issue103: [Menu] paidApp 동작 시 About 메뉴를 fSnippet 모드로 전환 (등록: 2026-05-04, 완료: 2026-05-04) (Hash: 505e55d)
* 목적: paidApp 동작 중일 때 cliApp 메뉴바 About 라벨/창 내용을 fSnippet 제품 기준으로 분기
* plan: `cli/_doc_work/plan/about-paidapp-mode_plan.md`
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
