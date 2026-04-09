---
name: paid_version
description: fSnippetCli 유료 버전 인식·실행·차단 설계 및 구현 현황
date: 2026-04-08
---

# 개요

fSnippetCli(무료 CLI 헬퍼)에서 fSnippet(유료 App Store 앱)을 인식하고 연동하는 전체 절차.
유료 앱이 설치되어 있으면 자동 실행하고 메뉴바를 숨기며, 유료 전용 기능 접근 시 적절히 분기 처리함.

* **fSnippetCli**: 비샌드박스 에이전트, 키 모니터링/텍스트 대체 엔진, REST API 서버
* **fSnippet**: App Store 배포 Sandbox GUI 앱 (유료)
* **관계**: fSnippetCli는 독립 실행 가능하되, fSnippet 설치 시 GUI 기능을 위임함

# 핵심 식별 정보

| 항목                  | 값                             |
| :-------------------- | :----------------------------- |
| paid 앱 Bundle ID     | `kr.finfra.fSnippet`           |
| fSnippetCli Bundle ID | `kr.finfra.fSnippetCli`        |
| 관리 클래스           | `PaidAppManager`               |
| 소스 파일             | `Managers/PaidAppManager.swift` |
| Sandbox               | paid=✅ / CLI=❌              |

# 1. paid 앱 탐지 (`isInstalled()`)

앱 시작 시 및 유료 기능 호출 시 아래 순서로 탐지.

## 1.1 경로 기반 탐지 (우선)

알려진 설치 경로에서 **실행 파일**까지 존재하는지 직접 확인:

| 우선순위 | 경로                                     | 검증 대상                                         |
| -------: | :--------------------------------------- | :------------------------------------------------ |
|        1 | `/Applications/fSnippet.app`             | `Contents/MacOS/fSnippet` 실행 파일 존재 여부     |
|        2 | `/Applications/_nowage_app/fSnippet.app` | `Contents/MacOS/fSnippet` 실행 파일 존재 여부     |

* 압축된 `.app`(실행 파일 없음)을 배제하기 위해 디렉토리 존재만이 아닌 **실행 파일까지 검증**

## 1.2 Bundle ID 기반 탐지 (fallback)

경로 탐지 실패 시 LaunchServices를 통해 Bundle ID로 조회:

```swift
NSWorkspace.shared.urlForApplication(withBundleIdentifier: "kr.finfra.fSnippet")
```

## 1.3 DerivedData 필터링 (Issue21)

LaunchServices가 Xcode DerivedData 빌드를 반환하는 문제를 방지:

```swift
private func isReleaseAppURL(_ url: URL) -> Bool {
    let path = url.path
    return !path.contains("Library/Developer") && !path.contains("DerivedData")
}
```

* `Library/Developer` 또는 `DerivedData` 경로가 포함된 URL은 무조건 제외
* 이 필터는 `isInstalled()` 와 `launchPaidApp()` 양쪽 모두에 적용

## 1.4 설계 결정: 경로 탐지 + LaunchServices 병용

| 방식                  | 장점                     | 단점                                  |
| :-------------------- | :----------------------- | :------------------------------------ |
| 경로 기반 (knownPaths) | 빠르고 예측 가능         | 사용자 커스텀 설치 경로 감지 불가     |
| LaunchServices (BID)  | 커스텀 설치 경로도 감지  | DerivedData 빌드 오탐지 가능          |

* fSnippetCli는 두 방식을 병용하되, DerivedData 필터로 오탐지 방지
* (참고: fWarrangeCli는 경로 기반만 사용하여 더 단순한 접근)

## 1.5 실행 상태 확인 (`isRunning()`)

```swift
NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "kr.finfra.fSnippet" }
```

# 2. 앱 시작 시 자동 실행 흐름

`AppDelegate.applicationDidFinishLaunching` (fSnippetCliApp.swift):

```
fSnippetCli 시작
│
├─ PaidAppManager.isRunning() == true
│  └─ 메뉴바 아이콘 숨김 (즉시)
│
├─ PaidAppManager.isInstalled() == true && isRunning() == false
│  └─ launchPaidApp() 호출 → 성공 시 메뉴바 숨김
│
└─ 둘 다 false
   └─ 메뉴바 아이콘 표시 (독립 모드)
```

## 핵심 원칙

* **REST 서버는 항상 유지**: paid 앱 실행 여부와 무관하게 `localhost:3015` REST API 활성화
* **메뉴바만 숨김**: `AppState.shared.showMenuBar` 플래그로 `MenuBarExtra(isInserted:)` 제어
* **앱 프로세스는 유지**: `NSApplication.terminate()` 호출하지 않음 — 키 모니터링/텍스트 대체 엔진은 계속 동작

