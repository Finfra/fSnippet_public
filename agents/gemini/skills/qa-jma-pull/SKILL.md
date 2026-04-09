---
name: SKILL
description: "ssh jma 원격 서버에 접속하여 fSnippet 폴더(/Users/nowage/_git/__all/fSnippet)의 변경사항을 최신으로 갱신(git pull)하는 워크플로우를 제공합니다."
---

# QA JMA Pull Skill

이 스킬은 `jma` 서버의 `/Users/nowage/_git/__all/fSnippet` 디렉토리에 접속하여 `git pull`을 실행함으로써 최신 코드를 즉시 갱신하는 절차를 설명합니다.

## 사용 시기
- 로컬에서 푸시(push)한 내용이나 원격 저장소의 최신 변경사항을 `jma` 서버(QA/테스트 환경 등)에 즉시 반영해야 할 때 호출합니다.
- 사용자가 "jma에서 pull 해줘" 또는 이와 유사한 요청을 할 때 사용합니다.

## 실행 방법

에이전트는 터미널 도구를 사용하여 다음 명령어를 차례대로 실행해야 합니다:

1. `jma` 서버에서 `git pull` 실행
```bash
ssh jma 'cd /Users/nowage/_git/__all/fSnippet && git pull'
```

2. 성공 여부 확인 후 완료 알림 실행 (사용자 규칙 필수 사항)
```bash
say 'Complished'
```

## 유의 사항
- 만약 충돌(conflict)이나 관련 오류 메세지가 발생한다면, 사용자에게 해당 내용을 보고하고 어떻게 처리할지 문의하십시오.
- 이미 최신 상태(Already up to date)인 경우에도 정상 완료된 것이므로 완료 알림을 수행합니다.
