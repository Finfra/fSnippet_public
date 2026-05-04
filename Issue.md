---
name: Issue
description: fSnippetCli 이슈 관리
date: 2026-04-07
---

# Issue Management

* Issue HWM: 110
* Save Point :
      - 2026.05.05: cd4577e (Feat(Issue108): cliApp 메뉴바 항목 다국어 지원 — ko 번역 정비)
      - 2026.05.04: fddc8f4 (Feat(Issue106): cliApp 메뉴바 Quit 항목 paidApp 정책 분리)
      - 2026.05.04: e1984f6 (Fix(Issue105): Settings 단축키·메뉴바를 cliApp 자체 설정창으로 라우팅)
      - 2026.05.04: 0f57ebc (Fix(Issue104): Snippet Popup 메뉴/단축키 작동 — fSnippetShowPopup observer 추가)
      - 2026.05.04: 505e55d (Feat(Issue103): paidApp 동작 시 About 메뉴를 fSnippet 모드로 분기)
      - 2026.05.03: 24f2a1b (Fix(Issue101): NSWorkspace bundleIdentifier 매칭으로 zombie process 제거)
      - 2026.05.02: 2804aaa (Docs: Close Issue99 — menuBar_enhance.md 반영)
      - 2026.04.27: 0cacd11 (Feat(Cli): Issue84 — registerSnippet 단축키 메뉴 노출 + 등록 로직)

# 🤔 결정사항
* _doc_design/paid_cli_protocol.md 기준 진행(paidApp앱과 연동)
* _doc_design/menuBar_enhance.md 기준 진행(메뉴바)

# 🌱 이슈후보

# 🚧 진행중

## Issue109: [Bug/Design] Settings 라우팅 정책 불일치 — `SettingsWindowManager`가 stub이라 모든 Settings 진입이 paidApp 위임 (등록: 2026-05-05)
* 목적: Issue107 v1.2 설계 문서가 "Settings는 항상 cliApp 자체 설정창"으로 명시했으나, 실제 코드는 `SettingsWindowManager.swift:18-21`에서 `showSettings()` → `PaidAppManager.handlePaidFeature()`만 호출하는 stub. cliApp 자체 Settings UI는 존재하지 않음. 설계와 구현 정합성 회복
* 근본 원인:
    - `cli/fSnippetCli/Managers/SettingsWindowManager.swift:6-37`: `class SettingsWindowManager`가 stub. `showSettings()`/`toggleSettings()` 모두 `PaidAppManager.shared.handlePaidFeature()` 호출
    - `handlePaidFeature()`는 paidAppStatus에 따라 분기:
        - `started` → `PaidAppDetector.openSettings()` (paidApp URL Scheme)
        - `stopped` → "fSnippet이 필요합니다" alert
        - `notInstall` → "Only support the paid version" alert
    - **Issue105 fix는 placebo**였음: KeyEventHandler/MenuBarView 양쪽이 `SettingsWindowManager.toggleSettings()`로 통일됐지만 toggleSettings가 결국 handlePaidFeature를 호출하므로 paidApp 분기 로직이 그대로 작동
    - paidApp 압축 상태(executable 미존재) → `isInstalled()` false → "Only support paid version" alert이 그대로 표시됨
* 결정 필요 (택1):
    - **옵션 A** (대규모): cliApp 자체 Settings UI 신규 구현 — paidApp 의존 없이 _config.yml 기반 단축키·로깅·히스토리 옵션 편집 창 제작. SwiftUI 기반 Settings Scene 또는 NSWindow + SwiftUI hosted view. Issue107 v1.2 설계 그대로 유지
    - **옵션 B** (저비용): Issue107 v1.2 설계 갱신 — Settings는 paidApp 라우팅(현 코드 반영). 메뉴 라벨도 paidApp 분기에 맞춰 재설계 (예: paidApp 활성 시 "Open fSnippet Settings", 비활성 시 항목 비활성화 또는 안내). Issue105 hash `e1984f6` 회고 메모 추가
    - **옵션 C** (혼합): cliApp 자체 최소 Settings UI(_config.yml 일부 키만 편집) + paidApp 활성 시 paidApp Settings 위임 메뉴 별도 노출
