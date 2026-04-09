---
name: SKILL
description: 마크다운 파일의 목차(TOC)를 자동으로 생성하고 업데이트합니다.
---

# TOC Generator Skill (목차 생성 스킬)

이 스킬은 마크다운 파일에 대한 목차(Table of Contents)를 자동으로 생성합니다.
특히 `## 📋 목차` 헤더를 찾아 그 아래에 문서 내 `H1` (#) 헤더들을 기반으로 목록을 갱신합니다.

## 사용법 (Usage)

```bash
python3 .agent/skills/toc/scripts/toc.py --file [파일경로] [--apply]
```

- `--file`: 마크다운 파일 경로.
- `--apply`: 지정 시 파일을 직접 수정합니다. 생략 시 표준 출력(stdout)으로 새 목차를 출력합니다.

## 로직 (Logic)
1.  **대상 헤더**: `## 📋 목차`를 찾습니다.
2.  **범위**: 대상 헤더부터 다음 헤더(`#` 또는 `##`) 또는 블록 끝까지 작업합니다.
3.  **내용**: 문서의 첫 줄(문서 제목)을 제외한 모든 `H1` (`# 제목`) 헤더를 수집합니다.
4.  **포맷팅**: `1. [제목](#앵커)` 형식의 번호 매기기 목록을 생성합니다.
5.  **앵커 (Anchors)**:
    - 텍스트를 소문자로 변환합니다.
    - 공백을 하이픈(`-`)으로 대체합니다.
    - 특수 문자를 제거합니다 (영문자, 숫자, 하이픈, 한국어 문자는 유지).
    - GitHub/VSCode 마크다운 앵커 스타일과 일치시킵니다.

## Example
**Input:**
```markdown
# My Doc

## 📋 목차

# Section A
# Section B
```

**Output:**
```markdown
# My Doc

## 📋 목차

1. [Section A](#section-a)
2. [Section B](#section-b)

# Section A
...
```