# 3. paid 앱 실행/종료 실시간 감시

`setupPaidAppMonitoring()` (fSnippetCliApp.swift):

```
NSWorkspace.didLaunchApplicationNotification
└─ bundleIdentifier == "kr.finfra.fSnippet"
   └─ AppState.shared.showMenuBar = false (메뉴바 숨김)

NSWorkspace.didTerminateApplicationNotification
└─ bundleIdentifier == "kr.finfra.fSnippet"
   └─ AppState.shared.showMenuBar = true (메뉴바 복원)
```

* fSnippet 실행 → fSnippetCli 메뉴바 숨김 (유료 앱이 UI를 전담)
* fSnippet 종료 → fSnippetCli 메뉴바 복원 (독립 모드로 전환)

# 4. paid 앱 실행 (`launchPaidApp()`)

## 4.1 Bundle ID 기반 실행 (우선)

```swift
NSWorkspace.shared.urlForApplication(withBundleIdentifier: paidBundleID)
→ isReleaseAppURL() 필터
→ 실행 파일 존재 확인
→ NSWorkspace.shared.openApplication(at:configuration:)
```

## 4.2 경로 기반 실행 (fallback)

```swift
knownPaths 순회
→ Contents/MacOS/fSnippet 실행 파일 존재 확인
→ NSWorkspace.shared.open(URL(fileURLWithPath:))
```

# 5. 유료 전용 기능 차단 (`handlePaidFeature()`)

모든 유료 기능 차단은 `PaidAppManager.shared.handlePaidFeature()` 단일 진입점으로 통일됨.

## 5.1 분기 로직

```
handlePaidFeature() 호출
│
├─ isInstalled() == true
│  └─ launchPaidApp()
│     ├─ 성공 → 토스트: "fSnippet 실행됨\n기능을 다시 시도해주세요"
│     │         (아이콘: arrow.up.forward.app.fill, fontSize: 24)
│     └─ 실패 → showPaidOnlyToast()
│
└─ isInstalled() == false
   └─ showPaidOnlyToast()
      → 토스트: "Only Support\nthe Paid Version"
         (아이콘: lock.fill, fontSize: 28)
```

## 5.2 차단 위치 목록

| #  | 기능                | 차단 파일                               | 트리거              | 이슈    |
| -: | :------------------ | :-------------------------------------- | :------------------ | :------ |
|  1 | ⌘S Save To Snippet | `UI/History/HistoryViewer.swift`         | 히스토리 ⌘S         | Issue7  |
|  2 | ⌘S Save (Preview)  | `UI/History/HistoryPreviewView.swift`    | 프리뷰 ⌘S           | Issue7  |
|  3 | 설정 단축키 (^⇧⌘;) | `Core/KeyEventHandler.swift`            | 글로벌 핫키         | Issue8  |
|  4 | Tab 편집/생성       | `UI/SnippetPopupView.swift` (onEdit)    | 팝업 Tab 키         | Issue9  |
|  5 | 행 편집             | `UI/SnippetPopupView.swift` (handleEdit) | 팝업 행 클릭        | Issue9  |
|  6 | 스니펫 생성 버튼    | `UI/SnippetPopupView.swift`             | "Create New" 버튼   | Issue9  |
|  7 | 설정창 열기         | `Managers/SettingsWindowManager.swift`   | showSettings() 호출 | Issue20 |

## 5.3 토스트 위치 조정

히스토리/프리뷰 등 윈도우가 있는 컨텍스트에서는 `relativeTo:` 파라미터로 토스트 위치를 해당 윈도우 근처에 표시:

```swift
PaidAppManager.shared.handlePaidFeature(
    relativeTo: HistoryViewerManager.shared.window?.frame
)
```

# 6. 메뉴바 연동

## 6.1 메뉴바 아이콘 구분

fSnippetCli와 fSnippet을 시각적으로 구분하기 위해 아이콘에 대각선 클리핑 적용:

* SF Symbol: `bolt.fill`
* 클리핑: `NSBezierPath`로 아래 30%를 수평 클리핑 (위 70%만 표시)
* fSnippet(paid)는 온전한 아이콘, fSnippetCli는 잘린 아이콘으로 구분

## 6.2 MenuBarExtra 바인딩

`AppState.shared.showMenuBar`를 커스텀 Binding으로 연결 (Issue22):

```swift
MenuBarExtra(isInserted: Binding(
    get: { AppState.shared.showMenuBar },
    set: { AppState.shared.showMenuBar = $0 }
))
```

* `@ObservedObject` + `@Published` 직접 바인딩은 MenuBarExtraController KVO와 피드백 루프를 일으킴 → 커스텀 Binding으로 해결

