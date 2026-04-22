---
name: menubar-cli-ownership_plan
description: menubar 아이콘을 cliApp 단일 소유로 통합하고 paidApp 종료 시 REST kill로 cliApp도 함께 종료되도록 3-앱 조율
date: 2026-04-20
issue: Issue52
---

# 배경 및 목표

## 문제

* paidApp(fSnippet, #15)과 cliApp(fSnippetCli, #25)이 **각각 메뉴바 아이콘**을 관리함
* 사용자가 종료하려면 **메뉴바 아이콘 2개를 따로 닫아야 함** — UX 저하
* pairApp(fWarrangeCli, #26)도 동일 구조로 향후 동일 문제 발생 예정

## 목표

| 목표                          | 달성 방식                                         |
| :---------------------------- | :------------------------------------------------ |
| 메뉴바 아이콘 단일 소유       | cliApp만 표시, paidApp은 제거                     |
| 종료 시 단일 클릭             | paidApp 종료 시 REST로 cliApp kill → 동시 종료    |
| paidApp 메뉴 기능 보존        | paidApp 메뉴 항목을 cliApp 메뉴로 이전            |
| paidApp 인지 가능             | cliApp이 paidApp 설치·실행 여부 감지하여 분기     |
| pairApp 확장 가능             | cliApp 패턴을 pairApp에도 적용 (후속 이슈)         |

## 비목표 (YAGNI)

* paidApp·cliApp 상호 심층 통합 (단일 바이너리화 등)
* 메뉴바 아이콘 외의 UI 변경
* 기존 REST API v1 하위호환 깨뜨리기

# 적용 범위

## 프로젝트별 작업 분담

| 프로젝트                          | 레포 위치                         | 작업 성격       | 이슈 번호 |
| :-------------------------------- | :-------------------------------- | :-------------- | :-------- |
| cliApp (fSnippetCli, #25)         | `_public/` (현재)                 | **실제 구현**   | TBD (본 plan) |
| paidApp (fSnippet, #15)           | `~/_git/__all/fSnippet/` (상위)   | **이슈 등록**   | 별도 발급 |
| pairApp (fWarrangeCli, #26)       | `~/_git/__all/fWarrange/`         | **후속 이슈**   | 별도 발급 |

## 영향 파일 (cliApp)

| 경로                                                        | 변경 유형     | 책임                                                     |
| :---------------------------------------------------------- | :------------ | :------------------------------------------------------- |
| `cli/fSnippetCli/fSnippetCliApp.swift`                      | 수정          | **Phase 0** — `applicationWillTerminate` 에 brew stop 통합 |
| `cli/fSnippetCli/MenuBarView.swift`                         | 수정          | **Phase 0** 선행 brew stop 호출 제거 + **Phase 3** paidApp 섹션 추가 |
| `cli/_tool/kill.sh`                                         | 수정          | **Phase 0** — brew service 잔존 fallback 체크            |
| `cli/_tool/fsc-run-xcode.sh`                                | 수정          | **Phase 0** — kill_app 후 fallback 체크                  |
| `cli/fSnippetCli/Managers/APIRouter.swift`                  | 수정          | **Phase 1** — `/api/v2/shutdown` 라우팅                  |
| `cli/fSnippetCli/Managers/APIServer.swift`                  | 수정 (필요 시) | **Phase 1** — POST body 파싱 지원                         |
| `cli/fSnippetCli/Data/APIModels.swift`                      | 수정          | **Phase 1** — `ShutdownRequest/Response`                 |
| `cli/fSnippetCli/Utils/` (신규)                             | 생성          | **Phase 2** — `PaidAppDetector.swift`                    |
| `api/openapi_v2.yaml`                                       | 수정          | **Phase 1** — `/shutdown` 엔드포인트 명세                |

# 구현 순서

## Phase 0 — 종료 경로 단일화 (delegate 통합 + 스크립트 fallback)

**배경**: 현재 `BrewServiceSync.onAppStop` 은 메뉴바 "종료" 버튼 1곳에서만 호출됨. API `/api/cli/quit`, `SettingsObservableObject`, `MenuBarManager`, `KeyEventProcessor`, `RuleManager`, `Relauncher` 등 N개 `NSApp.terminate` 경로는 **brew stop 을 bypass** → Phase 1의 `/shutdown` API 도입 전에 해결해야 전 경로가 일관되게 동작함.

**리스크 검증 완료**:

* `keep_alive successful_exit: false` — `NSApp.terminate` 정상 종료는 launchd respawn 없음
* `onAppStop` 내부 `isServiceLoaded()` early-return — 이중 호출에 안전
* 2초 blocking 은 메뉴바에서 이미 실사용 중 (위치만 이동, 체감 지연 동일 또는 감소)

### Task 0-1: applicationWillTerminate 에 brew stop 통합

**Files:**

* Modify: `_public/cli/fSnippetCli/fSnippetCliApp.swift` (line 114~119 주변)

- [ ] **Step 1: `BrewServiceSync.onAppStop` 을 delegate 최상단으로 이동**

```swift
func applicationWillTerminate(_ notification: Notification) {
    // Issue52 Phase0: 모든 종료 경로(메뉴바·API·SettingsVM·Relauncher 등)의 공통 수렴점.
    // brew 가 started 상태면 여기서 stop 하여 브루 상태 일관성 보장.
    // timeout 3.0s: macOS 종료 허용 시간(5~20s) 내 충분한 여유.
    BrewServiceSync.onAppStop(timeout: 3.0)

    // 기존 리소스 정리
    SnippetFileManager.shared.stopFolderWatching()
    APIServer.shared.stop()
    logI("fSnippetCli 종료")
}
```

- [ ] **Step 2: 빌드 확인**

Run: `xcodebuild -project _public/cli/fSnippetCli.xcodeproj -scheme fSnippetCli -configuration Debug build`
Expected: BUILD SUCCEEDED

### Task 0-2: MenuBarView 선행 호출 제거

**Files:**

* Modify: `_public/cli/fSnippetCli/MenuBarView.swift` (line 68~77 주변)

- [ ] **Step 1: 종료 버튼 핸들러 단순화**

```swift
Button {
    // Issue52 Phase0: applicationWillTerminate 가 단일 수렴점 — brew stop 은 delegate 전담.
    NSApplication.shared.terminate(nil)
} label: {
    Label("종료", systemImage: "power")
}
.keyboardShortcut("q")
```

- [ ] **Step 2: 주석 정리**

Line 70~72의 `Issue51 Phase2: 메뉴바 종료 시 brew services stop 선행` 주석 제거.

### Task 0-3: kill.sh 에 brew 잔존 fallback 추가

**Files:**

* Modify: `_public/cli/_tool/kill.sh`

- [ ] **Step 1: pkill 후 launchctl 확인 블록 추가**

기존 `pkill -9 -f "MacOS/$PROJECT_NAME"` 뒤, `REMAIN` 확인 블록 직전에 삽입:

```bash
# Issue52 Phase0: delegate 가 정상 수행되면 brew=stopped 가 되지만,
# SIGKILL / crash 경로는 delegate 를 건너뛰므로 fallback 체크.
sleep 2
if launchctl list 2>/dev/null | grep -q "homebrew.mxcl.fsnippet-cli"; then
    echo "⚠️ brew service 잔존 — fallback: brew services stop"
    brew services stop fsnippet-cli 2>&1 | tail -1 || true
else
    echo "✅ brew service 정상 정지 (delegate 경유)"
fi
```

### Task 0-4: fsc-run-xcode.sh 의 kill_app 후속 처리

**Files:**

* Modify: `_public/cli/_tool/fsc-run-xcode.sh` (`kill_app` 함수)

- [ ] **Step 1: kill_app 에 fallback 체크 추가**

```bash
kill_app() {
    echo "[kill] $PROJECT_NAME 프로세스 종료"
    pkill -f "MacOS/$PROJECT_NAME" 2>/dev/null || true
    # Issue52 Phase0: delegate 정상 경유 시 brew=stopped, SIGKILL 경로 fallback
    sleep 1
    if brew_service_running; then
        echo "[kill] ⚠️ brew service 잔존 — fallback stop"
        brew services stop "$BREW_FORMULA" 2>&1 | tail -1 || true
    fi
}
```

### Task 0-5: 수동 검증 (4 경로 회귀 테스트)

- [ ] **A. 메뉴바 "종료" 클릭**

1. `brew services start fsnippet-cli` 로 started 상태 조성
2. 메뉴바에서 "종료" 클릭
3. `launchctl list | grep fsnippet` 결과 없어야 함 (delegate에서 brew stop 정상 수행)
4. 로그에 `[brew-sync] ✅ brew services stop 성공` 확인

- [ ] **B. API `/api/cli/quit` 호출**

```bash
curl -X POST http://localhost:3015/api/cli/quit -H "X-Confirm: true"
sleep 2
launchctl list | grep fsnippet   # 출력 없어야 함
```

- [ ] **C. `kill.sh` 실행 (정상 경로)**

```bash
bash cli/_tool/kill.sh
launchctl list | grep fsnippet   # 출력 없어야 함
```

로그 출력 `✅ brew service 정상 정지 (delegate 경유)` 확인.

- [ ] **D. `kill -9` 시뮬레이션 (fallback 경로)**

```bash
PID=$(pgrep -f "MacOS/fSnippetCli")
kill -9 $PID
bash cli/_tool/kill.sh   # 잔존 프로세스 없으므로 fallback 블록에서 brew stop 해야 함
launchctl list | grep fsnippet   # 출력 없어야 함
```

로그 출력 `⚠️ brew service 잔존 — fallback: brew services stop` 확인.

### Task 0-6: 커밋

- [ ] **Step 1: Phase 0 단일 커밋**

```bash
git add _public/cli/fSnippetCli/fSnippetCliApp.swift \
        _public/cli/fSnippetCli/MenuBarView.swift \
        _public/cli/_tool/kill.sh \
        _public/cli/_tool/fsc-run-xcode.sh
git commit -m "Feat(Issue52 Phase0): 종료 경로 단일화 — applicationWillTerminate 로 brew stop 통합

* BrewServiceSync.onAppStop 을 delegate 로 이동 (timeout 2.0 → 3.0s)
* MenuBarView 선행 호출 제거 (중복 방지)
* kill.sh·fsc-run-xcode.sh 에 launchctl 잔존 체크 fallback 추가
* 근거: NSApp.terminate 경로 N개가 brew stop 을 bypass 하던 문제 해결
* 리스크: keep_alive successful_exit:false 로 respawn 없음, early-return 안전"
```

## Phase 1 — cliApp: shutdown REST API 추가

### Task 1-1: OpenAPI 명세 선행 업데이트

**Files:**

* Modify: `_public/api/openapi_v2.yaml`

- [ ] **Step 1: `/shutdown` 엔드포인트 추가**

```yaml
/shutdown:
  post:
    summary: cliApp 프로세스 종료
    description: paidApp 종료 시 cliApp도 함께 종료시키기 위한 엔드포인트
    requestBody:
      required: false
      content:
        application/json:
          schema:
            type: object
            properties:
              reason:
                type: string
                description: 종료 사유 (로그 기록용)
                example: "paidApp shutdown"
              delayMs:
                type: integer
                description: 종료 지연 (밀리초). 기본 0
                default: 0
    responses:
      '200':
        description: 종료 수락 (실제 종료는 응답 전송 직후)
        content:
          application/json:
            schema:
              type: object
              properties:
                accepted:
                  type: boolean
                message:
                  type: string
```

- [ ] **Step 2: 커밋**

```bash
git add _public/api/openapi_v2.yaml
git commit -m "Docs(API v2): /shutdown 엔드포인트 명세 추가 (menubar-cli-ownership)"
```

### Task 1-2: API 응답 모델 추가

**Files:**

* Modify: `_public/cli/fSnippetCli/Data/APIModels.swift`

- [ ] **Step 1: 모델 정의 추가**

```swift
struct ShutdownRequest: Codable {
    let reason: String?
    let delayMs: Int?
}

struct ShutdownResponse: Codable {
    let accepted: Bool
    let message: String
}
```

- [ ] **Step 2: 빌드 확인**

Run: `xcodebuild -project _public/cli/fSnippetCli.xcodeproj -scheme fSnippetCli -configuration Debug build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 커밋**

```bash
git add _public/cli/fSnippetCli/Data/APIModels.swift
git commit -m "Feat(API v2): ShutdownRequest/Response 모델 추가"
```

### Task 1-3: 라우팅 + 종료 로직 구현

**Files:**

* Modify: `_public/cli/fSnippetCli/Managers/APIRouter.swift`

- [ ] **Step 1: 라우트 등록**

POST `/api/v2/shutdown` 핸들러 추가. 기존 v2 라우팅 패턴 따름.

```swift
case ("POST", ["api", "v2", "shutdown"]):
    return handleShutdown(request: request)
```

- [ ] **Step 2: 핸들러 구현**

```swift
private func handleShutdown(request: HTTPRequest) -> HTTPResponse {
    let body = try? JSONDecoder().decode(ShutdownRequest.self, from: request.bodyData ?? Data())
    let reason = body?.reason ?? "unspecified"
    let delayMs = max(0, body?.delayMs ?? 0)

    logI("🛑 shutdown 요청 수신: reason=\(reason), delayMs=\(delayMs)")

    let response = ShutdownResponse(accepted: true, message: "cliApp 종료 예약됨 (delay=\(delayMs)ms)")
    let payload = try! JSONEncoder().encode(response)

    // 응답 전송 직후 종료하도록 비동기 예약
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs + 100)) {
        logI("🛑 cliApp 종료 실행 (reason=\(reason))")
        NSApplication.shared.terminate(nil)
    }

    return HTTPResponse(statusCode: 200, body: payload, contentType: "application/json")
}
```

- [ ] **Step 3: 수동 테스트**

```bash
# 터미널 A: cliApp 실행
open _public/cli/build/Debug/fSnippetCli.app

# 터미널 B: shutdown 호출
curl -X POST http://localhost:3015/api/v2/shutdown \
  -H "Content-Type: application/json" \
  -d '{"reason":"manual-test","delayMs":500}'
```

Expected: `{"accepted":true,"message":"..."}` 응답 직후 cliApp 종료 (메뉴바 아이콘 사라짐)

- [ ] **Step 4: 커밋**

```bash
git add _public/cli/fSnippetCli/Managers/APIRouter.swift
git commit -m "Feat(API v2): POST /shutdown 핸들러 구현"
```

## Phase 2 — cliApp: paidApp 감지 로직

### Task 2-1: PaidAppDetector 생성

**Files:**

* Create: `_public/cli/fSnippetCli/Utils/PaidAppDetector.swift`

- [ ] **Step 1: 감지기 구현**

```swift
import AppKit

/// paidApp (fSnippet) 설치 및 실행 상태 감지
enum PaidAppDetector {
    /// paidApp의 표준 Bundle ID (kr.finfra.fSnippet)
    /// Debug 접미사(`$(BUNDLE_ID_SUFFIX)`)가 붙을 수 있으나 prefix 매칭으로 처리
    static let bundleIdPrefix = "kr.finfra.fSnippet"

    /// paidApp이 현재 실행 중인지 여부
    static func isRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            guard let bid = app.bundleIdentifier else { return false }
            // cliApp 자신(kr.finfra.fSnippetCli) 제외: Cli로 끝나지 않는 fSnippet만
            return bid.hasPrefix(bundleIdPrefix) && !bid.hasSuffix("Cli")
        }
    }

    /// paidApp 설치 경로 (표준 /Applications 또는 /Applications/_nowage_app)
    static func installedURL() -> URL? {
        let candidates = [
            "/Applications/fSnippet.app",
            "/Applications/_nowage_app/fSnippet.app",
        ]
        return candidates.compactMap { path in
            FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
        }.first
    }

    /// paidApp 실행 (설치되어 있으면 open, 없으면 false)
    @discardableResult
    static func launch() -> Bool {
        guard let url = installedURL() else {
            logW("PaidAppDetector: fSnippet 설치 경로를 찾지 못함")
            return false
        }
        NSWorkspace.shared.open(url)
        return true
    }

    /// paidApp 설정창 열기 (REST 또는 Distributed Notification)
    static func openSettings() {
        // paidApp 측 이슈 완료 후 상세 프로토콜 확정
        // MVP: paidApp 실행(열기)만 보장
        launch()
    }
}
```

- [ ] **Step 2: 빌드 확인**

Run: `xcodebuild -project _public/cli/fSnippetCli.xcodeproj -scheme fSnippetCli -configuration Debug build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 커밋**

```bash
git add _public/cli/fSnippetCli/Utils/PaidAppDetector.swift
git commit -m "Feat(Utils): PaidAppDetector — fSnippet 설치·실행 상태 감지"
```

## Phase 3 — cliApp: 메뉴바 통합

### Task 3-1: MenuBarView에 paidApp 섹션 추가

**Files:**

* Modify: `_public/cli/fSnippetCli/MenuBarView.swift`

- [ ] **Step 1: paidApp 감지 결과에 따른 메뉴 항목 분기**

기존 메뉴 구조 보존, 아래 항목을 분기 추가 (`fSnippet` 섹션):

```swift
// fSnippet (paidApp) 메뉴 섹션
if PaidAppDetector.installedURL() != nil {
    Divider()
    Text("fSnippet").font(.caption).foregroundStyle(.secondary)

    Button("fSnippet 열기") {
        PaidAppDetector.launch()
    }
    Button("fSnippet 설정 열기") {
        PaidAppDetector.openSettings()
    }
    if PaidAppDetector.isRunning() {
        Text("● 실행 중").font(.caption2).foregroundStyle(.green)
    } else {
        Text("○ 중지됨").font(.caption2).foregroundStyle(.secondary)
    }
}
```

- [ ] **Step 2: 수동 테스트**

1. paidApp 미설치 상태 — fSnippet 섹션 미표시 확인
2. paidApp 설치 + 미실행 상태 — "○ 중지됨" 표시 확인
3. paidApp 실행 후 — "● 실행 중" 표시 확인
4. "fSnippet 열기" 클릭 — paidApp 실행 확인

- [ ] **Step 3: 커밋**

```bash
git add _public/cli/fSnippetCli/MenuBarView.swift
git commit -m "Feat(UI): 메뉴바에 fSnippet 섹션 추가 (paidApp 제어 통합)"
```

## Phase 4 — paidApp 측 이슈 등록

**주의**: 본 Phase는 `_public/cli/Issue.md`가 아닌 **paidApp 메인 레포** (`~/_git/__all/fSnippet/Issue.md`)에서 진행. 본 plan 파일은 cliApp 측이므로 링크만 유지.

### Task 4-1: paidApp Issue.md에 이슈 등록

- [ ] **Step 1: paidApp 메인 레포로 이동**

```bash
cd ~/_git/__all/fSnippet
```

- [ ] **Step 2: HWM 확인 후 `/issue-reg` 또는 수동 등록**

이슈 제목: `메뉴바 아이콘 cliApp 단일화 및 종료 시 cliApp REST kill 연동`

**목적**:

* cliApp이 메뉴바 소유권을 전담하도록 자사 메뉴바 아이콘 제거
* 종료 시 cliApp(`POST http://localhost:3015/api/v2/shutdown`)을 호출하여 동시 종료
* cliApp 실행 여부 감지 로직 추가 (미실행 시 kill REST 생략)

**상세**:

1. **메뉴바 아이콘 제거**: 기존 `NSStatusItem` 또는 `MenuBarExtra` 제거. 설정 접근은 paidApp 본체 윈도우로 유도.
2. **종료 훅**: `NSApplicationDelegate.applicationWillTerminate(_:)` 또는 SwiftUI `.onDisappear` 훅에 cliApp shutdown REST 호출 추가.

```swift
private func shutdownCliAppIfRunning() {
    guard isCliAppRunning() else { return }
    let url = URL(string: "http://localhost:3015/api/v2/shutdown")!
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = #"{"reason":"paidApp terminate","delayMs":0}"#.data(using: .utf8)
    // 동기 호출 (최대 500ms 타임아웃) — 종료 지연 최소화
    req.timeoutInterval = 0.5
    URLSession.shared.dataTask(with: req).resume()
}
```

3. **cliApp 감지 알고리즘**: paidApp 측에 `CliAppDetector` 신규 생성. bundleID prefix `kr.finfra.fSnippetCli` 검색.
4. **연동 시점**: paidApp 실행 시 cliApp 미실행이면 안내(또는 자동 실행 선택지).
5. **양방향 링크**: 본 이슈의 `* plan:` 필드에 `_public/cli/_doc_work/plan/menubar-cli-ownership_plan.md` 경로 기록.

**구현 명세**:

* 메뉴바 아이콘 제거 후 macOS Dock 표시 여부 확인 (LSUIElement 유지 시 GUI 진입점 사라짐 → **사용자 UX 검증 필수**)
* cliApp REST 실패 시 자체 종료는 정상 진행 (cliApp 부재는 오류 아님)

- [ ] **Step 3: paidApp Issue.md 커밋**

(paidApp 측 `/issue-reg` 완료 후 자동 처리됨)

- [ ] **Step 4: 이슈 번호 확보 후 본 plan frontmatter 갱신**

cliApp 측 본 plan 파일 `issue:` 필드는 **cliApp 이슈 번호**를 가리킴.
paidApp 이슈 번호는 본 plan 하단 "관련 이슈" 섹션에 기록.

## Phase 5 — pairApp 후속 이슈 (Phase 1~4 완료 후)

### Task 5-1: fWarrangeCli Issue.md에 이슈 등록

- [ ] **Step 1: pairApp 레포로 이동**

```bash
cd ~/_git/__all/fWarrange
```

- [ ] **Step 2: 이슈 등록**

이슈 제목: `메뉴바 아이콘 cliApp 단일화 패턴 적용 (fSnippet Issue{N} 미러)`

* 상세는 fSnippet paidApp 이슈 완료 후 확정된 패턴을 참조
* REST 포트·Bundle ID만 fWarrange용으로 치환
* 본 plan 링크 + paidApp 이슈 링크 포함

# 완료 조건

## cliApp (본 plan 직접 책임)

* [ ] **Phase 0 4경로 회귀**: 메뉴바 종료 / API /api/cli/quit / kill.sh / kill -9 + kill.sh — 전부 `launchctl list | grep fsnippet` 공백
* [ ] `POST /api/v2/shutdown` 호출 시 cliApp 정상 종료 (메뉴바 아이콘 사라짐, 프로세스 종료)
* [ ] `PaidAppDetector.isRunning()` / `installedURL()` / `launch()` 3개 메서드 수동 테스트 통과
* [ ] 메뉴바에서 paidApp 실행·설정 메뉴 항목 동작
* [ ] `openapi_v2.yaml` 명세와 구현 일치
* [ ] Release 빌드 + `brew services restart fsnippet-cli` 회귀 확인

## paidApp (Phase 4, 본 plan은 게이트만)

* [ ] paidApp Issue.md에 이슈 등록 완료
* [ ] 본 plan frontmatter `issue:` 필드에 cliApp 측 이슈 번호 기입
* [ ] paidApp 이슈 번호를 본 plan "관련 이슈" 섹션에 역참조 링크 추가

## pairApp (Phase 5, 본 plan은 게이트만)

* [ ] fWarrangeCli Issue.md에 후속 이슈 등록 완료

# 리스크 및 완화

| 리스크                                              | 영향도 | 완화책                                                              |
| :-------------------------------------------------- | :----- | :------------------------------------------------------------------ |
| paidApp 메뉴바 아이콘 제거 후 진입점 상실           | 높음   | Phase 4 구현 전 UX 검증. 필요 시 Dock 아이콘 복귀 또는 전용 윈도우 모드 |
| cliApp shutdown 호출 시 paidApp 의도와 불일치       | 중간   | `reason` 필드로 로그 추적. `delayMs`로 paidApp 종료 타이밍 조정      |
| REST 호출 실패로 cliApp이 살아남음                  | 중간   | paidApp 측 감지 로직이 실행 확인 후에만 호출. 실패해도 paidApp은 정상 종료 |
| paidApp Debug 빌드 Bundle ID 접미사(`.branch`)      | 낮음   | `PaidAppDetector`가 prefix 매칭 + `Cli` suffix 제외로 구분          |
| fWarrangeCli 포트·BundleID 미정                     | 낮음   | Phase 5 직전 pairApp 레포에서 확인 후 이슈 상세 작성                |

# 관련 자료

## 본 레포 (cliApp, `_public/`)

* [`api/openapi_v1.yaml`](../../_public/api/openapi_v1.yaml), [`api/openapi_v2.yaml`](../../_public/api/openapi_v2.yaml) — API SSOT
* [`cli/fSnippetCli/Managers/APIRouter.swift`](../../_public/cli/fSnippetCli/Managers/APIRouter.swift)
* [`cli/fSnippetCli/MenuBarView.swift`](../../_public/cli/fSnippetCli/MenuBarView.swift)
* [`_public/.claude/rules/api-rules.md`](../../_public/.claude/rules/api-rules.md) — API SSOT 동기화 규칙

## 상위/병렬 프로젝트

* paidApp: `~/_git/__all/fSnippet/Issue.md` (Phase 4 이슈 등록 대상)
* pairApp: `~/_git/__all/fWarrange/_public/` (Phase 5 이슈 등록 대상)

## 관련 이슈 (완료 후 채움)

* cliApp Issue{N}: TBD (본 plan frontmatter와 동일)
* paidApp Issue{M}: TBD (Phase 4 완료 후)
* pairApp Issue{K}: TBD (Phase 5 완료 후)

# Opus 4.7 실행 제약

공통 제약은 [`~/.claude/rules/opus-4-7-execution-rules.md`](../../../../../../.claude/rules/opus-4-7-execution-rules.md) 참조. 본 plan 특화 제약:

* Phase 4·5는 **별도 레포** 작업 — 현 세션에서 cross-repo 파일 직접 수정 금지. `cd`로 이동 후 해당 프로젝트의 `/issue-reg` 흐름 준수.
* paidApp 메뉴바 아이콘 제거 전 **사용자 UX 검증 필수** (진입점 상실 리스크). 미검증 시 구현 중단.
* cliApp shutdown API 구현 후 **수동 회귀 테스트 1회** 필수 (brew 재시작 포함)
* 각 Phase 완료 직후 커밋. 여러 Phase를 한 커밋에 묶지 말 것.
* REST kill 호출 시 timeout 0.5s 상한 — paidApp 종료 지연 방지
