---
title: get-app-root
description: fSnippetCli의 appRootPath를 환경변수 또는 기본값으로 결정합니다.
date: 2026-04-07
---

# 우선순위

1. 환경변수 `fSnippetCli_config` (설정 시 최우선)
2. 기본 경로: `~/Documents/finfra/fSnippetData`

# Usage

```bash
agents/gemini/skills/get-app-root/scripts/get-app-root.sh
```

# Behavior

* 환경변수 `fSnippetCli_config`가 설정되어 있으면 해당 경로 반환
* 미설정 시 `~/Documents/finfra/fSnippetData` 반환
