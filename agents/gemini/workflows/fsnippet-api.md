---
name: fsnippet-api
description: "fSnippet API 연동 워크플로우 (Gemini Agent용)"
---

# fSnippet API 연동 워크플로우

이 워크플로우는 fSnippet 애플리케이션이 실행 중일 때, 로컬 API(기본 포트 3015)를 통해 데이터를 조회하거나 제어하는 방법을 안내합니다.

## 필수 확인 사항
- fSnippet 앱이 실행 중인지 확인합니다 (`pgrep -f MacOS/fSnippet`).
- fSnippet 설정(Settings) > Advanced > "API enabled"가 켜져 있는지 확인합니다.
- 기본 포트는 `3015`입니다.

## 주요 API 기능 목록 및 사용 방법
API 스킬(`fsnippet-api-skill`)을 활용하여 다음 작업들을 수행할 수 있습니다.

1. **상태 확인 (Health Check)**
   - 앱 정상 구동 및 버전, 포트, 통계 정보를 확인합니다.
   - `curl http://localhost:3015/`

2. **스니펫 검색 (Search Snippets)**
   - 쿼리를 통해 스니펫을 검색합니다.
   - `curl "http://localhost:3015/api/snippets/search?q={query}"`

3. **스니펫 확장 (Expand Snippet)**
   - Abbreviation을 전달하여 확장된 텍스트 결과를 얻어옵니다. (Placeholder 포함 가능)
   - `curl -X POST http://localhost:3015/api/snippets/expand -H "Content-Type: application/json" -d '{"abbreviation": "..."}'`

4. **클립보드 히스토리 조회 (Clipboard History)**
   - 최근 클립보드 히스토리를 확인합니다.
   - `curl "http://localhost:3015/api/clipboard/history?limit=10"`

5. **사용 통계 (Statistics)**
   - 가장 많이 사용된 스니펫(Top N)을 조회합니다.
   - `curl "http://localhost:3015/api/stats/top?limit=10"`

6. **트리거 키 정보 조회 (Triggers)**
   - 현재 활성화된 트리거 키를 확인합니다.
   - `curl http://localhost:3015/api/triggers`

작업을 수행할 때 `run_shell_command` 도구를 사용하여 위 `curl` 명령어들을 실행하세요.
