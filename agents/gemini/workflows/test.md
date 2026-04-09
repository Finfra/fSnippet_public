---
name: test
description: "표준화된 빌드 및 테스트 프로세스 (빌드 -> 초기화 -> 실행 -> 검증)"
---

# Test Workflow

`/test` 명령어를 사용하여 표준화된 5단계 테스트 프로세스를 실행합니다.

## 1. 테스트 환경 초기화 (Init)
테스트 보드(`testBoard.txt`)를 초기화합니다.

```bash
// turbo
echo "" > _tool/testBoard.txt
```

## 2. 앱 빌드 및 실행 (Build & Run)
기존 프로세스를 종료하고, 빌드 후 앱을 실행합니다. (Standard Run Script)

```bash
// turbo
sh _tool/run.sh
```

## 3. 검증 준비 (Verify Setup)
TextEdit로 테스트 보드를 열어 테스트 준비를 마칩니다.

```bash
// turbo
open -a TextEdit _tool/testBoard.txt
```

## 4. 로그 모니터링 (Monitor)
필요한 경우 로그를 확인합니다. (별도 터미널 권장)
`tail -f /tmp/fSnippet.log`
