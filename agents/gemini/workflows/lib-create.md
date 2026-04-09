---
name: lib-create
description: "기능 추가 전 기본 라이브러리를 생성하고 테스트하는 샌드박스 공간(lib) 생성 절차"
---

# `lib/` 모듈 생성 워크플로우

새로운 기능을 앱에 즉각 반영하기 전에, `lib/` 폴더 내에 실험 및 검증용 샌드박스를 구성하는 워크플로우입니다.

## 1. 폴더 생성 (Create Directory)
`lib/` 하위에 적절한 이름의 폴더를 생성합니다. (예: `lib/import`)

## 2. README.md 작성 (Documentation)
생성된 폴더 내에 `README.md`를 작성하여 목적 및 적용 대상 파일(fSnippet 내부 경로)을 명시합니다.

```bash
echo "# lib/[모듈명]" > lib/[모듈명]/README.md
echo "목적 및 적용 대상: \`fSnippet/Managers/...\`" >> lib/[모듈명]/README.md
```

## 3. 리소스 및 테스트 데이터 포함 (Include Test Data)
테스트를 위해 필요한 경우 설정 파일, 더미 데이터, 혹은 YAML 파일 등을 폴더 내에 함께 구성합니다.

## 4. 코드 작성 및 검증 (Code & Run Trial)
독립 실행 가능한 형태(예: `swift [스크립트명].swift`)로 코드를 작성한 후, 자체 단위 테스트를 수행합니다.

## 5. 완료 및 공유 (Commit)
샌드박스 설정 및 초기 코드가 완료되면 형상을 관리하고 추후 `/lib-apply` 할 수 있게 준비합니다.
