---
name: SKILL
description: Issue.md의 Save Point 섹션을 업데이트합니다.
---

# Save Point Update Skill (세이브 포인트 업데이트 스킬)

이 스킬은 `Issue.md` 파일의 'Save Point' 섹션에 새로운 커밋 해시와 메시지를 추가하여 작업 이력을 기록합니다.

## 필수 조건 (Prerequisites)
- Python 3 설치 필요.
- 프로젝트 루트에 `Issue.md` 존재.
- `Issue.md` 내에 `* Save Point :` 헤더 존재.

## 사용법 (Usage)

`scripts` 디렉토리의 `save-point.py`를 실행합니다.

```bash
# 도움말 표시
python3 .agent/skills/save-point-update/scripts/save-point.py --help

# Save Point 추가
python3 .agent/skills/save-point-update/scripts/save-point.py \
  --hash "a1b2c3d" \
  --msg "Docs: Close Issue 568" \
  --file "Issue.md"
```

## 옵션 (Options)
- `--hash`: (필수) 커밋 해시 (예: `3f81e98`)
- `--msg`: (선택) 설명 메시지 (기본값: "Update")
- `--file`: (선택) 대상 파일 경로 (기본값: "Issue.md")
