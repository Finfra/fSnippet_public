---
name: snippet-rules
description: "스니펫 규칙 및 _rule.yml 관리 워크플로우 (Rule Manager Skill 사용)"
---

# 스니펫 규칙 관리 워크플로우

1. **현황 분석 (Analyze Current Rules)**:
   - `snippets/_rule.yml` (또는 각 폴더의 `_rule.yml`)을 확인합니다.
   - 변경하려는 규칙이 기존 규칙과 충돌하지 않는지 `.claude/rules/snippet-rules.md`를 참고하여 분석합니다.

2. **백업 (Backup)**:
   - 규칙 파일 수정 전 백업을 권장합니다.

3. **규칙 수정 (Modify Rules)**:
   - YAML 형식을 철저히 준수하여 규칙을 수정하거나 추가합니다.
   - **주의**: Prefix/Suffix 설정 시 들여쓰기와 배열 형식을 정확히 지킵니다.

4. **검증 (Validate)**:
   - `_tool` 폴더 내에 YAML 유효성 검사 스크립트가 있다면 실행합니다. (또는 로컬 테스트)
   - 앱을 재시작하여 규칙이 정상적으로 로드되는지 확인합니다. (`flog.log` 확인)

5. **문서화 (Document)**:
   - `Rule Manager Skill`을 사용하여 문서를 동기화하거나 등록합니다.
   - 예: `sh agents/gemini/skills/rule-manager/scripts/register-rule.sh snippets/_rule.yml snippet-rules` (필요시)
   - 문서 업데이트가 필요한 경우: `.claude/rules/snippet-rules.md`를 직접 수정하거나 `/rule-mgr sync`를 실행합니다.
