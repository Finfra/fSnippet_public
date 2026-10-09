---
title: fSnippetCli 자주 묻는 질문
description: fSnippetCli FAQ — fSnippet 과의 관계, 확장이 안 될 때, 약어 · 클립보드 · REST · 데이터 · 라이선스 (한국어)
date: 2026.10.09
---
# 자주 묻는 질문 (FAQ)

## fSnippetCli 와 fSnippet

**Q. fSnippetCli 만 써도 되나요?**
네. 스니펫 확장 · 팝업 · 플레이스홀더 · 클립보드 히스토리 · REST API · 명령행 · Alfred 가져오기는 모두 fSnippetCli 의 기능입니다. 설정은 `_config.yml` · REST 로, 스니펫은 파일로 관리합니다.

**Q. fSnippet(App Store 앱)은 무엇을 더해 주나요?**
설정 창과 스니펫 편집기 같은 GUI 입니다. fSnippet 은 fSnippetCli 를 통해 동작하므로 fSnippetCli 가 함께 설치되어 있어야 합니다 — [fSnippet 제품 페이지](https://finfra.kr/product/fSnippet/kr/index.html).

**Q. «Only support the paid version» 창이 떠요.**
메뉴바 **🔧 설정 창 열기**, 스니펫 팝업의 **Tab**, 클립보드 히스토리의 텍스트 **⌘S** 처럼 fSnippet 을 여는 동작을 fSnippet 없이 실행했을 때 나타납니다. 같은 일은 `_config.yml` · REST · 스니펫 파일 편집으로 할 수 있습니다.

## 확장이 안 될 때

**Q. 약어를 쳐도 바뀌지 않아요.**
순서대로 확인합니다.

1. 서비스 실행: `brew services info fsnippet-cli` · `curl -s http://localhost:3015/api/v2/status`
2. 손쉬운 사용 권한: `curl -s http://localhost:3015/api/v2/settings/general/permissions` 의 `accessibility` 가 `true` 인지 — 아니면 [설치 › 손쉬운 사용 권한](02_Install.md#4-손쉬운-사용-권한)
3. 약어 확인: `fSnippetCli snippet search <검색어>` 로 실제 약어(`abbreviation`)를 봅니다. 폴더 접두어(`Docker` → `d`)를 빼먹는 경우가 많습니다
4. 트리거 키: 기본은 **오른쪽** ⌘ 입니다. 왼쪽 ⌘ 로는 확장되지 않습니다 — `curl -s http://localhost:3015/api/v2/triggers`

**Q. brew 로 업데이트한 뒤 확장이 멈췄어요.**
손쉬운 사용 목록에서 fSnippetCli 를 껐다 켜거나, `-` 로 지우고 다시 추가한 뒤 `brew services restart fsnippet-cli` 를 실행합니다.

**Q. 확장하면 앞 글자가 덜 지워지거나 더 지워져요.**
`_config.yml` 의 `snippet_trigger_bias`(기본 `0`, -10 ~ 10)로 지우는 글자 수를 보정합니다. 특정 폴더만 그렇다면 `_rule.yml` 의 그 폴더에 `trigger_bias` 를 줍니다 — [스니펫 사용법 › 폴더 규칙](04_Snippet_Usage.md#폴더-규칙-_ruleyml).

**Q. 새로 만든 스니펫이 안 잡혀요.**
폴더 감시로 자동 반영되지만, 안 되면 메뉴바 **👻 데몬 ▸ 스니펫 다시 불러오기** 또는 `curl -X POST http://localhost:3015/api/v2/reload` 를 실행합니다. 스니펫 파일은 `snippets/` 바로 아래 **폴더 안**에 있어야 합니다.

## 설정

**Q. `_config.yml` 을 고쳤는데 그대로예요.**
설정 파일은 앱 시작 때 읽습니다. **👻 데몬 ▸ 데몬 재시작** 으로 반영하거나, 처음부터 REST `settings/*` 로 바꾸면 바로 적용됩니다 — [메뉴바 사용법 › 설정 파일](06_MenuBar_Usage.md#설정-파일-_configyml).

**Q. 메뉴를 한국어로 보고 싶어요.**
`_config.yml` 의 `language` 를 `ko` 로 바꾸고 재시작합니다(번들 기본 `en`).

**Q. 설정을 처음 상태로 되돌리려면?**
`fSnippetCli settings reset --confirm` 또는 `POST /api/v2/settings/actions/reset-settings` 를 씁니다. 바꾸기 전에 `fSnippetCli settings snapshot export <파일>` 로 백업해 두면 `import` 로 되돌릴 수 있습니다.

## 클립보드 히스토리

**Q. 비밀번호가 기록에 남는 게 걱정돼요.**
복사 전에 **⌃⌥⌘P** 로 기록을 일시 정지하고, 이미 남은 항목은 히스토리 창에서 골라 Delete 로 지웁니다. 전체 삭제는 메뉴바 **📜 클립보드 ▸ 클립보드 히스토리 비우기** 입니다.

**Q. 기록은 얼마나 남나요?**
번들 기본값은 텍스트 90일 · 이미지 7일 · 파일 목록 30일입니다 — [클립보드 히스토리 › 설정](05_Clipboard_Usage.md#설정-_configyml).

## REST API · 보안

**Q. REST API 를 끄려면?**
`_config.yml` 에서 `api_enabled: false` 로 바꾸고 재시작합니다. 잠시만 막으려면 메뉴바 **👻 데몬 ▸ REST API 일시 정지**(요청에 `503`, 스니펫 확장은 계속 동작). 단 fSnippet · Skill · MCP 는 REST 로 동작하므로 함께 멈춥니다.

**Q. 다른 기기에서 접속해도 되나요?**
기본은 이 Mac 만 허용합니다. REST 에는 인증이 없으므로 외부 접속은 필요할 때만 `api_allow_external` 과 `api_allowed_cidr` 로 좁게 엽니다 — [REST API 사용법 › 보안](07_API_Usage.md#보안).

## 데이터 · 백업

**Q. 백업은 무엇을 하면 되나요?**
데이터 폴더 `~/Documents/finfra/fSnippetData/` 를 통째로 복사하면 스니펫 · 규칙 · 설정 · 클립보드 기록이 모두 들어갑니다. 스니펫만 관리하려면 `snippets/` 를 Git 저장소로 두어도 됩니다.

**Q. 데이터 폴더를 다른 곳에 두고 싶어요.**
환경변수 `fSnippetCli_config` 에 경로를 지정하면 그 폴더를 씁니다. Homebrew 서비스로 실행할 때 환경변수를 넘기는 방법은 (검증 필요).

**Q. Alfred 스니펫을 옮길 수 있나요?**
네. `fSnippetCli import alfred <snippets.alfdb 경로>` — [스니펫 사용법 › Alfred 가져오기](04_Snippet_Usage.md#alfred-스니펫-가져오기).

## 라이선스 · 삭제

**Q. 회사에서 써도 되나요?**
소스 코드는 Apache-2.0 입니다. Homebrew 로 설치하는 공식 배포본은 개인 · 교육 · 비영리 · 오픈소스 프로젝트는 무제한, 그 밖의 조직은 동시 250 카피까지 무료입니다. 그 이상은 [상업 라이선스](../../COMMERCIAL.md) — 조건 전문은 [공식 배포본 약관](../../DISTRIBUTION-TERMS_ko.md).

**Q. 완전히 지우려면?**
`brew services stop fsnippet-cli` → `brew uninstall fsnippet-cli` 후, 데이터까지 지우려면 `~/Documents/finfra/fSnippetData/` 를 삭제하고 손쉬운 사용 목록에서 fSnippetCli 를 뺍니다.

## 다음 단계

* [매뉴얼 목차](../README.md)
* [기능 명세](../FunctionalSpecification.md)
