---
name: doc-design
description: "코드 분석을 통한 _doc_design 폴더 내 설계 문서 업데이트"
---

# 설계 문서 업데이트 워크플로우

1. **대상 문서 확인 (Identify Target)**:
   - 사용자가 요청한 `_doc_design/` 폴더 내의 특정 파일을 확인합니다.
   - **주요 설계 문서**:
     - `ARCHITECTURE.md`: 시스템 아키텍처
     - `.claude/rules/snippet-rules.md`: 스니펫 규칙 및 매핑 로직
     - `design_ui.md`: UI 디자인 가이드
     - `design_ui_labels.md`: UI 레이블 및 다국어 키 정의
     - `design_Multi-languageSupport.md`: 다국어 지원 설계
     - `info_GLOSSARY.md`: 프로젝트 용어 정의 (UI 텍스트 변경 시 필수 확인)
     - `diagram_CLASS.mermaid`: 클래스 다이어그램
   - 지정되지 않은 경우, 현재 작업 중인 코드와 관련된 설계 문서를 추론합니다.

2. **관련 코드 검색 (Search Related Code)**:
   - 설계 문서의 내용과 관련된 실제 코드를 찾습니다.
   - `grep_search` 또는 `list_dir`을 사용하여 관련 클래스, Struct, 모듈을 식별합니다.

3. **구현 vs 설계 비교 (Compare Implementation vs Design)**:
   - **코드(As-Is)**: 현재 코드의 실제 동작, 파라미터, 반환값, 구조를 분석합니다.
   - **문서(To-Be)**: 설계 문서에 명시된 내용이 코드와 일치하는지 확인합니다.
   - 일치하지 않는 부분(누락된 기능, 변경된 이름, 폐기된 로직 등)을 식별합니다.
   - **Cross-Check**: 특정 설계 문서를 수정할 때 `_doc_design/ARCHITECTURE.md`의 내용과 상충되지 않는지 반드시 확인합니다.

4. **문서 업데이트 (Update Document)**:
   - 코드의 실제 구현을 반영하여 설계 문서를 수정합니다.
   - 필요한 경우 Mermaid 다이어그램(`diagram_*.mermaid`)도 함께 업데이트합니다.
   - 변경된 내용은 명확하고 간결한 한국어로 작성합니다.

5. **검증 (Verify)**:
   - 업데이트된 설계 문서가 현재 코드를 정확히 설명하는지 다시 한번 확인합니다.

6. **이모지 적용 (Apply Emojis)**:
   - 업데이트된 Mermaid 다이어그램(`diagram_*.mermaid`) 파일에 대해 `emoji-mapper` 스킬을 실행합니다.
   - 명령어: `python3 agents/gemini/skills/emoji-mapper/scripts/apply_emojis.py [파일경로]`
   - 예시: `python3 agents/gemini/skills/emoji-mapper/scripts/apply_emojis.py _doc_design/diagram/DIAGRAM_CLASS_all.mermaid`
