---
title: fSnippetCli 배포 재생목록
description: prj25 fSnippetCli(cliApp) 출고 전 jma 에서 설치 채널별 작동을 검증하는 배포용 TDD 재생목록 (prj3#Issue717)
date: 2026.09.27
gate: pre-merge
r2: warn
env: jma
peers: prj15
---

# 무엇을 지키나

사용자가 받는 fSnippetCli 산출물(소스 빌드·app 번들·brew local·GitHub release tarball·공개 tap)이 jma 클린 환경에서 설치·기동·확장·REST 까지 작동하고, 같은 버전의 paidApp(prj15)과 붙어 동작하는지를 지킨다.

* 브랜치 모델: `release/{X.Y.Z}` → R1 은 release 브랜치 HEAD(clean). 2-레포 락스텝이므로 증거에 prj15 후보 커밋 SHA 를 함께 기록한다 ([fapp-gitflow](~/_git/___pm/_doc_arch/fapp-gitflow.md))
* 실행 머신은 **jma**. 원격 빌드·서명은 tmux 경유 + 화면 잠금 해제 상태에서 한다 ([jma-fsnippet-deploy](.claude/skills/jma-fsnippet-deploy/SKILL.md))

# 재생목록

위에서 아래로 돈다 — 2행(클린 상태)이 깨지면 뒤 행의 통과는 «깨끗한 설치» 증거가 아니다.

| #   | id                           | 채널     | 목표                                                                                                                                                            | 근거                                                                                                          | 실행                                                                              | 상태      |
| :-- | :--------------------------- | :------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------ | :-------------------------------------------------------------------------------- | :-------- |
| 1   | `dev-playlist-green`         | —        | 개발 재생목록(`tdd/playlist.md`) 전 행 통과                                                                                                                     | tdd/playlist.md                                                                                               | `tdd/playlist.md`                                                                 | ⬜ 미실행 |
| 2   | `jma-clean-state`            | —        | jma 의 fSnippet·fSnippetCli 흔적(앱·brew·LaunchAgent·Containers·defaults·TCC)이 제거 검증 FAIL 0 이다                                                           | .claude/skills/jma-fsnippet-clear/SKILL.md                                                                    | `bash .claude/skills/jma-fsnippet-clear/scripts/jma-fsnippet-clear.sh --yes`      | ⬜ 미실행 |
| 3   | `source-build-from-readme`   | 소스     | jma 에서 공개 repo clean clone → README «Build from Source» 명령(`xcodebuild -scheme fSnippetCli -configuration Release build`)이 성공하고 산출 app 이 기동된다 | README.md · cli/README.md "Build from Source"                                                                 | —                                                                                 | ⬜ 신규   |
| 4   | `app-bundle-ztest-e2e`       | app      | jma 에서 Debug .app 빌드·배포 뒤 TextEdit 트리거 입력 결과가 testBoard 기대값과 같고, API·CMD 테스트 통과, 로그 ERROR/CRITICAL 0                                | cli/_tool/fsc-test.sh (12단계) · cli/_tool/fsc-deploy-debug.sh                                                | `bash cli/_tool/fsc-test.sh`                                                      | ⬜ 미실행 |
| 5   | `brew-local-install`         | brew     | jma 에서 brew local 재설치 → brew 서비스 `started` · REST `:3015` `ok:true` · 서명 Authority 가 `Apple Development`/`Developer ID`                              | .claude/skills/jma-fsnippet-deploy/SKILL.md · cli/_tool/fsc-deploy-brew.sh `cmd_local`                        | `bash .claude/skills/jma-fsnippet-deploy/scripts/jma-fsnippet-deploy.sh --cliApp` | ⬜ 미실행 |
| 6   | `release-tarball-install`    | 바이너리 | publish 와 같은 방식으로 만든 `fSnippetCli-{VER}.tar.gz`(사전 빌드·서명 app)를 jma 클린 환경에 설치하면 서명이 보존되고 기동·REST 200 이다                      | cli/Formula/fsnippet-cli.rb (`prefix.install "fSnippetCli.app"`) · cli/_tool/fsc-deploy-brew.sh `cmd_publish` | —                                                                                 | ⬜ 신규   |
| 7   | `brew-tap-published-install` | brew     | 공개 tap `brew install finfra/tap/fsnippet-cli` 가 jma 클린 환경에서 설치되고 패키지 라벨 = 번들 `CFBundleShortVersionString` = `VERSION`                       | README.md 설치 절차 · ../_doc_arch/version_manage_with_cliApp.md §6 "산출물 실체 검증"                        | —                                                                                 | ⬜ 신규   |
| 8   | `version-artifact-match`     | —        | 설치본 번들 버전·실행 데몬 응답 version·`VERSION`·Formula `version`/`url`(cli-v{VER}) 이 모두 같다                                                              | ../_doc_arch/version_manage_with_cliApp.md §6 · cli/Formula/fsnippet-cli.rb                                   | —                                                                                 | ⬜ 신규   |
| 9   | `peer-prj15-candidate`       | 연동     | 같은 버전 후보 paidApp(prj15)+cliApp 을 jma 에 함께 배포하면 두 프로세스 실행 · brew `started` · REST `:3015` 응답 · 서명 확인이 FAIL 0                         | .claude/skills/jma-fsnippet-deploy/SKILL.md "검증 항목"                                                       | `bash .claude/skills/jma-fsnippet-deploy/scripts/jma-fsnippet-deploy.sh`          | ⬜ 미실행 |
| 10  | `peer-prj15-api-compat`      | 연동     | 이번 cliApp REST 가 paidApp 이 쓰는 API 스펙과 100% 호환된다                                                                                                    | ../_tool/test/test-api-compat.sh · ../_doc_arch/paid_cli_protocol.md                                          | `bash ../_tool/test/test-api-compat.sh 3015`                                      | ⬜ 미실행 |
| 11  | `peer-prj15-current-release` | 연동     | 현재 출고본 paidApp(App Store 직전 버전)이 이번 cliApp 에 붙어 등록·설정 동기화가 된다 — 락스텝이 아니면 사용자는 구버전과 섞어 쓴다                            | ~/.claude/_doc_arch/rules-ondemand/release-test-rules.md "연동 프로젝트" · ../_doc_arch/paid_cli_protocol.md  | —                                                                                 | ⬜ 신규   |

# 증거

경로 `_doc_work/_release/v{VER}/release-test_{VER}.md` — 형식은 [release-test-rules](~/.claude/_doc_arch/rules-ondemand/release-test-rules.md) «증거 형식».

* frontmatter `version·commit·dirty·result·env·peers·date` — `peers: prj15@{후보 SHA}` 필수(2-레포 락스텝)
* 본문 `| # | id | 결과 | 비고 |` 에 행별 결과. jma 로그 경로(`/tmp/jma_build_*.log` 등)를 비고에 남긴다

# 규약

* 각 행의 목표는 **검증 가능한 성질**이다 — *"잘 설치된다"* 는 목표가 아니다
* 한 행이라도 건너뛰면 `result: partial` 이다 — `pass` 로 쓰지 않는다
* 실패를 삼키는 패턴(`2>/dev/null || true` 등)으로 행을 통과시키지 않는다 — 실패는 실패로 기록한다
