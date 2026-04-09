---
name: cmd_design
description: fSnippetCli CLI 커맨드라인 인터페이스 설계 문서
date: 2026-04-08
---

# 배경

fSnippetCli는 현재 GUI(MenuBarExtra) + REST API로만 동작함. CLI 커맨드를 추가하여 터미널에서 직접 제어 가능하게 함.

## 설계 원칙

* Swift `CommandLine.arguments` 기반 (외부 의존성 없음)
* GUI 모드(기본)와 CLI 모드를 인자 유무로 분기
* 인자 없이 실행 시 기존 GUI 모드 유지 (하위 호환)
* REST API와 동일한 기능을 CLI에서도 제공

# 커맨드 구조

```
fSnippetCli [command] [subcommand] [options]
```

## 글로벌 옵션

| 옵션              | 단축 | 설명                      |
| :---------------- | :--- | :------------------------ |
| `--help`          | `-h` | 도움말 출력               |
| `--version`       | `-v` | 버전 정보 출력            |
| `--port <port>`   | `-p` | API 포트 지정 (기본 3015) |
| `--json`          |      | JSON 형식으로 출력        |

# 커맨드 목록

## 1. 서비스 관리

| 커맨드     | 설명                                |
| :--------- | :---------------------------------- |
| (인자없음) | GUI 모드 실행 (기존 동작)           |
| `status`   | 서비스 상태 출력 (실행 여부, 포트)  |
| `version`  | 버전 및 빌드 정보 출력              |

## 2. 스니펫

| 커맨드                    | 설명                              |
| :------------------------ | :-------------------------------- |
| `snippet list`            | 전체 스니펫 목록                  |
| `snippet search <query>`  | 스니펫 검색                       |
| `snippet get <id>`        | 스니펫 상세 조회                  |
| `snippet expand <abbrev>` | abbreviation → 텍스트 확장 (stdout) |

## 3. 클립보드

| 커맨드                      | 설명                    |
| :-------------------------- | :---------------------- |
| `clipboard list`            | 클립보드 히스토리 목록  |
| `clipboard get <id>`        | 클립보드 항목 상세      |
| `clipboard search <query>`  | 클립보드 검색           |

## 4. 폴더

| 커맨드              | 설명                          |
| :------------------ | :---------------------------- |
| `folder list`       | 폴더 목록                     |
| `folder get <name>` | 폴더 상세 (스니펫 포함)       |

## 5. 통계

| 커맨드         | 설명                |
| :------------- | :------------------ |
| `stats top`    | 사용 빈도 Top N     |
| `stats history` | 사용 이력          |

## 6. 트리거

| 커맨드    | 설명           |
| :-------- | :------------- |
| `trigger` | 트리거 키 정보 |

## 7. 설정

| 커맨드   | 설명                                        |
| :------- | :------------------------------------------ |
| `config` | 현재 설정 출력 (REST API 경유, 읽기 전용)   |

> **Note**: 설정 GUI는 fSnippet 유료 앱 전용 (Issue5에서 CLI 설정창 제거됨).

## 8. 임포트

| 커맨드                         | 설명                     |
| :----------------------------- | :----------------------- |
| `import alfred <path>`         | Alfred 스니펫 임포트     |

# 공통 옵션

| 옵션             | 적용 대상        | 설명                  | 기본값 |
| :--------------- | :--------------- | :-------------------- | :----- |
| `--limit <n>`    | list, search 계열 | 결과 개수 제한        | 20     |
| `--offset <n>`   | list, search 계열 | 결과 시작 위치        | 0      |
| `--json`         | 전체             | JSON 형식 출력        | off    |

# 구현 방식

## 아키텍처

```
main() / AppDelegate
├── CLI 인자 있음 → CLIRouter.run(args)
│   ├── CommandParser.parse(args) → Command
│   ├── CommandExecutor.execute(command)
│   │   ├── 로컬 실행 (SnippetFileManager 직접 호출)
│   │   └── 또는 REST API 호출 (localhost:3015)
│   └── OutputFormatter.format(result, json: bool)
└── CLI 인자 없음 → 기존 GUI 모드
```

## 핵심 파일

| 파일                    | 역할                              |
| :---------------------- | :-------------------------------- |
| `CLI/CLIRouter.swift`   | 인자 파싱 및 커맨드 분기          |
| `CLI/CommandParser.swift` | 커맨드/옵션 파싱                |
| `CLI/CommandExecutor.swift` | 커맨드 실행 (REST 호출 또는 직접) |
| `CLI/OutputFormatter.swift` | 출력 포매팅 (text/json)       |
| `CLI/Commands/*.swift`  | 개별 커맨드 구현                  |

