---
name: fSnippetCli
description: Non-sandbox helper for fSnippet — key monitoring, text replacement, REST API engine
date: 2026-04-07
---

# Overview

fSnippetCli is the **background engine** for the [fSnippet](https://github.com/Finfra/fSnippet_public) App Store app. It runs core features requiring Accessibility API (CGEventTap, key simulation) in a non-sandbox environment, enabling fSnippet's App Store distribution.

```
fSnippet (Sandbox, App Store)         fSnippetCli (Non-Sandbox, Helper)
├── Settings GUI                      ├── CGEventTap Key Monitoring
├── Snippet Editor           REST     ├── Text Auto-Replacement Engine
└── RESTClient ──────────────────►    ├── Snippet Popup / Clipboard History
    (localhost:3015)                  ├── REST API Server (port 3015)
                                      └── Global Shortcuts
```

# Installation

## Homebrew (Recommended)

```bash
brew tap finfra/tap
brew install finfra/tap/fsnippetcli

# Auto-start on login
brew services start fsnippetcli
```

## Homebrew Service Management

```bash
brew services start fsnippetcli     # Start (auto-start on login)
brew services stop fsnippetcli      # Stop
brew services restart fsnippetcli   # Restart
brew services info fsnippetcli      # Status
```

## Build from Source

```bash
git clone https://github.com/Finfra/fSnippet_public.git
cd fSnippet_public/cli
xcodebuild -scheme fSnippetCli -configuration Release build
```

# Accessibility Permission

fSnippetCli requires **Accessibility permission** for keyboard input monitoring and text replacement.

1. **System Settings** > Privacy & Security > Accessibility
2. Enable the `fSnippetCli.app` entry

# App Properties

| Property          | Value                       |
| :---------------- | :-------------------------- |
| Bundle ID         | `com.finfra.fSnippetCli`    |
| App Type          | macOS Agent (LSUIElement)   |
| Dock Visibility   | Hidden                      |
| UI                | Menu bar icon only          |
| Sandbox           | Disabled                    |
| Deployment Target | macOS 14.0                  |
| REST Port         | 3015 (default)              |

# Directory Structure

```
cli/
├── fSnippetCli.xcodeproj
├── Formula/
│   └── fsnippetcli.rb        ← Homebrew Formula
├── project.yml               ← XcodeGen spec
└── fSnippetCli/              ← Source root
    ├── fSnippetCliApp.swift   ← Entry point (MenuBarExtra)
    ├── MenuBarView.swift      ← Menu bar UI
    ├── Info.plist
    ├── fSnippetCli.entitlements
    ├── Core/                  ← Key event engine
    │   ├── CGEventTapManager.swift
    │   ├── KeyEventMonitor.swift
    │   ├── KeyEventProcessor.swift
    │   ├── AbbreviationMatcher.swift
    │   ├── TextReplacer.swift
    │   ├── PopupController.swift
    │   └── ...
    ├── Data/                  ← Data/file management
    │   ├── SnippetFileManager.swift
    │   ├── RuleManager.swift
    │   ├── ClipboardDB.swift
    │   └── ...
    ├── Managers/              ← Business logic
    │   ├── ShortcutMgr.swift
    │   ├── ClipboardManager.swift
    │   ├── APIServer.swift
    │   └── ...
    ├── UI/                    ← Popup/history windows
    │   ├── UnifiedSnippetPopupView.swift
    │   └── History/
    ├── Models/
    ├── Protocols/
    ├── Utils/
    └── Views/
```

# REST API (v1)

fSnippetCli includes a built-in REST API server for communication with the fSnippet GUI and external tools (MCP servers, Agent skills).

* **API Version**: v1
* **Service Root**: `/api/v1/`
* **OpenAPI Spec**: [`api/openapi.yaml`](../api/openapi.yaml)

## Endpoints

| Method | Path                                | Description                  |
| :----- | :---------------------------------- | :--------------------------- |
| GET    | `/`                                 | Health check                 |
| GET    | `/api/v1/snippets`                 | List all snippets            |
| GET    | `/api/v1/snippets/search?q=`       | Search snippets              |
| GET    | `/api/v1/snippets/by-abbreviation/` | Get snippet by abbreviation  |
| GET    | `/api/v1/snippets/{id}`            | Get snippet detail           |
| POST   | `/api/v1/snippets/expand`          | Expand abbreviation to text  |
| GET    | `/api/v1/clipboard/history`        | Clipboard history            |
| GET    | `/api/v1/clipboard/history/{id}`   | Clipboard item detail        |
| GET    | `/api/v1/clipboard/search?q=`     | Search clipboard             |
| GET    | `/api/v1/folders`                  | List folders                 |
| GET    | `/api/v1/folders/{name}`           | Folder detail with snippets  |
| GET    | `/api/v1/stats/top`               | Top N usage statistics       |
| GET    | `/api/v1/stats/history`           | Usage history                |
| GET    | `/api/v1/triggers`                | Trigger key info             |
| GET    | `/api/v1/cli/status`              | CLI helper status            |
| GET    | `/api/v1/cli/version`             | CLI helper version           |
| POST   | `/api/v1/cli/quit`                | Quit CLI (X-Confirm required)|
| POST   | `/api/v1/import/alfred`           | Import Alfred snippets       |

## Quick Test

```bash
# Health check
curl http://localhost:3015/

# Search snippets
curl "http://localhost:3015/api/v1/snippets/search?q=docker&limit=5"

# CLI version
curl http://localhost:3015/api/v1/cli/version
```

# Menu Bar Features

* Display active snippet count / last expansion time
* Toggle monitoring pause/resume
* Open log folder (`~/Documents/finfra/fSnippetData/logs/`)
* Quit (`⌘Q`)

# Data Paths

Shares the same data directory as fSnippet GUI:

| Item           | Path                                          |
| :------------- | :-------------------------------------------- |
| Snippet files  | `~/Documents/finfra/fSnippetData/snippets/`   |
| Clipboard DB   | `~/Documents/finfra/fSnippetData/clipboard.sqlite` |
| Config file    | `~/Documents/finfra/fSnippetData/config.yaml`  |
| Log            | `~/Documents/finfra/fSnippetData/logs/flog.log` |

# Requirements

* macOS 14.0+
* Xcode 15.0+ (for building from source)
* Accessibility permission (required)

# License

MIT
