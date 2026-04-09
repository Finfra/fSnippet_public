---
name: qa-type-jma-mgr
description: "로컬 코드 푸시 후 jma 서버에서 원격으로 일괄 테스트(Batch Test) 실행"
---

# QA Type JMA Manager Workflow

로컬 프로젝트의 변경사항을 원격 저장소에 푸시하고, `jma` 원격 서버에 접속하여 최신 코드를 pull하고, fSnippet을 재시작한 뒤 `tmux`의 `qa` 세션을 통해 일괄 테스트(Batch Test)를 실행하는 자동화 워크플로우입니다.

> [!NOTE] 에이전트 실행 지침
> 사용자가 특정 파일을 인자로 지정하지 않은 채로 이 워크플로우를 요청한 경우, 사용자에게 따로 확인(질문)하지 말고 기본 타겟 파일인 `Tests/FolderTest/testTable1.md` 파라미터로 사용하여 즉시 배치 테스트 과정을 진행하십시오.

## 0. 진행 상태 확인 모드 (Check / 확인)
사용자가 파라미터로 `check` 또는 `확인`을 함께 전달한 경우(`@[/qa-type-jma-mgr check]`), 아래 명령어를 실행하여 원격 `jma` 서버의 `qa` tmux 세션 화면 내용을 캡처하여 출력합니다. 이 모드가 실행되면 **아래 1~5번의 테스트 파이프라인(Push/Pull/Run)은 수행하지 않고 종료**해야 합니다.

```bash
ssh jma '/opt/homebrew/bin/tmux capture-pane -pS -1000 -t qa'
```

> **에이전트 지시사항**: 위 출력 내용(전체)을 분석하여 다음과 같은 현재 상태를 사용자에게 요약하여 보고합니다:
> - 진행 중인 경우: "현재 X번째 테스트(예: Test 5/10)가 진행 중입니다."
> - 완료된 경우: "Batch test completed" 등의 문구와 함께, **전체 테스트 항목 중 성공(OK)한 개수와 실패(Fail/Error)한 개수를 집계하여 요약해 주십시오.** 만약 실패한 항목이 있다면 어떤 항목(`_caseX` 등)이 실패했는지 목록도 출력하십시오.
> - 세션이 없거나 출력이 비정상인 경우: 해당 내용을 전달.

## 1. 로컬 프로젝트 푸시 (Push)
현재 프로젝트의 변경사항(Staging/Commit 안 된 파일 포함)을 저장하고 원격 브랜치에 푸시합니다.

```bash
git add .
git commit -m "Auto-commit before remote QA test on JMA" || echo "No changes to commit"
git push
```

## 2. JMA 원격 서버: 환경 갱신 및 fSnippet 재시작
`jma` 서버의 소스 코드를 제일 최신으로 당겨오고, 앱 재빌드 및 실행(run.sh) 도중 발생할 수 있는 Xcode 권한 제약(SSH CodeSign Error)을 우회하기 위해 **`qa` tmux 세션 내부로 명령을 전송**하여 실행합니다.

```bash
ssh jma '/opt/homebrew/bin/tmux send-keys -t qa "cd /Users/nowage/_git/__all/fSnippet && git pull && pkill -f \"MacOS/fSnippet\" || true && sh _tool/run.sh" C-m'
```

## 3. JMA 원격 서버: tmux 세션 확인
원격 서버에 UI 기반으로 실행을 유지할 `qa` tmux 세션이 열려있는지 확인합니다.

```bash
ssh jma '/opt/homebrew/bin/tmux has-session -t qa 2>/dev/null'
```
> **⚠️ 에이전트 지시사항**: 위 명령이 실패(종료 코드 1)하면 이 워크플로우의 실행을 **즉시 중단**하고, 사용자에게 다음 과정 안내 메시지를 한국어로 또렷하게 전달해야 합니다!
> ```
> ❌ 원격(jma)에 `qa` tmux 세션이 없습니다!
> VNC 를 통해 서버 데스크탑 환경에 직접 접속하신 뒤, 터미널(Terminal)을 열고 다음 명령어를 입력해주십시오.
> 
> tmux new -s qa
> 
> 세션 생성을 완료하신 이후 다시 실행을 요청해주세요!
> ```

## 4. JMA 원격 서버: 일괄 테스트 명령 전달 (tmux)
세션이 정상적으로 존재한다면, tmux 세션 `qa` 창으로 `qa_run_batch.sh` 테스트 명령어를 전달하여 원격 Mac의 GUI 상에서 타이핑 테스트가 실행되도록 합니다. (엔터 동작을 위해 `C-m` 인자가 붙습니다.)

```bash
# 워크플로우 파라미터를 그대로 원격 스크립트로 전달합니다. (예: Tests/FolderTest/testTable1.md)
ssh jma "/opt/homebrew/bin/tmux send-keys -t qa 'sh _tool/qa/qa_run_batch.sh $@' C-m"
```

## 5. 완료 알림
User Notification 규칙에 따라 작업 완료를 알립니다.

```bash
say 'Complished'
```
