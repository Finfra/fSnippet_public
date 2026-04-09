---
name: SKILL
description: Git 작업(status, add, commit, push) 및 Save Point 검증을 수행합니다.
---

# Git Skill (Git 작업 스킬)

이 스킬은 Git 워크플로우를 단순화하고 자동화합니다. 단순한 명령어 실행뿐만 아니라, **Save Point(이슈 파일의 최신 커밋 해시 기록)** 검증 로직을 포함하여 안전한 푸시를 보장합니다.

## 필수 조건 (Prerequisites)
- `git` 명령어가 설치되어 있어야 함.
- 프로젝트 루트에 `Issue.md` 파일이 존재해야 함 (Save Point 검증용).

## 사용법 (Usage)

`scripts` 디렉토리의 `git-wrapper.sh`를 실행하여 Git 작업을 수행합니다.

```bash
# 도움말 표시
sh .agent/skills/git/scripts/git-wrapper.sh help

# 1. 상태 확인
sh .agent/skills/git/scripts/git-wrapper.sh status

# 2. 변경사항 스테이징 (기본: git add .)
sh .agent/skills/git/scripts/git-wrapper.sh add [파일경로]

# 3. 커밋
sh .agent/skills/git/scripts/git-wrapper.sh commit "메시지 내용"

# 4. 푸시 (Save Point 검증 포함)
sh .agent/skills/git/scripts/git-wrapper.sh push

# 5. 풀 (Pull)
sh .agent/skills/git/scripts/git-wrapper.sh pull

# 6. 일괄 처리 (Auto: Status -> Add -> Commit -> Push)
# 옵션: 특정 파일 지정 가능 (기본값: .)
sh .agent/skills/git/scripts/git-wrapper.sh auto "메시지 내용" [파일경로]
```

## 기능 (Features)
- **Status**: `git status` 실행.
- **Add**: `git add` 실행 (인자 없으면 `.` 사용).
- **Commit**: `git commit -m` 실행. 메시지 없으면 에러 또는 `-v` 모드 진입.
- **Pull**: `git pull` 실행.
- **Push**:
    - `Issue.md`에 기록된 마지막 Save Point(Commit Hash)가 현재 HEAD와 일치하는지 확인.
    - 일치하지 않으면 경고 메시지 출력 (강제 푸시 옵션 없음, 사용자가 직접 해결 권장).
    - 검증 통과 시 `git push` 실행.
