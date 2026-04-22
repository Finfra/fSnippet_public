# Harness Define

* global General (공통) : `-g` suffix
* local Project (프로젝트 로컬) : suffix 없음
* cf) SCAR(Skills, Commands, Agents, Rules)

# global Layer

> `~/.claude/skills/` 및 `~/.claude/commands/` 에 위치. 모든 프로젝트에서 공통 사용.

## Skills

* `dev-g` — 개발 주기 (이슈 확인 → 구현 → 검증 → 종결)
* `issue-g` — 이슈 전체 라우팅 (분석 → reg/fix 분기)
* `capture-g` — UI 캡처 워크플로우

## Commands

* `/issue-reg-g` — 이슈 등록 (HWM 발급, Issue.md 업데이트)
* `/issue-fix-g` — 이슈 해결 (구현 + 검증 + 문서화)
* `/issue-closer-g` — 이슈 종결 (Hash 기록 + 완료 이동 + 커밋)

## Agents

(없음)

## Rules

* `~/.claude/rules/issue-g.md` — 이슈 관리 공통 규칙

# local Layer

> `.claude/` 에 위치. fSnippetCli 프로젝트 전용.

## Commands

### 글로벌 위임형 (global skill을 호출)

| 커맨드 | 위임 대상 | 설명 |
| :----- | :-------- | :--- |
| `/dev` | `dev-g` 스킬 | 개발 주기 진입점 |

### 로컬 전용 (독립 구현)

| 커맨드 | 설명 |
| :----- | :--- |
| `/issue` | 이슈 라우팅 (reg/fix 분기) |
| `/issue-reg` | fSnippetCli용 이슈 등록 |
| `/issue-fix` | fSnippetCli용 이슈 해결 |
| `/issue-closer` | fSnippetCli용 이슈 종결 |
| `/run` | kill → Xcode Debug 빌드 → 실행 |
| `/build` | Release 빌드만 |
| `/deploy` | debug / brew local / brew publish |
| `/verify` | 빌드 검증 (배포 없음) |
| `/api-test` | REST API v1·v2 검증 |
| `/brew-apply` | Homebrew Formula 수동 패치 |
| `/refactor` | 리팩토링 워크플로우 |
| `/rule-mgr` | `.claude/rules/` 관리 |
| `/workflow-mgr` | `.claude/commands/` 관리 |
| `/toc` | 마크다운 목차 자동생성 |

## Agents

| 에이전트 | 설명 |
| :------- | :--- |
| `build` | Release 빌드 전용 |
| `build-doctor` | 빌드 에러 진단 전용 |
| `deployment` | 배포 전용 |
| `git` | Git 작업 전용 |
| `refactor` | 리팩토링 전용 |
| `rule-manager` | 규칙 관리 전용 |
| `verify` | 빌드 검증 전용 |

## Rules

* `api-rules` — OpenAPI 명세 동기화 규칙
* `coding-rules` — 코딩 표준
* `deploy-rules` — 배포 절차
* `git-rules` — Git 워크플로우
* `issue-rules` — fSnippetCli 이슈 관리 오버라이드
* `language-rules` — 한국어 우선 규칙
* `naming-rules` — kebab-case 네이밍
* `no-worktree` — git worktree 금지 규칙
* `path-rules` — 경로 규칙
* `terminal-rules` — 터미널 실행 규칙
