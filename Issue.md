---
name: Issue
description: fSnippetCli 이슈 관리
date: 2026-04-07
---

# Issue Management

- Issue HWM: 51
- Save Point: 2026-04-19 (8b88964) Feat(Test)(Issue50): fsc-test.sh에 fwc 오케스트레이션 3단계 역이식

# 🤔 결정사항

# 🌱 이슈후보
1. 클립보드 히스토리 기능 중에서 고급 기능은 Paid 앱이 활성화 되어 있어야 실행 가능하게끔 해 줘 활성화 되어 있지 않다면 활성화 창[기존 코드 찾아서] 열게 해야함.
    - Paid 앱의 기능이 모듈로 구성되어 있는지 확인


# 🚧 진행중

## Issue51: brew services ↔ 메뉴바 앱 상태 동기화 재설계 — 4-quadrant 상태 매트릭스 기반 (pairApp fWarrangeCli#26 Issue39 Full Mirror) (등록: 2026-04-20)
* 목적: pairApp fWarrangeCli(#26) Issue39 에서 설계·검증 완료된 **4-quadrant 상태 매트릭스** 를 fSnippetCli 에 Full Mirror 이식. `brew services` (launchd) 와 메뉴바 GUI 앱의 4개 트리거(brew start / brew stop / app start / app stop) 에서 상대 상태를 양방향 동기화. `/opt/homebrew/var/fSnippetCli/` 경로 원천 차단 + Bundle ID 기반 단일 인스턴스 가드(launchd-bootstrap 우선권) 로 no-double-start / no-ghost-state 로 수렴.
* 참조 원본: pairApp fWarrangeCli#26 `3867459` — Feat(Issue39): brew services ↔ menubar 4-quadrant 상태 매트릭스 동기화
* 참조 리포트: fWarrangeCli `_public/cli/_doc_work/report/brew-service-menubar-sync_issue39_report.md`
* 배경:
    - Issue46(d4749f6) `keep_alive: successful_exit: false` 적용으로 launchd 재기동은 차단했으나, **메뉴바 종료 × `brew services start` 후속** / **`open` × `brew services` state 괴리** / **경로 다른 2개 인스턴스 공존** 문제는 미해결
    - fWarrangeCli Issue39 가 해당 3개 증상을 Phase 1~4 로 일괄 해결하며 4-quadrant 매트릭스 + launchd 우선권 규칙으로 수렴 — 본 이슈는 해당 구조 동일 이식
    - 현재 fSnippetCli 는 실측상 증상이 약함 (`brew services list` 에서 `started` 정상 표시) — 이는 주로 launchd-bootstrap 만 사용하는 사용 패턴 덕분. `open` 경로 병용 / Debug 빌드 경로 병존 시 동일 재현 가능성 존재 → 사전 방지 차원 Full Mirror
* 재설계 상태 매트릭스 (pairApp Issue39 동일):

    | Trigger        | 상대 상태      | 기대 동작                                              |
    | :------------- | :------------- | :----------------------------------------------------- |
    | **brew start** | 앱 실행 중      | brew state 만 `started` 로 이동 (앱 재기동 없음)       |
    | **brew start** | 앱 정지         | 앱 시작 + brew state `started`                         |
    | **brew stop**  | 앱 정지         | brew state `stopped`                                   |
    | **brew stop**  | 앱 실행 중      | brew state `stopped` (launchctl unload, 앱 종료 동반)  |
    | **app start**  | brew `started` | 앱만 시작, brew 호출 skip                              |
    | **app start**  | brew `stopped` | 앱 시작 + `brew services start` 호출 (state 동기화)    |
    | **app stop**   | brew `started` | `brew services stop` 호출 + `NSApplication.terminate`  |
    | **app stop**   | brew `stopped` | `terminate` 만 (brew 호출 skip)                        |

* 구현 명세 (pairApp `3867459` Full Mirror — 앱 구조 차이 반영 어댑테이션):
    - **앱 구조 차이 (pairApp → fSnippetCli 매핑)**:
        - pairApp: `fWarrangeCliApp.swift` 단일 파일 `AppEntry.main` + `@State AppState` + `state.initialize()`
        - fSnippetCli: `main.swift` (CLI/GUI 분기) + `fSnippetCliApp.swift` + `AppDelegate.applicationDidFinishLaunching`
        - 귀결: Guard 호출은 `main.swift` GUI 분기, `onAppStart` 호출은 `AppDelegate.applicationDidFinishLaunching` 말미 (기존 `setupPaidAppMonitoring` 이후)
    - **Phase 1** (`cli/_tool/fsc-config.sh`, `fsc-deploy-debug.sh`, `fsc-run-xcode.sh`): DerivedData 직접 실행, `/opt/homebrew/var/fSnippetCli/` 미생성. `DEPLOY_DIR/APP_PATH` → `LEGACY_VAR_DIR` + `resolve_app_path()` 치환. `_nowage_app` 심링크 DerivedData 지향
    - **Phase 2** (`cli/fSnippetCli/MenuBarView.swift` 종료 버튼): `NSApplication.shared.terminate(nil)` 앞에 `BrewServiceSync.onAppStop(timeout: 2.0)` 선행
    - **Phase 3** (`cli/fSnippetCli/fSnippetCliApp.swift` AppDelegate `applicationDidFinishLaunching` 말미): `BrewServiceSync.onAppStart()` 호출. skip 4종 동일 (UserDefaults `fsc.autoStartBrewService=false` / `XPC_SERVICE_NAME` 매칭 / launchctl 이미 로드됨 / brew 미존재)
    - **Phase 4** (신규 `cli/fSnippetCli/Services/SingleInstanceGuard.swift` + `main.swift` GUI 분기): `fSnippetCliApp.main()` 호출 직전 `SingleInstanceGuard.shouldTerminateAsDuplicate()` 체크. launchd-bootstrap 우선권 규칙 pairApp 동일
    - **신규 파일**: `cli/fSnippetCli/Services/BrewServiceSync.swift`, `cli/fSnippetCli/Services/SingleInstanceGuard.swift` (pairApp 소스 치환 이식)
    - **xcodeproj 갱신**: 신규 2개 파일을 PBXFileReference + PBXBuildFile + PBXGroup `Services` 에 수동 등록 (XcodeGen 사용 시 기존 DEVELOPMENT_TEAM/DEAD_CODE_STRIPPING 손실 우려 → 수동 편집 선택)
* 치환 규칙 (pairApp → fSnippetCli):
    - 포트: `3016` → `3015`
    - Formula: `fwarrange-cli` → `fsnippet-cli`
    - 서비스 label: `homebrew.mxcl.fwarrange-cli` → `homebrew.mxcl.fsnippet-cli`
    - Bundle ID: `kr.finfra.fWarrangeCli` → `kr.finfra.fSnippetCli`
    - 스크립트 prefix: `fwc-` → `fsc-`
    - 디렉토리: `fWarrangeCli` → `fSnippetCli`
    - UserDefaults key: `fwc.autoStartBrewService` → `fsc.autoStartBrewService`
* 실측 버그 (pairApp Issue39 에서 선행 해결, 본 이슈에서는 동일 패턴 방지):
    1. `getParentPID() == 1` 으로 launchd 기동 판정 시 macOS 모든 GUI 앱 PPID=1 특성상 상시 true → `onAppStart` 무한 skip. `XPC_SERVICE_NAME` 매칭만으로 판정
    2. 초기 `SingleInstanceGuard` 가 신규 프로세스 무조건 exit → open-기동분이 survive, launchd 프로세스 즉시 사라짐 → `brew services list` 가 `stopped` 로 표시. 승자 규칙 반전(launchd-bootstrap 우선권) 으로 해결
* 검증 계획:
    - 8개 매트릭스 셀 수동 재현 (`brew services start/stop` × 앱 실행/정지 × `open`/메뉴바 종료)
    - 각 셀마다 `brew services list | grep fsnippet-cli` + `pgrep -fl MacOS/fSnippetCli` + `curl :3015` 3종 확인
    - 리포트: `cli/_doc_work/report/brew-service-menubar-sync_issue51_report.md`

# 📕 중요

# 📙 일반

# 📗 선택

# ✅ 완료

## Issue50: fsc-test.sh에 fWarrangeCli(pairApp) 테스트 패턴 역이식 — apiTestDo.sh + cmdTestDo.sh 통합 구조 (등록: 2026-04-19, 해결: 2026-04-19, commit: 8b88964) ✅
* 목적: pairApp fWarrangeCli의 `fwc-test.sh`(245줄) 가 보유한 `apiTestDo.sh` + `cmdTestDo.sh` 분리 호출 + 구조화된 리포팅 패턴을 fSnippetCli의 `fsc-test.sh`(228줄) 에 역이식. 기존 ZTest 9단계 커버리지를 유지하면서 API / CMD 통합 테스트를 슈퍼셋 구조로 확장
* 배경:
    - fWarrangeCli(#26) Issue37 "Full Mirror 이식" 분석 중 `fwc-test.sh` 의 리포팅 패턴 (단계별 성공/실패 카운트, 실행 시간, 실패 상세 덤프) 이 `fsc-test.sh` 대비 우수함을 발견
    - `fsc-test.sh` 는 현재 ZTest 스니펫 확장 중심이고 REST API 및 CLI 명령 통합 테스트 오케스트레이션이 부재
    - pairApp 쪽은 `fwc-test.sh` → `apiTestDo.sh` + `cmdTestDo.sh` 로 책임 분리 후 상위 오케스트레이터가 `all` 호출
* 원인 분석:
    - `fsc-test.sh` 9단계는 ZTest 특화 (testBoard.txt / TextEdit 자동화 / flog.log) 뿐이라 API/CMD 통합 실행 경로가 없음
    - 실패 시 단계별 요약이 record_result 로 집계되지만 API/CMD 범위가 빠져 있어 파악에 별도 실행 필요
* 해결 방법 (실적용):
    - Phase 1 (갭 분석): `cli/_tool/{apiTestDo.sh,cmdTestDo.sh}` 는 이미 wrapper 구조(298B/694B)로 존재하고 실체는 `{apiTest,cmdTest}/Do.sh` 에 있음을 확인. fWarrange 는 단일 파일(6941B/6903B) 구조. wrapper 구조는 그대로 유지
    - Phase 2 (핵심): `fsc-test.sh` 를 9단계 → 12단계로 확장
        - Step 9 (신규): `apiTestDo.sh all` 호출 — v1/17.cli-quit 자동 skip 위해 stdin 에 `N` 주입
        - Step 10 (신규): `cmdTestDo.sh all` 호출 — 실패 라인(`실패=[1-9]`) grep 집계
        - Step 11 (신규): `flog.log` ERROR/CRITICAL 자동 카운트 (기존 Step 8 `🚦 트리거 확장` 검사와 별개)
        - Step 12: 기존 Step 9 (launchctl unsetenv) 재번호
    - Phase 3 (리포팅 통일): 기존 `record_result` + 최종 박스가 fwc 와 동일 구조라 추가 변경 없음
    - Phase 4 (Do wrapper 구조): fSnippet 기존 wrapper 구조 유지 결정. `--run/--log/--report` 옵션은 "구조만 맞추는 선" 방침에 따라 별도 PM 프로세스 몫으로 유지
* 수정 파일:
    - `cli/_tool/fsc-test.sh` — 헤더 주석 12단계 확장 + Step 9/10/11 신규 + Step 12 재번호 (71+/13-)
* 구현 명세:
    - API 집계: `grep -c '^==='` 로 실행 수, `grep -cE '"status": *"error"|❌'` 로 실패 건 카운트
    - CMD 집계: `grep -c '^==='` 로 실행 수, `grep -cE '실패=[1-9]'` 로 실패 라인 카운트
    - 로그 검사: `grep -cE "ERROR|CRITICAL" "$LOG_FILE"` + 실패 시 최근 5건 tail 출력
    - 문법 검증: `bash -n cli/_tool/fsc-test.sh` 통과
* 사용자 확정 범위: Phase 순차 진행, config 기본값 검증은 구조만 맞추는 선 (별도 PM 프로세스), plan/task 파일 생성 생략 (마감 차원)
* 관련 이슈: fWarrangeCli(#26) Issue37 plan `cli/_doc_work/plan/deploy-run-sync-from-pairapp_plan.md` Phase 5 "리스크 및 완화" 표 마지막 항목
* pairApp 이식 방향: 이번에는 fWarrange → fSnippet **역이식**. 향후 fWarrange 쪽 개선 사항 발생 시 동일 경로로 다시 역이식 가능

## Issue49: `/run` 계열 전 경로에 brew service 존재 기반 분기 로직 도입 (등록: 2026-04-19, 해결: 2026-04-19, commit: 2d4ec67) ✅
* 목적: `/deploy brew local` 로 설치된 LaunchAgent 가 실행 중인 상태에서 `/run` 계열(`build-deploy`, `deploy-run`, `tcc`, `run-only`)을 호출할 때 발생하는 launchd respawn 경합 / 포트 단일 인스턴스 충돌을 제거. brew service 실행 여부에 따라 Debug 오버라이드 경로를 명시적으로 분기.
* 배경:
    - Issue46 완료 후 Formula `keep_alive { successful_exit: false }` 설정 — 정상 종료는 유지, crash는 launchd가 즉시 복구하는 UX 정착
    - 사용자 실측: `/run run-only` 호출 시 `pkill` 은 launchd 입장에서 crash 로 분류 → Cellar/Release 바이너리가 즉시 respawn → `open` 으로 요청한 Debug 바이너리와 포트 3015 단일 인스턴스 가드 경합 발생
    - 동일 원인이 `build-deploy` / `deploy-run` / `tcc` 경로에도 존재함을 후속 검토로 확인 — 단, 이들은 `cp -R` 로 덮어쓰기까지 진행하므로 Release 바이너리가 먼저 포트를 잡으면 Debug 기동 자체가 실패
* 원인 분석:
    - **원인 1 — `pkill` 의 launchd 해석**: SIGTERM/SIGKILL 로 프로세스를 죽여도 `successful_exit: false` 규칙상 launchd 는 비정상 종료로 간주. `brew services stop` 로 명시적으로 unload 해야만 재기동하지 않음
    - **원인 2 — plist 존재 기반 판정의 한계**: `~/Library/LaunchAgents/homebrew.mxcl.fsnippet-cli.plist` 는 `brew services stop` 후에도 남음. plist 존재를 기준으로 "service 있음 → restart" 분기를 하면, Debug 세션 중 `/run run-only` 가 의도치 않게 Release 바이너리를 복원시키는 오작동 발생
    - **원인 3 — Launch Services `-600`**: `pkill` 직후 같은 경로로 `open` 을 호출하면 macOS Launch Services 내부 정리 전이어서 `-600 (procNotFound)` 반환 — 앱이 기동되지 않음
* 해결 방법:
    - `fsc-config.sh` 에 공통 헬퍼 `brew_service_running()` 추가 — `launchctl list` 에 `homebrew.mxcl.fsnippet-cli` 라벨이 로드되어 있는지로 판정 (plist 존재 기반이 아님)
    - `fsc-run-xcode.sh`:
        - `brew_service_stop_for_debug()` 신규 — 실행 중이면 `brew services stop` 선행
        - `build-deploy` / `deploy-run` / `tcc` 분기 상단에서 호출 → `pkill` 이전에 launchd 로부터 서비스 분리
        - `run_app_only` 재작성 — 실행 중이면 `brew services restart` (launchd 단일 경로), 정지/미등록이면 `kill + sleep 0.5 + open` (Debug 오버라이드 존중). `-600` 회피용 3회 retry 포함
* 수정 파일:
    - `cli/_tool/fsc-config.sh` — `BREW_SERVICE_LABEL` 추가, `brew_service_running()` 헬퍼
    - `cli/_tool/fsc-run-xcode.sh` — `brew_service_stop_for_debug()`, `run_app_only` 분기, 3개 CMD 분기 상단 호출
* 테스트 결과:
    - `brew services start` 상태에서 `/run build-deploy` → stop 메시지 출력 후 Debug 빌드/기동 정상
    - `brew services stop` 상태(정지됨)에서 `/run run-only` → 직접 `open` 분기 진입, REST API (port 3015) 응답 확인
    - `brew services start` 상태에서 `/run run-only` → `brew services restart` 분기 진입, uptime 리셋 확인
* 관련 이슈: Issue46 (keep_alive `successful_exit: false` 도입)
* pairApp 이식: fWarrangeCli(#26) 이슈후보 2번 — 동일 구조 Full Mirror 대기 (포트 3016, Formula `fwarrange-cli`)

## Issue46: `brew services` 기동 시 메뉴바 "종료"로 앱 제거 불가 — launchd keep_alive 무조건 재시작 (등록: 2026-04-19, 해결: 2026-04-19, commit: d4749f6) ✅
* 목적: `brew services start fsnippet-cli` 로 기동된 상태에서 메뉴바 "종료"를 눌러도 launchd가 프로세스를 즉시 재기동하여 앱을 종료할 수 없는 문제를 해결. 메뉴바 "종료" = 서비스 완전 중지, 앱 재실행 = 서비스 재개의 UX를 확립
* 배경:
    - Issue45 완료 시 `brew services` 경로로 복원하면서 `cli/Formula/fsnippet-cli.rb`에 `keep_alive true` 설정 (서비스 안정성 목적)
    - Issue45 검증 항목 [`brew services stop fsnippet-cli` → 정상 중지]은 통과했으나, **메뉴바 GUI "종료" 조작 경로는 검증 항목에 없었음** → 본 이슈에서 후행 발견
    - 사용자 실측: 메뉴바 "종료" 클릭 → 아이콘 사라짐 → 5~10초 내 자동 재등장 (launchd relaunch)
    - 사용자 실측 추가(2026-04-19): `brew services stop fsnippet-cli` 실행 전까지는 메뉴바 "종료"를 아무리 반복해도 launchd가 계속 재기동함. 즉 **launchd 서비스를 명시적으로 stop 시키기 전에는 앱 종료 자체가 불가능** → launchd `keep_alive true` 가 단일 원인임을 확증
* 원인 분석:
    - **원인 1 — launchd `keep_alive true` 의미**: `true`는 "종료 사유 무관 무조건 재시작". `NSApp.terminate(nil)` 이 발생시키는 정상 종료(exit code 0)도 재시작 대상이 됨
    - **원인 2 — 메뉴바 종료 로직 단순**: `cli/fSnippetCli/MenuBarView.swift:70`의 `NSApplication.shared.terminate(nil)` 만 호출. launchd 서비스 레벨 제어 없음 → 앱 프로세스 ≠ 서비스 분리 인지 안 됨
    - **구조적 배경**: Homebrew LaunchAgent는 **서비스 수명**을 관리하고, macOS 앱은 **프로세스 수명**을 관리함. 둘이 서로를 인지하지 못하면 메뉴바 종료가 서비스에 전달되지 않음
* 설계 근거: `~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md` §7-5-A 및 launchd.plist `KeepAlive` 딕셔너리 스펙
    - Homebrew `service` DSL의 `keep_alive` 는 `true`/`false`/해시 세 형태 지원
    - `keep_alive successful_exit: false` → exit 0 정상 종료 시 재시작 안 함, 비정상 종료(crash)만 재시작
    - `keep_alive crashed: true` → 크래시 발생 시에만 재시작 (명시적)
* 해결 전략:
    - **전략 A (Formula 설정 변경, 최소 침습)**: `keep_alive true` → `keep_alive successful_exit: false` 로 변경. 메뉴바 정상 종료(exit 0) 시 재시작 안 함, 크래시 시에만 재시작되어 데몬 안정성 유지
    - **전략 B (메뉴바 로직에 brew services stop 호출)**: brew 의존성 + 비 brew 설치 환경 분기 필요 + PATH 이슈 → 복잡도 증가
    - **채택**: 전략 A + MenuBarManager `launchctl bootout` 보강 (d4749f6)
* 구현 명세 (d4749f6 반영):
    - `cli/Formula/fsnippet-cli.rb` `service do` 블록: `keep_alive successful_exit: false` 적용
    - `cli/_tool/fsc-deploy-brew.sh` Step 5 로컬 tap Formula heredoc 내 동일 수정 (Formula SSOT 동기화)
    - `cli/_tool/fsc-deploy-brew.sh` Step 7 `open "$STABLE_APP"` 호출 제거 — 심링크만 생성. LaunchAgent 단일 경로(`opt_prefix`) 로 TCC 승인 경로 일원화
    - `cli/_tool/fsc-deploy-brew.sh` Step 9 REST 헬스 체크는 `FSC_AUTOSTART=1` 일 때만 수행
    - `cli/fSnippetCli/Managers/MenuBarManager.swift` 종료 시 `launchctl bootout` 호출 추가 → launchd 재등록 허용
    - Formula: xcode 재빌드 제거 → 사전 빌드 app tarball 복사 (brew sandbox 키체인 제약 회피)
* 설계 원칙:
    - **크래시 복구 vs 사용자 종료 구분**: launchd `keep_alive` 를 조건부로 구성하여 서비스 안정성(크래시 자동 복구)과 사용자 제어권(메뉴바 종료)을 동시 확보
    - **배타 원칙 유지**: Issue45의 brew services ↔ SMAppService 배타 원칙은 그대로 유지
    - **TCC 단일 경로**: `open` 호출 경로 제거로 LaunchAgent 단일 경로만 TCC 승인 요구 → 1회 승인
* 검증:
    - [x] `cli/Formula/fsnippet-cli.rb` 에서 `keep_alive successful_exit: false` 로 수정됨
    - [x] `fsc-deploy-brew.sh` Step 5 로컬 Formula heredoc 에 동일 수정 반영
    - [x] `fsc-deploy-brew.sh` Step 7 에서 `open` 호출 제거 — 심링크만 생성
    - [x] `fsc-deploy-brew.sh` Step 9 가 `FSC_AUTOSTART=1` 일 때만 수행되도록 조건부 분기
    - [x] `MenuBarManager` 종료 시 `launchctl bootout` 호출 추가 (d4749f6)
    - [ ] `FSC_AUTOSTART=1 /deploy brew local` 실행 시 **TCC 승인 요청이 1회만 발생** — 사용자 실측 검증
    - [ ] 메뉴바 "종료" 클릭 → 5~10초 대기 후에도 아이콘 재등장 안 함 — 사용자 실측 검증
    - [ ] 의도적 crash 유발(kill -9) → launchd가 자동 재시작 — 사용자 실측 검증
    - [ ] 로그아웃 → 재로그인 시 LaunchAgent 자동 기동 — 사용자 실측 검증
* 관련 파일:
    - `cli/Formula/fsnippet-cli.rb` (service 블록 `keep_alive` 조건 변경)
    - `cli/_tool/fsc-deploy-brew.sh` (Step 5/7/9 재구성)
    - `cli/_tool/fsc-deploy-debug.sh` (TCC 꼬임·심링크 경로 일원화)
    - `cli/fSnippetCli/Managers/MenuBarManager.swift` (launchctl bootout 추가)
* 참조:
    - Issue45 (`brew services` 경로 재도입) — 본 이슈의 선행 이슈
    - Issue47 (SMAppService 배타 원칙 완전 이행) — 후속 이슈
    - launchd.plist KeepAlive 딕셔너리 스펙: https://www.launchd.info/
    - Homebrew Formula service DSL: https://docs.brew.sh/Formula-Cookbook#using-formulaservice

## Issue48: `/run tcc` — brew 서비스 경로 전용 TCC 재설정 서브커맨드 분리 (등록: 2026-04-19, 해결: 2026-04-19, commit: d4749f6) ✅
* 목적: `/deploy brew local` 이후 TCC 이슈 발생 시 Xcode Debug 빌드 없이 TCC reset + brew services restart 만 수행하는 경량 경로 제공
* 상세:
    - 현재 `/run tcc` 동작: `kill + tccutil reset Accessibility kr.finfra.fSnippetCli + fsc-run-xcode.sh build-deploy` → Xcode Debug 빌드까지 수행
    - brew 서비스 경로(Release 앱)만 사용하는 경우 Xcode 빌드는 불필요한 오버헤드
    - `tcc-brew` 서브커맨드 신설: `tccutil reset Accessibility kr.finfra.fSnippetCli + brew services restart fsnippet-cli` 로 brew 전용 TCC 재설정
    - `deploy.md`의 TCC 안내도 `/run tcc-brew` 로 경로 분기 추가
* 구현 명세:
    - `fsc-run-xcode.sh` 에 `tcc-brew` 케이스 추가 또는 별도 `fsc-tcc-brew.sh` 스크립트 신설
    - `/run` 커맨드 라우팅 테이블에 `tcc-brew` 항목 추가
    - 기존 `tcc` 옵션 유지 (Xcode Debug 경로 사용자용)
* 종결 사유 (2026-04-19):
    - Save point 커밋 `d4749f6` 에서 `fsc-deploy-brew/debug 스크립트 TCC 꼬임·심링크 경로 일원화` 완료
    - LaunchAgent 단일 경로(opt_prefix) + 심링크 경로 통합으로 TCC 승인 경로가 1회로 수렴 (Issue46 해결 경로에 포함)
    - brew 서비스 경로 전용 분리 서브커맨드의 필요성 자체가 해소됨 → obsolete 처리

## Issue47: 앱 내부 SMAppService 기반 Login Item 등록 차단 — brew services 배타 원칙 준수 (등록: 2026-04-19, 해결: 2026-04-19, commit: 12023c1) ✅
* 목적: 앱 기동 및 설정 변경 시 `AutoStartManager`(SMAppService.mainApp.register()) 가 Login Item 을 자동 추가하는 동작을 제거하여 Issue45 의 `brew services` ↔ SMAppService 배타 원칙을 앱 내부까지 완전 준수
* 배경:
    - Issue44(commit 1d01e68) — `fsc-deploy-brew.sh` 의 osascript 기반 Login Item 등록 인프라 구축
    - Issue45(commit 2418363) — 오픈소스 배포 표준 `brew services` 경로 재도입 + Login Item osascript 인프라 전면 제거
    - Issue45 구현 명세에 **"`brew services` 와 SMAppService 는 배타적 — 동시 등록 금지"** 명문화
    - 그러나 Issue45 커밋 범위는 **배포 스크립트 레벨**에만 적용됨 → 앱 내부 `AutoStartManager` (SMAppService 기반) 는 잔존
    - 사용자 실측(2026-04-19): brew services 기반으로 설치 후에도 시스템 설정 > 로그인 항목에 fSnippetCli 가 자동 추가되는 현상 관찰 → 이슈후보 2번으로 등록됨
* 원인 분석:
    - **원인 1 — `AutoStartManager.setAutoStart(true)` 호출**: `cli/fSnippetCli/Managers/AutoStartManager.swift` 가 `SMAppService.mainApp.register()` 호출 → macOS 가 "Login Item Added" 시스템 알림 표시 + 로그인 항목 목록에 추가
    - **원인 2 — SettingsObservableObject 진입점 3곳**: `applyInitialSettings()`, 프로퍼티 `didSet`, `init()` 말미 모두 `AutoStartManager.shared.setAutoStart(autoStart)` 호출 → autoStart 가 `true` 이면 기동 시마다 재등록
    - **원인 3 — legacy 기본값 누적**: `start_at_login` prefs 에 `true` 가 한 번이라도 기록된 사용자는 Issue45 배포 후에도 앱 내부에서 자동 재등록됨
    - **구조적 배경**: Issue44 이전에는 앱 내부 `AutoStartManager` 와 배포 스크립트 Login Item 이 동일 목적(로그인 시 자동 기동)을 이중 관리함. Issue45 에서 배포 스크립트 경로만 제거 → 앱 내부 경로는 배타 원칙 위배 상태로 방치
* 설계 근거: `~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md` §7-5-C "배타 원칙"
    - LaunchAgent(brew services) 와 SMAppService 는 **동일 바이너리 이중 등록** 형태가 되어 launchd 가 예측 불가능한 타이밍으로 프로세스 2회 기동 시도
    - 오픈소스 배포 표준은 `brew services` 이므로 SMAppService 경로는 제거가 원칙
* 해결 전략:
    - **전략 A (no-op + 유지)**: `AutoStartManager.setAutoStart()` 내부를 no-op 로 변경 + `SettingsObservableObject` 호출부 제거. API v2 `launchAtLogin` / `start_at_login` prefs 는 backward compat 유지 (읽기/쓰기는 prefs 값만 단순 저장, 실 등록은 안 함)
    - **전략 B (전면 제거)**: `AutoStartManager.swift` 파일 삭제 + pbxproj 정리 + 호출부 제거
    - **채택**: 전략 A (최소 침습 + backward compat + 이력 보존). 전략 B 는 pbxproj 편집 리스크 있음
* 구현 명세:
    - `cli/fSnippetCli/Managers/AutoStartManager.swift`:
        - `setAutoStart(_:)` 내부 SMAppService 호출 전부 제거 → no-op + 경고 로그 "Issue47: brew services 배타 원칙, SMAppService 경로 obsolete"
        - `isAutoStartEnabled()` 는 `false` 고정 반환 (prefs 와 분리)
        - 파일 상단에 obsolete 주석 추가
    - `cli/fSnippetCli/Data/SettingsObservableObject.swift`:
        - L37 `didSet` 내 `AutoStartManager.shared.setAutoStart(autoStart)` 호출 제거
        - L316 `applyInitialSettings()` 내 호출 제거
        - L873 `init()` 말미 호출 제거
        - `autoStart` 프로퍼티 자체는 유지 (API v2 backward compat + legacy prefs 마이그레이션)
    - `start_at_login` prefs 키 및 API v2 `launchAtLogin` 필드는 유지 (backward compat) 하되 설정값 변경해도 실제 Login Item 등록/해제 안 됨
* 설계 원칙:
    - **배타 원칙 완전 이행**: 앱 내부까지 `brew services` 일원화
    - **최소 침습**: API/SettingsModel 시그니처 변경 없음 → v2 클라이언트 호환
    - **이력 보존**: AutoStartManager 파일 유지 + obsolete 사유 주석
* 검증:
    - [x] Release 빌드 성공
    - [x] Debug 빌드 + `/Applications/_nowage_app/fSnippetCli.app` 배포 + 실행 성공 (REST API 정상, uptime 6s)
    - [x] API `GET /api/v2/settings/behavior` 응답에 `launchAtLogin` 필드 존재 (backward compat)
    - [x] `AutoStartManager.shared.setAutoStart` 호출부 전역 제거 확인 (grep 검색 결과 0건)
    - [ ] `/deploy brew local` 재설치 후 `brew services start fsnippet-cli` 기동 (사용자 필요 시 별도 진행)
    - [ ] 시스템 설정 > 일반 > 로그인 항목에 **fSnippetCli 가 추가되지 않음** 확인 (기존 항목은 사용자가 수동 제거) — 사용자 실측 검증
    - [ ] macOS "Login Item Added" 시스템 알림 미노출 확인 — 사용자 실측 검증
* 관련 파일:
    - `cli/fSnippetCli/Managers/AutoStartManager.swift` (no-op + 이력 주석)
    - `cli/fSnippetCli/Data/SettingsObservableObject.swift` (호출부 3곳 제거)
    - `cli/fSnippetCli/Managers/APIRouter.swift` (수정 없음, 참고)
    - `cli/fSnippetCli/Data/APIModels.swift` (수정 없음, 참고)
* 참조:
    - Issue44 (Login Item osascript 경로 — obsolete)
    - Issue45 (brew services 재도입 + 배타 원칙 선언)
    - Issue46 (brew services launchd keep_alive 조정)
    - homebrew_tap_deploy.md §7-5-C 배타 원칙

## Issue45: `brew services` 경로 재도입 + Formula 명명 `fsnippet-cli` 로 복원 — 오픈소스 배포 표준 (등록: 2026-04-19, 해결: 2026-04-19, commit: 2418363, 5294c6b) ✅
* 목적: 오픈소스 배포 관점에서 사용자가 기대하는 표준 인터페이스 `brew services start/stop/info` 로 fSnippetCli 자동 기동을 관리 가능하도록 Formula `service do` 블록 재도입 + Formula 명명을 `fsnippet-cli` (하이픈 포함)로 복원 (Issue4의 "Homebrew 소문자 정규화" 번복)
* 🔄 Formula 명명 복원 (2026-04-19 사용자 결정):
    - 과거 Issue4(2026-04-08)에서 `fsnippet-cli.rb` → `fsnippetcli.rb` 로 "소문자 정규화" 명분으로 변경
    - 실제 Homebrew 공식 관행은 하이픈 포함 허용 (`node-cli`, `aws-cli` 등 다수 사례) → 정규화 명분은 부정확
    - 오픈소스 배포 시 가독성 + 단어 경계 명확성 우선 → **`fsnippet-cli`** 로 복원
    - Formula 파일: `cli/Formula/fsnippet-cli.rb` (클래스 `FsnippetCli`)
    - 패키지명: `finfra/tap/fsnippet-cli`
    - 로그 경로: `/opt/homebrew/var/log/fsnippet-cli.log` / `.err.log`
    - memory `project_brew-deployment.md` 에 표준으로 명문화 (사용자 직접 작성)
* 배경:
    - 과거 Issue4(2026-04-08, commit 92c01c2)에서 `brew services` 경로 구축 → 정상 동작 검증 완료
    - Issue18(2026-04-08, commit 7879ac2)에서 `service do` 블록 제거 + SMAppService 전담 결정
    - Issue44(2026-04-19, commit 1d01e68)에서 Login Item(osascript) 경로 구축 — obsolete
    - 🔄 설계 번복: 오픈소스 배포 시 사용자 기대치는 `brew services` 가 표준. Login Item은 osascript 접근 권한 의존 + 외부 에이전트 도구로 비가시적 → 배포 친화적이지 않음
    - Issue44의 Login Item 인프라 전면 폐기 후 `brew services` 일원화
* 설계 근거: `~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md` §7-5-A "`brew services` 경로 (LaunchAgent)"
* 구현 명세:
    - `cli/Formula/fsnippet-cli.rb` **복원** (원격 배포 publish용, GitHub URL + SHA256 placeholder) + `service do` 블록 포함
        ```ruby
        service do
          run [opt_prefix/"fSnippetCli.app/Contents/MacOS/fSnippetCli"]
          keep_alive true
          log_path var/"log/fsnippet-cli.log"
          error_log_path var/"log/fsnippet-cli.err.log"
          process_type :interactive   # GUI 세션 접근 허용 (LSUIElement 메뉴바 렌더링)
        end
        ```
    - `fsc-deploy-brew.sh` Step 5 로컬 tap Formula heredoc도 동일 `service do` 블록 포함
    - `fsc-deploy-brew.sh` 재구성:
        - Step 8: Login Item 등록 → `brew services start finfra/tap/fsnippet-cli` (FSC_AUTOSTART=1 옵트인 유지)
        - `cmd_uninstall`: `fsc-loginitem.sh unregister` → `brew services stop` 선행 호출
        - `cmd_status`: Login Item 섹션 → `brew services info` 섹션
    - **Login Item 인프라 완전 제거**:
        - `cli/_tool/fsc-loginitem.sh` 삭제 (배타 원칙 — 두 경로 병행 금지)
        - `fsc-deploy-brew.sh` 내 Login Item 관련 코드 제거
        - `/Applications/_nowage_app` 심링크는 유지 — `brew services`와 무관한 개발자 편의
    - `.claude/commands/deploy.md` 갱신: Login Item 안내 → `brew services start` 안내
* 설계 원칙:
    - **`brew services`와 SMAppService는 배타적** — 동시 등록 금지 (LaunchAgent + 앱 내부 자동 시작 중복)
    - Homebrew 배포본 표준: `brew services`
    - App Store/서명 배포본: SMAppService
    - Login Item 경로 폐기: 오픈소스 CLI 배포에서 osascript 의존은 배포 친화적이지 않음 + 배타 원칙에 따라 `brew services`와 병행 불가
* 검증:
    - [ ] `cli/Formula/fsnippet-cli.rb` 복원 + `service do` 블록 존재
    - [ ] `fsc-deploy-brew.sh` Step 5 로컬 Formula에 `service do` 블록 포함
    - [ ] `/deploy brew local` 실행 시 Step 1~9 전부 PASS
    - [ ] `brew services list` 에 `fsnippet-cli` 표시됨
    - [ ] `brew services start finfra/tap/fsnippet-cli` → 정상 기동
    - [ ] 메뉴바에 bolt 아이콘 표시 (LSUIElement + LaunchAgent 호환성 확인)
    - [ ] CGEventTap 정상 동작 (Accessibility TCC 승인 후)
    - [ ] REST 3015 응답
    - [ ] `brew services info fsnippet-cli` → started 상태 조회
    - [ ] `brew services stop fsnippet-cli` → 정상 중지
    - [ ] `/deploy brew uninstall` → `brew services stop` 선행 호출 확인
    - [ ] 로그아웃 → 재로그인 시 자동 기동 (LaunchAgent KeepAlive 효과)
    - [ ] `cli/_tool/fsc-loginitem.sh` 삭제 확인
* 관련 파일:
    - `cli/Formula/fsnippet-cli.rb` (복원, `service do` 블록 포함)
    - `cli/_tool/fsc-deploy-brew.sh` (Step 5/8 재구성, cmd_uninstall/cmd_status 변경)
    - `cli/_tool/fsc-loginitem.sh` (삭제)
    - `.claude/commands/deploy.md` (brew services 안내로 재작성)
    - `~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md` §7-5 결정 트리 수정 (fSnippetCli를 §7-5-A 사례로 이동)

## Issue43: /deploy brew 서브커맨드 확장 (local/publish/status/uninstall + TCC 안내) (등록: 2026-04-19, 해결: 2026-04-19, commit: 1d01e68, 2418363) ✅
* 목적: `/deploy brew` 단독 호출 금지, 4개 서브커맨드로 분기하고 brew 설치 후 TCC 권한 꼬임 가능성을 `/run tcc` 안내로 유도
* 선수: **Issue45 (`brew services` 경로 재도입)** — `brew local` 완료 후 사용자 로그인 시 자동 기동 흐름이 완성되려면 Issue45 구현이 필요 (과거 Issue44 Login Item 경로는 설계 번복으로 obsolete)
* 배경:
    - 현재 `/deploy brew`는 로컬 tap 재설치만 수행 — 원격 tap 반영/상태 조회/정리 기능이 섞여 있지 않아 확장성 부족
    - brew 재설치 후 새 서명 바이너리로 TCC Accessibility 권한이 꼬여 키 감지 실패 가능 (이번 세션 실측)
    - `fsc-run-xcode.sh tcc` 서브커맨드로 `tccutil reset Accessibility` 자동화 완료 (사용자 별도 수정)
* 설계 근거: `~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md`
    - Tap 레포 규칙: `homebrew-<name>` 형식 (= `finfra/homebrew-tap`)
    - 배포 흐름: 태그 → Release → SHA256 → Formula `url`/`sha256` 갱신 → tap 레포 푸시
    - 자동화: `dawidd6/action-homebrew-bump-formula` GitHub Action
* 서브커맨드 스펙:

    | 서브커맨드               | 동작                                                                                  | 상태               |
    | :----------------------- | :------------------------------------------------------------------------------------ | :----------------- |
    | `/deploy brew local`     | Release 빌드 + 로컬 tap(`finfra/tap`) 재설치 + 앱 실행 (기존 fsc-deploy-brew.sh 로직) | ✅ 구현 예정       |
    | `/deploy brew publish`   | 원격 `finfra/homebrew-tap` 저장소 생성/푸시, 태그 기반 Formula 업데이트               | 🚧 TODO (Phase B) |
    | `/deploy brew status`    | brew list, brew --prefix, 프로세스·REST 상태 조회                                     | ✅ 구현 예정       |
    | `/deploy brew uninstall` | brew uninstall + 로컬 tap Formula 정리                                                | ✅ 구현 예정       |
* Phase A (local/status/uninstall + Usage 강제): 🚧 진행중
    - `fsc-deploy-brew.sh`를 서브커맨드 분기 구조로 재작성
    - `deploy.md`에 `brew <sub>` 서브커맨드 필수 명시, 인자 없으면 Usage
    - `local`/`publish` 완료 후 TCC 안내 출력 — "`/run tcc`로 권한 재설정 가능" 명시
* Phase B (publish 구현): 미착수
    - GitHub 태그 + Release 자동 생성 (`gh release create`)
    - `cli/Formula/fsnippet-cli.rb` 원격용 Formula 복원 (GitHub URL + SHA256)
    - 원격 `finfra/homebrew-tap` 레포 푸시 스크립트
    - 사전 조건: 원격 `finfra/homebrew-tap` 저장소 생성 필요
* 구현 명세:
    - Phase A만 먼저 완료·검증·커밋 (단계 분리)
    - Phase B는 별도 커밋으로 진행
    - TCC 안내는 로그/출력에 한국어로 표시, `/run tcc` 커맨드를 해결책으로 제시
* 검증:
    - [ ] `/deploy brew` 단독 → Usage 출력 + exit 1
    - [ ] `/deploy brew local` → 기존 8단계 + TCC 안내
    - [ ] `/deploy brew status` → brew/tap/프로세스/REST 한눈에 조회
    - [ ] `/deploy brew uninstall` → brew uninstall + 로컬 tap Formula 제거
    - [ ] `/deploy brew publish` → "🚧 TODO" 메시지 + 향후 구현 가이드 링크
* 관련 파일:
    - `cli/_tool/fsc-deploy-brew.sh` (서브커맨드 분기 재작성)
    - `.claude/commands/deploy.md` (brew 서브커맨드 필수 명시)
    - 참고: `~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md`

## Issue42: Accessibility 권한 UX 개선 (pairApp 패턴 이식 — 시스템 프롬프트 중복 제거 + 권한 부여 후 자동 재초기화) (등록: 2026-04-19, 해결: 2026-04-19, commit: 353e8fe) ✅
* 목적: 접근성 권한 다이얼로그가 중첩되어 뜨는 문제와 권한 부여 후 `/run`을 두 번 실행해야 CGEventTap이 정상 작동하는 문제를 pairApp(fWarrangeCli) 패턴 이식으로 해결
* 배경: 이미지 근거 2건 수집됨 (Issue.md 이슈후보 2번, 2026-04-19)
    - 시스템 "Accessibility Access" 다이얼로그 + 앱 커스텀 "접근성 권한 필요" NSAlert가 **동시에** 노출됨 (pairApp은 1회만 표시)
    - 권한 승인 후에도 CGEventTap 핸들이 이미 실패 상태라 앱 재기동 필요
* 진단 (비교 분석):
    - pairApp `AppState.initialize()` — `AXIsProcessTrusted()` 사용 (prompt 옵션 없음) + 커스텀 NSAlert만 노출
    - fSnippetCli `AppDelegate.checkAccessibilityPermission` — `AXIsProcessTrustedWithOptions(prompt: true)` 사용으로 시스템 프롬프트 트리거 + 커스텀 NSAlert 중첩
    - 두 앱 모두 자동 재시작 로직은 없으나, pairApp은 CGEventTap 의존이 없어 권한 지연에 관대하고, fSnippetCli는 CGEventTap 재초기화 없이는 복구 불가
* Phase A (시스템 프롬프트 중복 제거): ✅
    - `cli/fSnippetCli/fSnippetCliApp.swift` `checkAccessibilityPermission` 수정
    - `AXIsProcessTrustedWithOptions(prompt: true)` → `AXIsProcessTrusted()` 교체
    - 커스텀 `showAccessibilityAlert()` NSAlert만 유지 (사용자 안내 + 시스템 설정 deep link)
    - 효과: 시스템 Accessibility Access 창 미노출 → 앱 커스텀 안내만 1회 표시
* Phase B (권한 부여 후 자동 재초기화): ✅
    - `AppDelegate`에 `accessibilityPollingTimer` 프로퍼티 추가
    - `checkAccessibilityPermission()` 미승인 경로에서 `startAccessibilityPolling()` 호출
    - 5초 주기로 `AXIsProcessTrusted()` 재검사, 최대 10분 (120회) 후 자동 종료
    - 권한 감지 시 `reinitializeKeyEventMonitor()` 호출 — stopMonitoring + cleanup + 새 인스턴스 + startMonitoring
    - 프로세스 relaunch 없이 CGEventTap 재등록만으로 키 감지 활성화
* 구현 명세:
    - Phase A·B를 하나의 코드 커밋(353e8fe)에 포함
    - Release 빌드에서도 동일 효과 확인 필요 (추후)
* 검증:
    - ✅ Phase A 적용 후 권한 미승인 상태에서 앱 기동 시 시스템 다이얼로그 미노출 확인
    - ✅ 커스텀 NSAlert "접근성 권한 필요" 1회만 노출 확인
    - ✅ 폴링 로그 확인 (`⏱️ 접근성 권한 폴링 시작 (5초 주기, 최대 10분)`)
    - ✅ 권한 부여 후 자동 재초기화 로그 확인 및 키 감지 정상 동작 (사용자 "잘 작동함")
* 관련 파일:
    - `cli/fSnippetCli/fSnippetCliApp.swift` (Phase A + B 구현)
    - 참고: `fWarrange/_public/cli/fWarrangeCli/AppState.swift`, `Services/AccessibilityService.swift`

## Issue41: fsc-run-xcode.sh 구조 정비 — Phase1(DRY) + Phase2(Xcode run→stop TCC 획득 + /deploy debug 신설) (등록: 2026-04-18, 해결: 2026-04-19, commit: 2084147, 3513713) ✅
* 목적: fsc-run-xcode.sh의 빌드·실행 흐름을 TCC 권한 귀속 관점에서 올바르게 재설계. Xcode AppleScript로 `run ws`까지 시켜 TCC 권한을 앱에 귀속시킨 뒤 `stop`으로 Xcode 세션 분리, 그리고 `/deploy debug`로 Applications 배포·독립 기동
* 배경: Phase1 완료 후 사용자 피드백 — "AppleScript로 build만 하고 open으로 기동"하는 흐름은 TCC가 Xcode 세션에 귀속된 상태가 아닌, 독립 프로세스로 open되므로 **TCC 권한 문제가 실제로는 해결되지 않음**. 올바른 흐름은 Xcode에서 run→stop으로 최초 1회 TCC 승인을 얻은 뒤 /deploy debug로 독립 실행
* Phase 1 (commit: 2084147): inline stop 중복 제거
    - `fsc-run-xcode.sh` `xcode_build()` 진입부 `open_project` + inline AppleScript stop 블록(총 9줄) 제거
    - 해당 위치에 `xcode_stop` 함수 호출 한 줄로 교체 (xcode_stop 내부에서 `open_project`와 stop 모두 수행)
    - activate + build 로직은 그대로 유지 — DRY 확보
* Phase 2 (commit: 3513713): Xcode run→stop TCC 획득 + /deploy debug 신설
    - `fsc-run-xcode.sh` `xcode_run_stop()` 신규 함수: AppleScript `run ws` → 1초 delay → `stop ws` (TCC 권한 획득)
    - `build-deploy` 흐름 재구성: build → xcode_run_stop (TCC 획득) → `fsc-deploy-debug.sh` 호출 (Applications 배포 + 독립 open)
    - `fsc-deploy-debug.sh` 신설: 기존 `deploy()` / `run_app()` / `get_build_dir()` 로직 이관. `/deploy debug` 및 `fsc-run-xcode.sh`에서 공용 호출
    - `/deploy` 커맨드 `debug` 인자 분기 추가 (Debug 빌드 결과물 → `/Applications/_nowage_app/` 복사 + 실행, `xattr -cr` 포함)
    - `fsc-run-xcode.sh`에서 기존 `get_build_dir/deploy/run_app` 함수 제거 — 중복 해소
    - `run-only`는 `kill_app` + `open "$APP_PATH"`로 단순화 (배포 앱 미존재 시 안내)
* 구현 명세:
    - stop AppleScript 소스 단일 지점 (`xcode_stop()` 한 곳만 유지)
    - 기능 동작: stop → activate → build → **run→stop (TCC)** → deploy → run (독립 open)
    - TCC 다이얼로그 승인은 최초 1회만 필요 (접근성·Automation 권한)
    - `/deploy debug`는 `fsc-config.sh`의 `APP_NAME/APP_PATH/DEPLOY_DIR` 재사용
    - `pkill -f xcodebuild` 재도입 금지 (주석으로만 명시)
    - Release 경로는 기존 `/deploy` 유지 (xcodebuild Release)
* 검증:
    - ✅ `/run` (build-deploy) 전체 흐름 정상: stop → open → build → run-stop → deploy → run
    - ✅ `/run kill` → fSnippetCli만 종료, 타 Xcode 워크스페이스 유지
    - ✅ `bash cli/_tool/fsc-run-xcode.sh stop` 단독 실행 안전
    - ✅ `/deploy debug` 단독 실행 시 Debug 빌드 결과물 배포 + 실행 (fsc-deploy-debug.sh)
    - ✅ `bash cli/_tool/fsc-test.sh` ZTest 9단계 전체 통과 — "✅ 테스트 성공"
    - ✅ REST 3015 정상 응답 (`"status": "ok"`, snippet_count 확인)
* 관련 파일:
    - `cli/_tool/fsc-run-xcode.sh` (수정)
    - `cli/_tool/fsc-deploy-debug.sh` (신규)
    - `.claude/commands/deploy.md` (로컬 전용, `release`/`debug` 인자 분기)

## Issue40: Xcode GUI 기반 빌드·테스트 진입점 재설계 (TCC 회피 · 향후 앱 모델) (등록: 2026-04-18, 해결: 2026-04-18, commit: e8bff18) ✅

* 목적: `/run` 계열 개발 흐름에서 TCC 재요청을 제거하고, 래퍼 스크립트 없는 역할 분리 구조를 확립해 향후 모든 앱의 표준 모델로 제시
* 위상: fSnippetCli(#25)가 향후 신규 앱 전체의 reference model. pairApp fWarrangeCli(#26) Issue31 POC에서 `run.sh` 래퍼 유지 → 래퍼 완전 제거 구조로 진화
* 설계 경로: office-hours 세션(2026-04-18) — run.sh 완전 제거 + `fsc-test.sh` 독립 + `/run` 커맨드 인자 분기
* 완료 내용:
    - 신규 Script: `cli/_tool/fsc-config.sh`, `cli/_tool/fsc-run-xcode.sh`, `cli/_tool/fsc-test.sh`
    - 이동 Script: `cli/_tool/run.sh` → `cli/_tool/run.sh_old` (git rename 100%, 히스토리 보존)
    - `kill.sh` workspace 스코프화 — `every workspace document` 전역 stop 제거 + `fsc-config.sh` source
    - `.claude/commands/run.md` 인자 분기 재작성 (build-run/run-only/kill/full/기타)
    - `.claude/agents/build.md` Debug 섹션만 `fsc-run-xcode.sh`로 전환 (Release는 xcodebuild 유지)
    - `.claude/settings.local.json`: `Bash(osascript:*)` + `fsc-*.sh` 권한 추가
    - `.gitignore`: `cli/_tool/.last_build_path` 캐시 제외
* 진입점 아키텍처:
    - `/run` (기본) → `fsc-run-xcode.sh build-deploy` (Xcode GUI Debug 빌드+배포+실행)
    - `/run run-only` → `fsc-run-xcode.sh run-only`
    - `/run kill` → `kill.sh`
    - `/run full` → `fsc-test.sh` (ZTest 9단계)
    - `/build`·`/verify`·`/deploy`·`/brew-apply` → `xcodebuild` 유지 (Release 또는 빌드만)
* 핵심 개선 (pairApp 대비 진화):
    - `pkill -f xcodebuild` 전역 종료 제거 — 다른 Xcode 프로젝트 CLI 빌드 영향 없음
    - `xcode_build` 내부에서 workspace 한정 stop 흡수 — dispatch 간결화
    - `xcode_stop` 내부 `open_project` 선행 호출 — workspace 미로드 상태 안정
* 검증:
    - ✅ Xcode 미실행 상태에서 `/run` → 자동 오픈 → Debug 빌드+배포+실행 성공
    - ✅ Xcode 실행 중 상태에서 `/run` 반복 → 중복 오픈 없이 빌드 성공
    - ✅ 반복 `/run` 실행 시 **TCC 재요청 없음** (핵심 목적 달성)
    - ✅ `/run run-only` → 재빌드 없이 실행, uptime 갱신 확인
    - ✅ `/run kill` → 해당 workspace만 stop, 다른 Xcode 프로젝트 영향 없음
    - ✅ `curl http://localhost:3015/` 정상 응답 (status ok, port 3015, snippet_count 1954)
    - ✅ mtime skip 배포 캐싱 동작 (`[deploy] 변경 없음 (skip)`)
    - ✅ pairApp `fwc-*.sh` 구조와 1:1 정합 (접두어·포트 값 차이만) — `run_diff_pairApp.md` 보고서 참조
* 후속 이슈:
    - Issue41: `xcode_build` inline stop 중복을 `xcode_stop` 함수 호출로 교체 (DRY)
    - 별도 이슈: paidApp #15 fSnippet 메인 앱 동일 패턴 이식
    - 별도 이슈: pairApp #26 — `xcode_build` 내부 stop 흡수 역이식 (Issue40 개선 모델 적용)
* 참조:
    - pairApp POC: `~/_git/__all/fWarrange/_public/cli/_doc_work/report/xcode-build-migration_issue31_report.md`
    - 비교 보고서: `cli/_doc_work/report/run_diff_pairApp.md`

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
* plan: `cli/_doc_work/z_done/plan/start-nPTiR_plan.md`
* task: `cli/_doc_work/z_done/tasks/start-nPTiR_task.md`
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

## Issue44: Login Item 자동 등록 (obsolete — Issue45 `brew services` 경로로 대체) (등록: 2026-04-19, 취소: 2026-04-19, commit: 1d01e68 → 후속 커밋에서 산출물 삭제)
* 취소 사유: 오픈소스 배포 관점에서 사용자 표준 인터페이스는 `brew services start/stop/info`. Login Item(osascript) 경로는:
    - 외부 에이전트 도구로 비가시적 (배포 Formula만 읽어서는 자동 시작 흐름 이해 불가)
    - osascript → `System Events` 자동화 권한 요구 (TCC Automation 별도 승인)
    - `brew services`와 **배타적** (§7-5-C) — 오픈소스 배포 표준을 우선하므로 Login Item 폐기
* 완성되었던 산출물 (커밋 1d01e68에 포함, Issue45 구현 커밋에서 삭제):
    - `cli/_tool/fsc-loginitem.sh` (283줄, register/unregister/status + 강제 재등록 + stale 탐지) — **삭제 예정**
    - `fsc-deploy-brew.sh` Step 8: `FSC_AUTOSTART=1` 옵트인 Login Item 등록 → Issue45에서 `brew services start` 로 대체
    - `fsc-deploy-brew.sh` cmd_uninstall의 Login Item 자동 해제 훅 → Issue45에서 `brew services stop` 으로 대체
    - `fsc-deploy-brew.sh` cmd_status의 Login Item 섹션 → Issue45에서 `brew services info` 로 대체
* 유지된 부분 (Login Item과 무관한 개발 편의 인프라):
    - `/Applications/_nowage_app/fSnippetCli.app` 심링크 전략 (§7-4) — `brew services` 경로와 병행 호환
    - Step 7의 심링크 생성 로직
* 기술적 발견 (재활용 가능 지식):
    - AppleScript `System Events` + `make login item` 은 심링크를 자동 resolve하여 bundle alias(FSRef)로 저장
    - Homebrew Cellar 버전 폴더 경로가 Login Item에 inode-bound → 업그레이드 시 stale alias 발생
    - 해결 전략: register를 항상 강제 재등록(unregister → register) 패턴으로 구현 — 일반 Login Item 자동화 시 참고 가능
    - whose절 + 역순 repeat 일괄 삭제 패턴 (중복 등록 잔재 정리)
* 원본 이슈 기록 참조: Issue.md 1d01e68 커밋 버전 (git history)

# 📜 참고
