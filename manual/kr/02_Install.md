---
title: fSnippetCli 설치
description: fSnippetCli 설치 · 손쉬운 사용 권한 · 서비스 관리 · REST API 확인 (한국어)
date: 2026.10.09
---
# 설치 및 권한 설정

## 1. 시스템 요구사항

| 항목  | 요구                                 |
| :---- | :----------------------------------- |
| macOS | 14.0 이상                            |
| 설치  | Homebrew                             |
| 권한  | 손쉬운 사용(Accessibility) 권한 필수 |
| 빌드  | Xcode 15.0 이상 (소스 빌드 시만)     |

## 2. Homebrew 로 설치 (권장)

> **설치 전 약관 고지.** 소스 코드는 Apache-2.0 이라 직접 빌드해 쓰면 제한이 없습니다. 아래 명령으로 설치하는 **공식 배포본**은 개인 · 교육 · 비영리 · 오픈소스 프로젝트는 무제한, 그 밖의 조직은 **동시 250 카피**까지 무료입니다. 그 이상이거나 재판매 · 번들 · 호스팅 용도라면 [상업 라이선스](../../COMMERCIAL.md)가 필요하며, 공식 배포본을 설치하면 [공식 배포본 약관](../../DISTRIBUTION-TERMS_ko.md)에 동의한 것으로 봅니다.

```bash
brew tap finfra/tap
brew install finfra/tap/fsnippet-cli
brew services start fsnippet-cli     # 시작 + 로그인 시 자동 시작
```

앱은 `$(brew --prefix)/opt/fsnippet-cli/fSnippetCli.app`(Apple Silicon 은 `/opt/homebrew/opt/fsnippet-cli/fSnippetCli.app`)에 설치되고, 실행되면 메뉴바에 아이콘이 나타납니다. Dock 에는 나타나지 않습니다.

| 작업     | 명령                                                              |
| :------- | :---------------------------------------------------------------- |
| 상태     | `brew services info fsnippet-cli`                                 |
| 중지     | `brew services stop fsnippet-cli`                                 |
| 재시작   | `brew services restart fsnippet-cli`                              |
| 업데이트 | `brew upgrade fsnippet-cli`                                       |
| 삭제     | `brew services stop fsnippet-cli` → `brew uninstall fsnippet-cli` |
| tap 제거 | `brew untap finfra/tap` (선택)                                    |

* 삭제해도 `~/Documents/finfra/fSnippetData/` 의 스니펫 · 설정 · 클립보드 히스토리는 남습니다. 완전히 지우려면 이 폴더를 직접 삭제하세요
* 서비스 로그는 `$(brew --prefix)/var/log/fsnippet-cli.log` · `fsnippet-cli.err.log` 에 쌓이고, 엔진 로그는 데이터 폴더의 `logs/flog_cliApp.log` 에 있습니다

## 3. 소스에서 빌드

```bash
git clone https://github.com/Finfra/fSnippet_public.git
cd fSnippet_public/cli
xcodebuild -scheme fSnippetCli -configuration Release build
```

결과물: `~/Library/Developer/Xcode/DerivedData/fSnippetCli-*/Build/Products/Release/fSnippetCli.app`

소스 빌드에도 fSnippet 아이콘이 들어갑니다. 아이콘은 Apache 라이선스 대상이 아닌 Finfra 상표이므로, 아이콘이 든 빌드를 재배포할 때는 [TRADEMARK.md](../../TRADEMARK.md) 를 따릅니다 — 상세: [cli/README.md](../../cli/README.md).

## 4. 손쉬운 사용 권한

키 입력을 감시하고 텍스트를 바꿔 넣으려면 **fSnippetCli** 에 손쉬운 사용 권한이 있어야 합니다.

1. **시스템 설정** › **개인정보 보호 및 보안** › **손쉬운 사용**
2. **fSnippetCli** 를 켭니다 (없으면 `+` 로 `/opt/homebrew/opt/fsnippet-cli/fSnippetCli.app` 추가)
3. 확인: `curl -s http://localhost:3015/api/v2/settings/general/permissions` → `"accessibility" : true`

| 증상                               | 해결                                                         |
| :--------------------------------- | :----------------------------------------------------------- |
| 목록에 켜져 있는데 확장이 안 됨    | 끄고 다시 켜거나, `-` 로 지운 뒤 다시 추가하고 서비스 재시작 |
| 소스 빌드 후 권한이 풀림           | 빌드마다 서명이 달라져 다시 등록해야 함                      |
| 메뉴는 열리는데 약어가 바뀌지 않음 | 권한이 꺼진 상태 — 위 1~2 를 다시 하고 fSnippetCli 재시작    |

## 5. REST API 확인

REST 서버는 **기본으로 켜져 있습니다**(포트 3015, `127.0.0.1` 만 허용).

```bash
curl -s http://localhost:3015/api/v2/status
```

`"status":"ok"` 가 나오면 정상입니다. 서버 끄기 · 포트 · 외부 접속 허용은 `_config.yml` 에서 바꿉니다 — [메뉴바 사용법 › 설정 파일](06_MenuBar_Usage.md#설정-파일-_configyml). v1(`/api/v1/*`)은 폐기되어 `410 Gone` 을 돌려줍니다.

## 6. (선택) GUI 래퍼 fSnippet

설정 창 · 스니펫 편집기를 GUI 로 쓰려면 App Store 앱 **fSnippet** 을 추가로 설치합니다. fSnippet 은 이 fSnippetCli 를 통해 동작합니다 — [fSnippet 제품 페이지](https://finfra.kr/product/fSnippet/kr/index.html).

## 다음 단계

* [빠른 시작](03_QuickStart.md)
* [메뉴바 사용법](06_MenuBar_Usage.md)