## 실행 모드 분기

```swift
// fSnippetCliApp.swift 또는 main.swift
let args = CommandLine.arguments
if args.count > 1 {
    // CLI 모드: GUI 초기화 없이 커맨드 실행 후 종료
    let exitCode = CLIRouter.run(Array(args.dropFirst()))
    exit(exitCode)
} else {
    // GUI 모드: 기존 MenuBarExtra 앱 실행
    fSnippetCliApp.main()
}
```

## REST API 호출 방식

CLI 커맨드는 이미 실행 중인 fSnippetCli 인스턴스의 REST API를 호출하는 방식으로 동작:

```swift
// ex) fSnippetCli snippet search docker
// → GET http://localhost:3015/api/v1/snippets/search?q=docker
func executeViaAPI(endpoint: String) -> (Int, Data?) {
    let url = URL(string: "http://localhost:\(port)\(endpoint)")!
    let (data, response, _) = URLSession.shared.synchronousDataTask(with: url)
    return (response.statusCode, data)
}
```

* 장점: API 서버 로직 재사용, GUI 인스턴스와 동일 데이터
* 전제: fSnippetCli가 이미 서비스로 실행 중이어야 함
* 서비스 미실행 시: "fSnippetCli 서비스가 실행 중이 아닙니다. `brew services start fsnippetcli` 로 시작해주세요" 안내

# 출력 형식

## 기본 (텍스트)

```
$ fSnippetCli snippet list --limit 3
  ID    Abbreviation    Folder    Content
  001   bb⌘            Bash      #!/bin/bash
  002   dc⌘            Docker    docker-compose up -d
  003   gg⌘            Git       git log --oneline -10
```

## JSON (`--json`)

```json
{
  "count": 3,
  "items": [
    {"id": "001", "abbreviation": "bb⌘", "folder": "Bash", "content": "#!/bin/bash"},
    ...
  ]
}
```

# 종료 코드

| 코드 | 의미                    |
| ---: | :---------------------- |
|    0 | 성공                    |
|    1 | 일반 오류               |
|    2 | 잘못된 인자             |
|    3 | 서비스 미실행           |
|    4 | API 통신 오류           |

# API 엔드포인트 매핑

| CLI 커맨드              | REST API                                 |
| :---------------------- | :--------------------------------------- |
| `status`                | `GET /api/v1/cli/status`                 |
| `version`               | `GET /api/v1/cli/version`                |
| `snippet list`          | `GET /api/v1/snippets`                   |
| `snippet search <q>`    | `GET /api/v1/snippets/search?q=<q>`      |
| `snippet get <id>`      | `GET /api/v1/snippets/<id>`              |
| `snippet expand <abbr>` | `POST /api/v1/snippets/expand`           |
| `clipboard list`        | `GET /api/v1/clipboard/history`          |
| `clipboard get <id>`    | `GET /api/v1/clipboard/history/<id>`     |
| `clipboard search <q>`  | `GET /api/v1/clipboard/search?q=<q>`     |
| `folder list`           | `GET /api/v1/folders`                    |
| `folder get <name>`     | `GET /api/v1/folders/<name>`             |
| `stats top`             | `GET /api/v1/stats/top`                  |
| `stats history`         | `GET /api/v1/stats/history`              |
| `trigger`               | `GET /api/v1/triggers`                   |
| `config`                | `GET /api/v1/settings`                   |
| `import alfred <path>`  | `POST /api/v1/import/alfred`             |

# 구현 우선순위

## Phase 1 (필수)
* `--help`, `--version`
* `status`
* `snippet list`, `snippet search`

## Phase 2 (핵심)
* `snippet expand`, `snippet get`
* `clipboard list`, `clipboard search`
* `folder list`
* `--json` 옵션

## Phase 3 (확장)
* `stats top`, `stats history`
* `trigger`, `config`
* `import alfred`
* `--limit`, `--offset` 옵션

# 유료 전용 기능 제한

아래 기능은 fSnippetCli(무료)에서 제공하지 않으며, fSnippet 유료 앱에서만 사용 가능:

| 기능                 | CLI 동작              | 관련 이슈 |
| :------------------- | :-------------------- | :-------- |
| ⌘S Save To Snippet   | 미지원 (토스트 안내)  | Issue7    |
| 설정 단축키 (^⇧⌘;)  | 미지원 (토스트 안내)  | Issue8    |
| 스니펫 편집 (Tab 키) | 미지원 (토스트 안내)  | Issue9    |

상세 목록 및 차단 위치: [paid_version.md](paid_version.md)