* 영향:
    - 사용자: 현재 paidApp 미설치 사용자는 cliApp 단축키/설정을 변경할 수 없음 (옵션 B 채택 시 명시적 기록 필요)
    - 유지보수: 설계-코드 갭이 잔존하면 후속 이슈에서 같은 혼선 재발
    - paidApp Issue851/852 완료 후 paidApp 측 Settings 안정화 — paidApp 활성 시는 paidApp Settings로 위임이 자연스러움
* 구현 명세 (옵션 결정 후 분리):
    - 옵션 A 진행 시: `SettingsWindowManager` 실구현 + 단축키/로그/히스토리/일반 탭 SwiftUI View + 변경사항 _config.yml 저장 + 라이브 적용 알림
    - 옵션 B 진행 시: `_doc_design/menuBar_enhance.md` v1.2 → v1.3 갱신 (Settings 정책 섹션 재작성), Issue105 회고 노트, MenuBarView Settings 항목 paidAppStatus 분기 처리

## Issue110: [Refactor] PaidAppManager.handlePaidFeature를 AppStateManager.paidAppStatus 단일 진입점으로 통합 (등록: 2026-05-05)
* 목적: Issue107 v1.2 설계가 paidAppStatus 3-state enum을 단일 진입점으로 정의했으나, `handlePaidFeature()`는 여전히 `isInstalled()` + `isRunning()` 2-flag 체크 사용. 추상화 일관성 확보 + 후속 변경 시 단일 진입점 보장
* 근본 원인:
    - `cli/fSnippetCli/Managers/PaidAppManager.swift:124-...`: `handlePaidFeature()`가 `guard isInstalled() else {...}` + `if isRunning() {...}` 패턴 사용
    - `AppStateManager.shared.paidAppStatus`는 동일 정보를 enum으로 보유하나 `handlePaidFeature` 미사용
    - 동작은 동등하나, 향후 paidAppStatus 전이 정책 변경 시 두 곳을 동시 수정해야 하는 위험
* 구현 명세:
    - `handlePaidFeature()` 시그니처 유지, 내부 분기를 `switch AppStateManager.shared.paidAppStatus` 로 재작성
        - `case .started` → `PaidAppDetector.openSettings()` (또는 옵션 A 채택 시 `SettingsWindowManager` 자체)
        - `case .stopped` → `showRequirePaidAlert()`
        - `case .notInstall` → `showPaidOnlyAlert()`
    - 동작 동등성 단위 테스트 (각 상태에서 적절한 alert/창 노출)
    - 영향: paidApp 라이프사이클 NotificationCenter 갱신 → AppStateManager → handlePaidFeature 자동 동기화
* 영향: 기능 변경 없음. 코드 라인 수 감소 + 후속 이슈에서 paidAppStatus 정책 변경 시 단일 위치만 수정

# 📕 중요

# 📙 일반

# 📗 선택

# ✅ 완료

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
* 목적: paidApp Issue851(cliApp API ready 대기), Issue852(설정창 취소 사이드 이펙트) 후속 문서 정비. pairApp(fWarrange) `_doc_design/menuBar_enhance.md` v1.2 수준의 명세 보강
* 해결:
    - `_doc_design/menuBar_enhance.md` v1.1 → v1.2 개정 (로컬 전용 SSOT, gitignored)
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
* 영향: 코드 변경 없음 (로컬 SSOT 문서 개선만). paidApp Issue851/852 후속 정비를 위한 참조 문서 정합성 확보. `_doc_design/`은 `_public/.gitignore`에 의해 의도적 비추적이므로 본 변경은 로컬에만 유지됨

## Issue106: [Feat] cliApp 메뉴바 Quit 항목 paidApp 정책 분리 — `Quit fSnippet ⌘Q` + `Quit All` (등록: 2026-05-04, 완료: 2026-05-04) (Hash: fddc8f4)
* 목적: `_doc_design/menuBar_enhance.md:53-54` 정책 — paidApp 활성 시 cliApp 메뉴에 paidApp 단독 종료(`Quit fSnippet ⌘Q`) + cliApp Quit All(`Quit All`, 단축키 없음) 두 항목 노출. paidApp 비활성 시 `Quit All` 단일 항목(단축키 없음). pairApp Issue70(fWarrange) 동일 패턴
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
* 수정 파일: `cli/fSnippetCli/Managers/PaidAppManager.swift`, `cli/fSnippetCli/MenuBarView.swift`, `_doc_design/menuBar_enhance.md`

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
