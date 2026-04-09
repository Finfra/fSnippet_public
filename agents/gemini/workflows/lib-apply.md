---
name: lib-apply
description: "lib 폴더에서 검증된 라이브러리/코드를 앱 실제 모듈 파일에 적용/업데이트"
---

# `lib` 적용 (Library Application) 워크플로우

`lib/` 폴더 내에서 실험 후 안전성이 검증된 코드를 `fSnippet` 앱 내부의 메인 모듈에 동기화·반영하는 표준 프로세스입니다.

## 1. 대상 파일 식별 (Identify Target)
통합할 원본(Source - `lib/` 내부) 파일과 반영할 타겟(Target - `fSnippet/` 내부) 파일을 명확히 매핑합니다. (예: `lib/import/alfred/import_snippets.swift` -> `fSnippet/Managers/AlfredImporter.swift` 또는 `AlfredLogic.swift`)

## 2. 코드 이식 (Transplant Code)
독립적인 스크립트 기반 코드를 애플리케이션 프레임워크와 아키텍처(클래스/메서드 구조)에 맞춰 이식합니다.
- 공통 로직 추출
- UI 종속 로직과 모델 로직의 분리 검증
- **[Deep Check (필수)]**: 단일 함수뿐만 아니라, 해당 함수가 연쇄적으로 호출하는 하위 함수, 참조하는 전역 상수(`SPECIAL_CHAR_MAPPINGS`, `getLiteralCandidates` 등)가 원본(`lib`)과 타겟(`fSnippet`) 간에 완벽히 동일한지 반드시 대조(Diff)합니다. 미세한 누락이 버그의 원인이 될 수 있습니다.
## 3. 의존성 및 Lint 검사 (Dependency Check)
이식된 코드에서 누락된 변수나 의존성 모듈이 있는지 크로스체크합니다.

## 4. 앱 빌드 검증 (Build Verification)
수정한 타겟 파일에 대해 올바른 컴파일이 수행되는지 검증합니다.

```bash
// turbo
xcodebuild -workspace fSnippet.xcworkspace -scheme fSnippet -configuration Debug clean build
```
*(참고: 에러 발생 시 `/build-doctor` 스킬을 통한 해결을 병행할 수 있습니다.)*

## 5. 반영 완료 보고 (Finalize)
적용 완료된 사항을 기록하고 `tasks.md` 등을 업데이트합니다.
