---
name: SKILL
description: 워크플로우 문서(.md)와 시스템 문서(noteForHuman.md, GEMINI.md) 간의 동기화를 자동화합니다.
---

# Workflow Manager Skill (워크플로우 관리 스킬)

이 스킬은 `.agent/workflows/` 디렉토리 내의 워크플로우 정의 파일들을 분석하여, 프로젝트 문서(`noteForHuman.md`, `GEMINI.md`)의 워크플로우 목록과 다이어그램을 자동으로 최신 상태로 갱신합니다.

## 필수 조건 (Prerequisites)
- Python 3 설치 필요.
- `.agent/workflows/` 디렉토리에 유효한 마크다운 워크플로우 파일들이 존재해야 함.
- 워크플로우 파일은 `YAML Frontmatter`에 `description` 필드를 가져야 함.

## 사용법 (Usage)

`scripts` 디렉토리의 `doc-gen.py`를 실행합니다.

```bash
# 문서 자동 동기화 실행
python3 .agent/skills/workflow-mgr/scripts/doc-gen.py
```

## 기능 (Features)
- **워크플로우 파싱**: 모든 `.md` 파일의 이름과 설명(description) 추출.
- **noteForHuman.md 업데이트**:
    - `Agent Workflows` 테이블 자동 갱신 (알파벳 순).
    - Mermaid Flowchart는 (현재는) 구조 유지하되, 필요 시 템플릿 기반 재생성 가능 (Todo).
- **GEMINI.md 업데이트**:
    - `Available Workflows` 목록 자동 갱신.

## 주의사항
- `noteForHuman.md` 등의 대상 파일에 특정 마커(주석 등)가 있으면 더 정확하게 동작할 수 있습니다. 현재는 특정 헤더(`## Agent Workflows`)를 기준으로 섹션을 찾아 교체합니다.
