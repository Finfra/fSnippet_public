---
title: fSnippetCli 빠른 시작
description: fSnippetCli 빠른 시작 — 첫 스니펫 만들기 · 확장 · 팝업 · REST 확인 4단계 (한국어)
date: 2026.10.09
---
# 빠른 시작 (Quick Start)

설치(`brew services start fsnippet-cli`)와 손쉬운 사용 권한을 마쳤다는 전제로, 첫 스니펫을 만들어 다른 앱에서 확장해 봅니다. 4단계면 됩니다.

| 단계 | 할 일            | 결과                                  |
| :--- | :--------------- | :------------------------------------ |
| 1    | 첫 스니펫 만들기 | `Demo/hi===Greeting.txt` 파일 하나    |
| 2    | 다른 앱에서 확장 | `dhi` + 오른쪽 ⌘ → `Hello, fSnippet!` |
| 3    | 팝업으로 찾기    | ⌥⇧Space → 검색 → Enter                |
| 4    | REST 로 확인     | `curl` 로 약어 · 내용 조회            |

## Step 1: 첫 스니펫 만들기

스니펫은 **스니펫 폴더 안의 하위 폴더에 있는 텍스트 파일**입니다. 파일명은 `약어===이름.txt` 형식이고, 파일 내용이 확장될 텍스트입니다.

터미널에서:

```bash
mkdir -p ~/Documents/finfra/fSnippetData/snippets/Demo
printf 'Hello, fSnippet!' > ~/Documents/finfra/fSnippetData/snippets/Demo/hi===Greeting.txt
```

Finder 로 하려면 메뉴바 아이콘 › **⚙️ 환경 설정 ▸ 스니펫 폴더 열기** 에서 `Demo` 폴더를 만들고 같은 이름의 텍스트 파일을 저장합니다. REST API 로도 만들 수 있습니다.

```bash
curl -X POST http://localhost:3015/api/v2/folders \
  -H "Content-Type: application/json" -d '{"name":"Demo"}'
curl -X POST http://localhost:3015/api/v2/snippets \
  -H "Content-Type: application/json" \
  -d '{"folder":"Demo","keyword":"hi","name":"Greeting","content":"Hello, fSnippet!"}'
```

## Step 2: 다른 앱에서 확장

약어는 **폴더 접두어 + 파일명의 약어 + 트리거 키** 로 정해집니다.

| 요소        | 값       | 규칙                                            |
| :---------- | :------- | :---------------------------------------------- |
| 폴더 접두어 | `d`      | 폴더명 `Demo` 의 대문자 `D` 를 소문자로         |
| 약어        | `hi`     | 파일명의 `===` 앞부분                           |
| 트리거 키   | 오른쪽 ⌘ | 기본값 `snippet_trigger_key: "{right_command}"` |

텍스트 편집기 · 메모 · 브라우저 입력창 등 아무 앱에서 `dhi` 를 입력하고 **오른쪽 ⌘ 를 한 번** 누르면 `dhi` 가 지워지고 `Hello, fSnippet!` 이 들어갑니다.

* 새 파일은 폴더 감시로 자동 반영됩니다. 반영이 안 되면 메뉴바 **👻 데몬 ▸ 스니펫 다시 불러오기** 를 누르거나 `curl -X POST http://localhost:3015/api/v2/reload` 를 실행하세요
* 그래도 바뀌지 않으면 손쉬운 사용 권한을 확인하세요 — [설치 › 손쉬운 사용 권한](02_Install.md#4-손쉬운-사용-권한)

## Step 3: 팝업으로 찾기

약어가 기억나지 않으면 스니펫 팝업으로 찾습니다.

1. 입력하려는 위치에 커서를 두고 **⌥⇧Space** (메뉴바 **⚡ 스니펫 팝업** 옆에 현재 단축키가 표시됨)
2. 검색창에 `hi` 를 입력
3. **↑ ↓** 로 고르고 **Enter** (또는 **⌘1** ~ **⌘9** 로 바로 선택) — 원래 앱에 텍스트가 들어감
4. 닫으려면 **Esc**

## Step 4: REST 로 확인

```bash
curl -s "http://localhost:3015/api/v2/snippets/search?q=Greeting"
```

응답의 `abbreviation` 이 `dhi{right_command}` 이면 Step 2 의 약어가 맞습니다. 약어를 넘기면 확장 결과만 받아 볼 수도 있습니다.

```bash
curl -s -X POST http://localhost:3015/api/v2/snippets/expand \
  -H "Content-Type: application/json" \
  -d '{"abbreviation":"dhi{right_command}"}'
```

## 한 걸음 더: 날짜 스니펫

파일 내용에 플레이스홀더를 쓰면 확장 시점의 값이 들어갑니다.

```bash
printf '{{date}}' > ~/Documents/finfra/fSnippetData/snippets/Demo/td===Today.txt
```

`dtd` + 오른쪽 ⌘ → `2026-10-09` 처럼 오늘 날짜가 들어갑니다. 문법 전체는 [플레이스홀더 가이드](../Placeholder.md).

## GUI 로 하려면

스니펫을 편집 화면에서 쓰고 설정을 창에서 바꾸는 GUI 는 래퍼 앱 **fSnippet** 이 제공합니다 — [fSnippet 제품 페이지](https://finfra.kr/product/fSnippet/kr/index.html).

## 다음 단계

* [스니펫 사용법](04_Snippet_Usage.md) — 파일명 규칙 · 트리거 키 · `_rule.yml` · 팝업
* [클립보드 히스토리](05_Clipboard_Usage.md) — ⌘; 로 복사 기록 다시 쓰기
* [메뉴바 사용법](06_MenuBar_Usage.md) — 메뉴 · 단축키 · `_config.yml` · 명령행
* [REST API 사용법](07_API_Usage.md) — 전체 엔드포인트