## 6.3 상태 전환

| fSnippet 상태 | fSnippetCli 메뉴바 | 동작 주체              |
| :------------ | :----------------- | :--------------------- |
| 실행 중       | 숨김               | setupPaidAppMonitoring |
| 설치됨+미실행 | 숨김 (자동 실행 후) | applicationDidFinish   |
| 미설치        | 표시               | 기본값 (독립 모드)     |
| 종료 감지     | 복원               | setupPaidAppMonitoring |

# 7. Paid 미감지 시 알림 UX (향후 고도화)

현재는 토스트("Only Support the Paid Version")만 표시하지만, 향후 fWarrange 패턴처럼 3버튼 알림으로 고도화 가능:

```
showPaidOnlyAlert()
├─ [App Store] → macappstore:// URL 열기
├─ [Locate...] → NSOpenPanel으로 fSnippet.app 수동 선택
│   └─ Bundle ID 검증 (kr.finfra.fSnippet) 후 실행
└─ [Cancel] → 닫기
```

* `Locate...` 사용 시 `Bundle(url:).bundleIdentifier == "kr.finfra.fSnippet"` 검증 필수
* 검증 실패 시 "Invalid application" 경고 표시

# 8. 유료 버전 연동 설계 (향후)

## 8.1 URL Scheme (권장)

```bash
open "fsnippet://command?action=edit&snippet=keyword"
open "fsnippet://command?action=settings"
open "fsnippet://command?action=save&source=clipboard"
```

* fSnippet.app이 `fsnippet://` URL Scheme을 등록해야 함
* 장점: 앱이 이미 실행 중이면 기존 인스턴스로 전달됨

## 8.2 Command Line Arguments

```bash
open -a "/Applications/fSnippet.app" --args --action edit --snippet keyword
```

* 장점: URL Scheme 등록 없이 즉시 사용 가능
* 단점: 앱이 이미 실행 중이면 인자가 무시될 수 있음

# 9. 관련 소스 파일

| 파일                                    | 역할                                                              |
| :-------------------------------------- | :---------------------------------------------------------------- |
| `Managers/PaidAppManager.swift`         | `isInstalled`, `isRunning`, `launchPaidApp`, `handlePaidFeature`  |
| `fSnippetCliApp.swift`                  | `MenuBarExtra(isInserted:)` 바인딩, `setupPaidAppMonitoring`, 아이콘 클리핑 |
| `MenuBarView.swift`                     | Settings/About 버튼, paid 분기 호출                               |
| `Managers/SettingsWindowManager.swift`  | `showSettings()` → `PaidAppManager.handlePaidFeature()` 위임      |
| `Core/KeyEventHandler.swift`            | 설정 핫키 차단                                                     |
| `UI/SnippetPopupView.swift`             | Tab 편집/생성/행 편집 차단                                         |
| `UI/History/HistoryViewer.swift`        | ⌘S 히스토리 모드 차단                                              |
| `UI/History/HistoryPreviewView.swift`   | ⌘S 프리뷰 모드 차단                                                |

# 10. 향후 기능 추가 시 가이드

* 이 문서의 "5.2 차단 위치 목록" 테이블에 항목 추가
* `PaidAppManager.shared.handlePaidFeature()` 단일 진입점 사용
* 동일 토스트 패턴 유지 (`lock.fill`, fontSize 28)
* Issue.md에 이슈 등록 후 구현

# 11. 관련 이슈

| 이슈    | 내용                                    | 커밋    |
| :------ | :-------------------------------------- | :------ |
| Issue7  | ⌘S Save To Snippet 유료 전용 안내      | 3d82f42 |
| Issue8  | 설정 단축키(^⇧⌘;) 유료 전용 안내       | 260083e |
| Issue9  | 스니펫 편집 (Tab 키) 유료 전용 안내     | 1d536c5 |
| Issue10 | 유료 기능 목록 문서화                   | 97da9b7 |
| Issue20 | 메뉴바에 설정/About 버튼 + 유료 분기   | -       |
| Issue21 | DerivedData 빌드 제외 필터링            | b25067a |
| Issue22 | MenuBarExtra 바인딩 피드백 루프 수정    | 3ed36ff |

# 12. 향후 고려사항

* `knownPaths`에 경로 추가 시 배열 순서 = 탐지 우선순위
* paid 앱의 특정 창(설정/편집)을 직접 열어야 하는 경우 URL Scheme 또는 DistributedNotification 활용 필요
* 이슈후보 "paid_version.md에 따라 코드 삭제" 항목은 이 문서 기준으로 불필요한 paid 관련 코드 정리를 의미
