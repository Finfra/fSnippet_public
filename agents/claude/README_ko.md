---
title: fSnippet Claude Code Plugin
description: fSnippet Claude Code 플러그인 설치 가이드
date: 2026-03-26
---

# 새 위치

fSnippet Claude Code 플러그인은 통합 플러그인 레포지토리에서 관리됩니다:

- **레포지토리**: [Finfra/f-claude-plugins](https://github.com/Finfra/f-claude-plugins)
- **경로**: `fSnippet/`

# 설치 방법

```
/plugin marketplace add Finfra/f-claude-plugins
/plugin install fsnippet@f-claude-plugins
```

# 수동 설치

```bash
git clone https://github.com/Finfra/f-claude-plugins.git
cp -r f-claude-plugins/fSnippet/plugin.json .claude-plugin/plugin.json
cp -r f-claude-plugins/fSnippet/skills .claude/skills
```
