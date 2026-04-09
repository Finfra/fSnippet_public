---
name: qa-type-mgr
description: "여러 개의 입력값을 일괄 테스트하고 결과를 CSV로 저장 (Batch Test)"
---

# QA Type Manager Workflow

사용자가 제공한 입력값(텍스트, CSV 파일, 또는 Markdown 테이블 파일)을 테스트하고, 결과를 `_doc_work/ReportQaCsv/`에 타임스탬프가 지정된 파일로 저장합니다.
CSV 파일 제공 시 `abbreviation` 컬럼을 읽어 테스트하며, `.md` 파일 제공 시 테이블의 `prefix`, `key`, `suffix` 컬럼을 조합하여 테스트합니다.

> [!CAUTION] Agent Execution Restriction
> **DO NOT** execute this workflow automatically or without explicit user permission.
> This workflow involves long-running batch tests and UI interactions that interfere with the user's environment.
> Always explain the need and ask the user for confirmation before running `@[/qa-type-mgr]`.

## 1. 일괄 테스트 실행 (Run Batch)
추출된 공통 쉘 스크립트 모듈(`_tool/qa/qa_run_batch.sh`)을 통해 앱 실행 확인, 입력 인자 파싱(텍스트, 파일 구분), 파이썬 배치 러너(`_tool/qa/qa_batch_runner.py`) 실행 및 Markdown 포맷 결과를 터미널에 출력합니다.

```bash
sh _tool/qa/qa_run_batch.sh "$@"
```
