---
name: fsnippet-api-skill
description: fSnippet의 로컬 REST API를 활용하여 스니펫, 클립보드, 통계 정보를 조회하고 텍스트 확장을 시뮬레이션합니다.
---

# fSnippet API Skill

fSnippet 앱이 백그라운드에서 동작 중일 때, Agent가 내부 데이터를 읽고 쓰기 위해 REST API를 호출하는 기술입니다.

## 사용 조건
1. fSnippet 앱 실행 중
2. API 활성화 (`http://localhost:3015/`)

## 핵심 명령어 (cURL 기반)

### 1. 서버 헬스 체크
앱이 API 요청을 받을 준비가 되었는지 확인합니다.
```bash
curl -s http://localhost:3015/
```

### 2. 스니펫 검색
특정 키워드가 포함된 스니펫을 찾습니다.
```bash
curl -s "http://localhost:3015/api/snippets/search?q=YOUR_QUERY"
```

### 3. 클립보드 내역 검색
클립보드 히스토리에서 특정 텍스트를 찾습니다.
```bash
curl -s "http://localhost:3015/api/clipboard/search?q=YOUR_QUERY"
```

### 4. 스니펫 확장 (Expand) 테스트
입력한 축약어(Abbreviation)가 어떻게 확장되는지 텍스트로 결과를 반환받습니다. (UI 입력 시뮬레이션 없이 로직만 검증할 때 유용)
```bash
curl -s -X POST http://localhost:3015/api/snippets/expand \
  -H "Content-Type: application/json" \
  -d '{"abbreviation": "awsec2{right_command}"}'
```

### 5. 통계(Top 10) 가져오기
가장 많이 사용된 스니펫을 확인합니다.
```bash
curl -s "http://localhost:3015/api/stats/top?limit=10"
```

에이전트는 위 명령어들을 `run_shell_command`를 통해 호출하고 응답(JSON)을 파싱하여 작업을 수행하십시오.
