---
title: fSnippet MCP Server
description: fSnippet REST API를 MCP 도구로 제공하는 서버
date: 2026-03-30
---

fSnippet REST API를 [MCP (Model Context Protocol)](https://modelcontextprotocol.io/) 도구로 제공하는 서버입니다.
AI 에이전트(Claude Code, Claude Desktop 등)에서 스니펫 검색, 축약어 확장, 클립보드 히스토리 조회, 사용 통계 확인을 직접 수행할 수 있습니다.

## 전제 조건

fSnippet macOS 앱이 실행 중이고 REST API가 활성화되어 있어야 합니다:

1. **fSnippet.app** 실행
2. **설정 > 고급** 열기
3. **REST API** 활성화

기본 서버 주소: `http://localhost:3015`

---

## 설치

### 방법 1: 글로벌 설치 (권장)

```bash
npm install -g fsnippet-mcp
```

### 방법 2: npx (설치 없이 바로 실행)

별도 설치 없이 MCP 설정에서 `npx`로 직접 실행합니다.

### 방법 3: 소스에서 직접 실행

```bash
git clone https://github.com/finfra/fSnippet_public.git
cd fSnippet_public/mcp
npm install
```

---

## 설정

### Claude Code

`~/.claude/settings.json` 또는 프로젝트 `.claude/settings.json`에 추가:

```json
{
  "mcpServers": {
    "fsnippet": {
      "command": "npx",
      "args": ["-y", "fsnippet-mcp"]
    }
  }
}
```

소스에서 직접 실행했다면:

```json
{
  "mcpServers": {
    "fsnippet": {
      "command": "node",
      "args": [
        "{PROJECT_ROOT}/mcp/index.js"
      ]
    }
  }
}
```

### Claude Desktop

`~/Library/Application Support/Claude/claude_desktop_config.json`에 추가:

```json
{
  "mcpServers": {
    "fsnippet": {
      "command": "npx",
      "args": ["-y", "fsnippet-mcp"]
    }
  }
}
```

소스에서 직접 실행했다면:

```json
{
  "mcpServers": {
    "fsnippet": {
      "command": "node",
      "args": [
        "{PROJECT_ROOT}/mcp/index.js"
      ]
    }
  }
}
```

### 서버 주소 변경

args에 `--server=<url>`을 추가하여 서버 주소를 변경할 수 있습니다:

```json
{
  "mcpServers": {
    "fsnippet": {
      "command": "npx",
      "args": ["-y", "fsnippet-mcp", "--server=http://192.168.0.10:3015"]
    }
  }
}
```

### 글로벌 설치 후 사용

```json
{
  "mcpServers": {
    "fsnippet": {
      "command": "fsnippet-mcp"
    }
  }
}
```

---

## 제공 도구 (Tools)

### 1. `health_check`

fSnippet 서버 상태를 확인합니다. 앱 버전, 포트, 가동 시간, 스니펫/클립보드 수를 반환합니다.

**파라미터**: 없음

**응답 예시**:
```json
{
  "status": "ok",
  "app": "fSnippet",
  "version": "2.1.0",
  "port": 3015,
  "snippet_count": 1937,
  "clipboard_count": 245
}
```

---

### 2. `search_snippets`

키워드로 스니펫을 검색합니다. 축약어, 폴더명, 태그, 설명에서 검색합니다.

**파라미터**:

| 이름     | 타입   | 필수   | 기본값 | 설명                        |
| -------- | ------ | ------ | ------ | --------------------------- |
| `query`  | string | 예     | -      | 검색 키워드                 |
| `limit`  | number | 아니오 | 20     | 최대 결과 수 (최대 100)     |
| `folder` | string | 아니오 | -      | 폴더명으로 필터링           |
| `offset` | number | 아니오 | -      | 결과 시작 위치 (페이징용)   |

**사용 예시** (Claude에게 요청):
```
"docker" 관련 스니펫을 검색해줘
```

---

### 3. `get_snippet`

축약어 또는 ID로 스니펫 상세 정보를 조회합니다. 전체 내용, 플레이스홀더 정보, 메타데이터를 포함합니다.

**파라미터**:

| 이름           | 타입   | 필수   | 설명                                  |
| -------------- | ------ | ------ | ------------------------------------- |
| `abbreviation` | string | 아니오 | 스니펫 축약어 (예: `bb{right_command}`)            |
| `id`           | string | 아니오 | 스니펫 ID (예: `AWS/ec2===EC2.txt`)  |

`abbreviation` 또는 `id` 중 하나를 지정해야 합니다.

---

### 4. `expand_snippet`

축약어를 전체 텍스트로 확장합니다. 플레이스홀더 값을 전달할 수 있습니다.

**파라미터**:

| 이름                 | 타입   | 필수   | 설명                                     |
| -------------------- | ------ | ------ | ---------------------------------------- |
| `abbreviation`       | string | 예     | 확장할 축약어                            |
| `placeholder_values` | object | 아니오 | 플레이스홀더 값 매핑 (키: 이름, 값: 텍스트) |

**사용 예시** (Claude에게 요청):
```
"bb{right_command}" 스니펫을 확장해줘
```

---

### 5. `clipboard_history`

클립보드 히스토리를 조회합니다. 종류, 앱, 고정 여부로 필터링 가능합니다.

**파라미터**:

| 이름     | 타입    | 필수   | 기본값 | 설명                                          |
| -------- | ------- | ------ | ------ | --------------------------------------------- |
| `limit`  | number  | 아니오 | 50     | 최대 결과 수 (최대 200)                       |
| `kind`   | string  | 아니오 | -      | 필터: `plain_text`, `image`, `file_list`      |
| `app`    | string  | 아니오 | -      | 소스 앱 번들 ID로 필터 (예: com.apple.Safari) |
| `pinned` | boolean | 아니오 | -      | 고정된 항목만 필터                            |
| `offset` | number  | 아니오 | -      | 결과 시작 위치 (페이징용)                     |

---

### 6. `clipboard_search`

클립보드 히스토리에서 텍스트를 검색합니다.

**파라미터**:

| 이름     | 타입   | 필수   | 기본값 | 설명                        |
| -------- | ------ | ------ | ------ | --------------------------- |
| `query`  | string | 예     | -      | 검색 키워드                 |
| `limit`  | number | 아니오 | 50     | 최대 결과 수                |
| `offset` | number | 아니오 | -      | 결과 시작 위치 (페이징용)   |

---

### 7. `list_folders`

스니펫 폴더 목록을 조회합니다. 각 폴더의 prefix, suffix, 스니펫 수, 규칙 정보를 포함합니다.

**파라미터**:

| 이름     | 타입   | 필수   | 설명                                         |
| -------- | ------ | ------ | -------------------------------------------- |
| `name`   | string | 아니오 | 폴더명 지정 시 해당 폴더의 스니펫 목록도 반환 |
| `limit`  | number | 아니오 | 스니펫 목록 최대 결과 수 (폴더 지정 시)       |
| `offset` | number | 아니오 | 스니펫 목록 시작 위치 (폴더 지정 시, 페이징용) |

---

### 8. `get_stats`

스니펫 사용 통계를 조회합니다. 가장 많이 사용된 스니펫 또는 사용 이력을 반환합니다.

**파라미터**:

| 이름     | 타입   | 필수   | 기본값 | 설명                                               |
| -------- | ------ | ------ | ------ | -------------------------------------------------- |
| `type`   | string | 아니오 | `top`  | `top` (가장 많이 사용) 또는 `history` (사용 이력)  |
| `limit`  | number | 아니오 | 10     | 결과 수                                            |
| `from`   | string | 아니오 | -      | 시작 날짜 ISO 8601 (history 전용)                  |
| `to`     | string | 아니오 | -      | 종료 날짜 ISO 8601 (history 전용)                  |
| `offset` | number | 아니오 | -      | 결과 시작 위치 (history 전용, 페이징용)            |

---

### 9. `get_triggers`

활성 트리거 키 정보를 조회합니다. 기본 트리거 키와 활성 트리거 목록을 반환합니다.

**파라미터**: 없음

---

## 디버깅

### MCP Inspector로 테스트

```bash
npx @modelcontextprotocol/inspector npx fsnippet-mcp
```

브라우저에서 Inspector UI가 열리며, 각 도구를 직접 테스트할 수 있습니다.

### 서버 연결 확인

```bash
# fSnippet REST API 서버가 실행 중인지 확인
curl http://localhost:3015/
```

---

## npm 배포

```bash
cd mcp
npm publish
```

---

## 아키텍처

```
Claude Code / Claude Desktop
    |
    | MCP (stdio)
    v
fsnippet-mcp (이 서버)
    |
    | HTTP (REST API)
    v
fSnippet.app (localhost:3015)
    └── macOS 네이티브 앱 (Swift/SwiftUI)
```

---

## 라이선스

MIT
