---
name: SKILL
description: 전용 러너 스크립트를 사용하여 fSnippet 프로젝트의 Swift 단위 테스트를 실행합니다.
---

# TDD Runner Skill (TDD 러너 스킬)

이 스킬은 `_tool/verify/run_unit_tests.sh` 스크립트를 사용하여 `Tests/Test_*.swift`에 위치한 Swift 단위 테스트를 실행합니다.

## 사용법 (Usage)

1.  **모든 단위 테스트 실행**:
    ```bash
    ./_tool/verify/run_unit_tests.sh
    ```

## 범위 (Scope)

-   **대상 파일**: `Tests/UnitTest/Test_*.swift` (예: `Test_UppercaseTrigger.swift`, `Test_RegressionTable.swift`)
-   **목적**: 모킹(Mocking) 및 샌드박스 환경을 사용하여 코어 로직 수정 사항 및 회귀(Regression) 오류를 검증합니다.
-   **제외 대상**: 폴더 기반 마크다운 테스트 (`Tests/FolderTest/`).

## 구현 상세 (Implementation Details)

스크립트는 각 테스트 파일을 필요한 의존성(Mocks, Data Managers)과 함께 개별적으로 컴파일하고 실행합니다. 실행 결과로 `✅ PASS` 또는 `❌ FAIL`과 함께 로그가 출력됩니다.
