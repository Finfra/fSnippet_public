---
name: refactor
description: "리팩토링 및 구조 개선 워크플로우 (코드 개선 -> 설계 동기화)"
---

# 리팩토링 워크플로우

1. **범위 설정 (Define Scope)**:
   - 리팩토링할 모듈이나 클래스를 명확히 선정합니다.
   - 기능 변경 없이 구조만 개선함을 원칙으로 합니다.

2. **Save Point 확보 (Essential)**:
   - 대규모 리팩토링 전에는 반드시 커밋을 하여 Save Point를 만듭니다. (또는 `Issue.md`에 기록)

3. **코드 개선 (Refactor Code)**:
   - 코드 가독성 향상, 중복 제거, 성능 최적화 등을 수행합니다.

4. **설계 동기화 (Sync Design)**:
   - 리팩토링으로 클래스명, 관계, 파일 위치가 변경되었는지 확인합니다.
   - **설계 문서 업데이트 워크플로우 실행**:
     ```bash
     @[/doc-design]
     ```
   - 위 명령어를 통해 `diagram_CLASS.mermaid` 및 `ARCHITECTURE.md` 등을 체계적으로 업데이트합니다.

5. **검증 (Verify)**:
   - 기존 기능이 동일하게 동작하는지(Regression Test) 확인합니다.
   - `run` 워크플로우를 활용합니다.
