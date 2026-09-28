---
name: PROMPTS
description: fSnippetCli(_public) 프로젝트 프롬프트 모음
date: 2026.09.27
---

# Info
## 자주쓰는 프롬프트 모음

### 빌드·배포
* /run
* /run kill
* /run --help
* /deploy brew local
* 다시 컴파일 후 brew local deploy
* brew deploy된 것 맞나?
* /api-test

### jma 사용자 테스트
* /sync-jma
* jma에서 run, 권한 주겠음.
* jma 클리어하고 사용자 입장에서 설치 후 확인. paidApp은 scp, cliApp은 brew로 배포.
* jma에서 배포 시 brew 문제 없는지 확인.
* jma에서 설정창 스크린샷 찍어줘.

### 개발 주기
* /dev Issue{{이슈번호}}
* /issue-fix-m {{이슈번호}}
* /issue-closer
* 로그 확인해봐. 문제 계속 발생.
* 해결된 것 같군. debug_TECH 업데이트해줘.
* noteForHuman.md에 명시해줘(상황, 해결책).
* prj26에서도 같은 문제가 생길 것 같은데 이슈 등록하고 진행해줘.
* /uc

# History
## 2026.09.27
* 복사용 평문 형식으로 전환 — 백틱·부연 설명 제거, 한 줄 한 프롬프트, 변수 자리는 fSnippet 플레이스홀더 {{필드명}} 형식
* 초기 생성 — 세션 히스토리(`history.jsonl`·세션 로그) 기반. `fWarrange/_public/PROMPTS.md` 양식 준수
