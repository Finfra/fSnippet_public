---
title: fSnippet Claude Code Plugin
description: fSnippet Claude Code plugin installation guide
date: 2026-03-26
---

> **This plugin has been moved to [f-claude-plugins](https://github.com/Finfra/f-claude-plugins).**

# New Location

The fSnippet Claude Code plugin is now maintained in the unified plugin repository:

- **Repository**: [Finfra/f-claude-plugins](https://github.com/Finfra/f-claude-plugins)
- **Path**: `fSnippet/`

# Installation

```
/plugin marketplace add Finfra/f-claude-plugins
/plugin install fsnippet@f-claude-plugins
```

# Manual Install

```bash
git clone https://github.com/Finfra/f-claude-plugins.git
cp -r f-claude-plugins/fSnippet/plugin.json .claude-plugin/plugin.json
cp -r f-claude-plugins/fSnippet/skills .claude/skills
```
