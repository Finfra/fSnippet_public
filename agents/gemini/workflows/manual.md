---
name: manual
description: "매뉴얼 빌드 및 미리보기 (Pandoc)"
---

# Manual Workflow

`/manual` 명령어를 사용하여 매뉴얼을 빌드하고 미리봅니다.

## 1. 매뉴얼 빌드 (Build)
Pandoc을 사용하여 Markdown 매뉴얼을 HTML로 변환합니다.

```bash
mkdir -p build/manual
pandoc $(fd .md _doc_work/Manual | sort) -s -o build/manual/index.html --toc --css manual.css
```

## 2. 미리보기 (Preview)
빌드된 매뉴얼을 기본 브라우저로 엽니다.

```bash
open build/manual/index.html
```

## 3. 앱 통합 리소스 복사 (Copy)
(개발용) 빌드된 매뉴얼을 앱 리소스 폴더로 복사하려면 다음을 실행합니다.
(Xcode 빌드 시에는 Run Script가 자동으로 수행하므로 수동 실행 불필요)
