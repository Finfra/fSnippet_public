---
title: fSnippetCli Claude Code Skill 사용법
description: Claude Code 플러그인(Skill)으로 fSnippetCli 스니펫 · 클립보드를 자연어로 다루기 (한국어)
date: 2026.10.09
---
# Claude Code Skill 사용법

Claude Code 플러그인 **fsnippet** 을 설치하면 Claude Code 안에서 자연어로 스니펫을 검색 · 확장 · 만들고, 클립보드 히스토리와 사용 통계를 조회할 수 있습니다. 플러그인은 fSnippetCli 의 [REST API](07_API_Usage.md)를 호출합니다.

## 전제

* fSnippetCli 가 실행 중이고 REST API 가 켜져 있어야 합니다 — `curl -s http://localhost:3015/api/v2/status`
* 서버가 꺼져 있으면 플러그인은 앱을 대신 띄우지 않고 실행 방법(`brew services start fsnippet-cli`)을 안내합니다

## 설치

플러그인은 통합 플러그인 저장소 [Finfra/f-claude-plugins](https://github.com/Finfra/f-claude-plugins) 의 `fSnippet/` 에 있습니다.

Claude Code 에서:

```
/plugin marketplace add Finfra/f-claude-plugins
/plugin install fsnippet@f-claude-plugins
```

수동 설치(프로젝트 폴더에서):

```bash
git clone https://github.com/Finfra/f-claude-plugins.git
mkdir -p .claude-plugin .claude
cp f-claude-plugins/fSnippet/plugin.json .claude-plugin/plugin.json
cp -r f-claude-plugins/fSnippet/skills .claude/skills
```

## 사용 예

| 입력                                                           | 동작                             |
| :------------------------------------------------------------- | :------------------------------- |
| `/fsnippet:fsnippet docker`                                    | `docker` 로 스니펫 검색          |
| `/fsnippet:fsnippet bb{right_command}`                         | 약어 `bb` 의 확장 결과 보기      |
| `/fsnippet:fsnippet clipboard history`                         | 최근 클립보드 기록               |
| `/fsnippet:fsnippet folders`                                   | 스니펫 폴더 목록                 |
| `/fsnippet:fsnippet stats top 5`                               | 많이 쓴 스니펫 5개               |
| `/fsnippet:fsnippet create snippet in Docker`                  | `Docker` 폴더에 새 스니펫 만들기 |
| `/fsnippet:fsnippet delete snippet Docker/dps===docker ps.txt` | 스니펫 지우기                    |

슬래시 명령 없이 «Docker 폴더에서 ps 관련 스니펫 찾아줘» 처럼 말해도, 요청이 Skill 설명과 맞으면 Claude Code 가 이 Skill 을 골라 씁니다. 그 밖에 엔진 일시 정지 · 재개 · 스니펫 다시 불러오기도 요청할 수 있습니다.

## 문제 해결

| 증상                  | 확인                                                                                                                       |
| :-------------------- | :------------------------------------------------------------------------------------------------------------------------- |
| 서버에 연결할 수 없음 | `brew services info fsnippet-cli` · `curl -s http://localhost:3015/api/v2/status`                                          |
| `503` 응답            | 메뉴바 **👻 데몬 ▸ REST API 재개** (또는 `POST /api/v2/cli/resume`)                                                        |
| 포트를 바꿨음         | Skill 은 `http://localhost:3015` 를 기준으로 씁니다. 다른 포트를 쓰면 설치된 `skills/fsnippet/SKILL.md` 의 주소를 바꿉니다 |

## 다음 단계

* [MCP 서버](09_MCP_Usage.md) — Claude Desktop 등 MCP 클라이언트에서 쓰기
* [REST API 사용법](07_API_Usage.md)
