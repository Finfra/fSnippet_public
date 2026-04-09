---
name: SKILL
description: CSV 매핑 파일을 기반으로 파일 내용(Mermaid, 마크다운 등)에 이모지를 자동으로 적용합니다.
version: 1.0.0
---

# Emoji Mapper Skill (이모지 매퍼 스킬)

이 스킬은 중앙 정의 파일(`_doc_design/EmojiForFile.csv`)을 기반으로 문서 파일(Mermaid 다이어그램 등)의 클래스 이름이나 기타 키워드에 이모지를 자동으로 추가하는 프로세스를 자동화합니다.

## 📋 필수 조건 (Prerequisites)
- Python 3 설치 필요
- `_doc_design/EmojiForFile.csv` 경로에 매핑 파일 필요 (형식: `emoji,ClassName,filePath`)

## 🚀 사용법 (Usage)

### 기본 사용법
특정 파일에 이모지를 적용하려면:

```bash
python3 .agent/skills/emoji-mapper/scripts/apply_emojis.py "경로/파일1.mermaid" "경로/파일2.md"
```

### 드라이 런 (Dry Run)
파일을 수정하지 않고 변경 사항만 확인하려면 (변경 내역을 표준 출력으로 표시):

```bash
python3 .agent/skills/emoji-mapper/scripts/apply_emojis.py --dry-run "경로/파일.mermaid"
```

## 🛠️ 설정 (Configuration)
매핑 파일 경로는 현재 프로젝트 루트 기준 `_doc_design/EmojiForFile.csv`로 하드코딩되어 있습니다. 반드시 프로젝트 루트에서 스크립트를 실행하십시오.

## 📝 로직 (Logic)
1. `_doc_design/EmojiForFile.csv`를 로드합니다.
2. 키워드를 길이순(내림차순)으로 정렬하여 긴 클래스 이름부터 일치시킵니다.
3. 세부 로직:
    - YAML Frontmatter(`---` 사이의 줄)는 건너뜁니다.
    - 정규 표현식을 사용하여 전체 단어(`\bClassName\b`)를 일치시킵니다.
    - 단어에 이미 해당 이모지가 접두사로 붙어 있는 경우 건너뜁니다 (멱등성).

## 🆕 새 클래스 등록 (Heuristic Emoji)

클래스에 새 이모지를 할당하고 소스 코드 로그에 주입하려면:

```bash
python3 .agent/skills/emoji-mapper/scripts/register_class.py "ClassName" "경로/소스파일.swift"
```

### 로직
1. `EmojiForFile.csv`를 확인합니다.
2. 휴리스틱 선택:
   - "Manager" -> ⚙️
   - "View" -> 🖼️
   - 기본값: 사용되지 않은 이모지 중 무작위 선택
3. CSV를 업데이트합니다.
4. 파일을 업데이트합니다: `logV("메시지")` -> `logV("⚙️ 메시지")`
