---
name: register-class-emoji
description: 클래스에 고유 이모지를 등록하고 로그를 업데이트한 후, 문서를 갱신합니다.
---

# 클래스 이모지 등록 워크플로우 (Register Class Emoji Workflow)

이 워크플로우는 클래스에 고유 이모지를 할당(휴리스틱 또는 랜덤)하고, 로그 구문을 업데이트하며, 프로젝트 문서를 갱신합니다.

## 1. 이모지 등록 및 코드 업데이트 (Register Emoji & Update Code)
Python 스크립트를 실행하여 이모지를 할당하고 소스 코드를 업데이트합니다.

```bash
# 사용법: python3 .agent/skills/emoji-mapper/scripts/register_class.py [ClassName] [FilePath]
# 예시: python3 .agent/skills/emoji-mapper/scripts/register_class.py "MyManager" "fSnippet/Managers/MyManager.swift"
```
> [!IMPORTANT]
> `[ClassName]`과 `[FilePath]`를 실제 값으로 반드시 변경해야 합니다.

## 2. 문서 업데이트 (Update Documentation)
이모지가 등록되고 코드가 업데이트되면, 다이어그램에 변경 사항을 반영하기 위해 doc design 워크플로우를 실행하거나 직접 적용 스크립트를 실행합니다.

```bash
# // turbo
python3 .agent/skills/emoji-mapper/scripts/apply_emojis.py _doc_design/diagram_CLASS.mermaid
```
> [!NOTE]
> `@[/doc-design]` 워크플로우에서도 이 작업이 포함되지만, 이모지 적용 스크립트를 명시적으로 실행하면 다이어그램의 일관성을 즉시 보장할 수 있습니다.
