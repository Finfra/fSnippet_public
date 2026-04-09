---
title: fSnippet Pro
description: macOS Menu Bar Snippet & Clipboard Manager
date: 2026-03-26
---

[![ko](https://img.shields.io/badge/lang-ko-red.svg)](./README_kr.md)

<img src="./manual/app-icon.png" width="28" alt="fSnippet Icon"> [![Product Page](https://img.shields.io/badge/Product%20Page-finfra.kr-blue)](https://finfra.kr/product/fSnippet/en/index.html)

> **Expand any text, Powerful snippet tool.**

macOS Menu Bar Snippet & Clipboard Manager. Manage text snippets, track clipboard history, and expand frequently used text with shortcuts.

## Editions

| Edition                | Price           | Interface | Install                                                   |
| :--------------------- | :-------------- | :-------- | :-------------------------------------------------------- |
| **fSnippet Pro** (GUI) | Paid            | GUI       | App Store (Coming Soon)                                   |
| **fSnippetCli** (CLI)  | Free / OSS      | CLI       | `brew install finfra/tap/fsnippetcli` ([Source](./cli/)) |

* **fSnippet Pro** - Full-featured GUI app with intuitive settings, visual snippet management, and clipboard history viewer. Available on the Mac App Store (coming soon).
* **fSnippetCli** - Fully open-source CLI version. All source code is in the [`cli/`](./cli/) directory. Installable via Homebrew.

## About This Repository

This repository serves two purposes:

1. **User support & documentation** for fSnippet Pro (GUI, paid)
2. **Open-source repository** for fSnippetCli (CLI, free)

## Features

* **Instant Access** - Quick access from the menu bar
* **Clipboard History** - Track all copied text, images, and links
* **Fast Snippet Expansion** - Expand frequently used text with shortcuts
* **Fine-grained Control** - Exclude apps, customize shortcuts
* **Easy Management** - Intuitive UI for snippet organization
* **Text & Image Support** - Store both text and image snippets
* **AI Agent Integration** - Automate with Claude, Gemini, and MCP

## AI Agent Integration

Automate and extend fSnippet with AI agents. All integration methods use the built-in REST API.

| Platform   | Integration Method            | Details                                     |
| :--------- | :---------------------------- | :------------------------------------------ |
| **Claude** | Marketplace Plugin (Skill)    | [Install via Claude Code](./agents/claude/) |
| **Gemini** | Workflow Installation         | [Install via Gemini](./agents/gemini/)      |
| **MCP**    | Model Context Protocol Server | [MCP Server Setup](./mcp/)                  |

## Requirements

* macOS 14.0 or later

## Product Page

| Language | Link                                                                       |
| :------- | :------------------------------------------------------------------------- |
| English  | [fSnippet - Product Page](http://finfra.kr/product/fSnippet/en/index.html) |
| Korean   | [fSnippet - 제품 페이지](http://finfra.kr/product/fSnippet/kr/index.html)  |

## Other Apps by Finfra

| App              | Description                                      | Link                                                                |
| :--------------- | :----------------------------------------------- | :------------------------------------------------------------------ |
| **fWarrange**    | The ultimate Mac window manager & layout restore | [Product Page](http://finfra.kr/product/fWarrange/en/index.html)    |
| **fBanner**      | Clipboard to banner image, instantly             | [Product Page](http://finfra.kr/product/fBanner/en/index.html)      |
| **fBoard**       | Your personalized screen board                   | [Product Page](http://finfra.kr/product/fBoard/en/index.html)       |
| **fQRGen**       | Clipboard to QR code, instantly                  | [Product Page](http://finfra.kr/product/fQRGen/en/index.html)       |
| **fGoogleSheet** | The fastest Google Sheets menu bar app for Mac   | [Product Page](http://finfra.kr/product/fGoogleSheet/en/index.html) |
## Documentation

| Document                              | Description                                    |
| :------------------------------------ | :--------------------------------------------- |
| [Manual](./manual/)                   | User manual (KR/EN)                            |
| [REST API](./api/)                    | REST API reference & OpenAPI spec              |
| [MCP Server](./mcp/)                  | Model Context Protocol server                  |
| [Claude Code Skill](./agents/claude/) | Claude Code plugin                             |
| [Localization](./localization/)       | Multi-language string resources (10 languages) |
## Community & Support

### Issues
* [GitHub Issues](https://github.com/Finfra/fSnippet_public/issues)

### Board (English)
| Category | Link                                                                  |
| :------- | :-------------------------------------------------------------------- |
| Notice   | [fSnippet Notice](https://finfra.kr/w1/category/fsnippet-notice/)     |
| Guide    | [fSnippet Guide](https://finfra.kr/w1/category/fsnippet-guide/)       |
| QnA      | [fSnippet QnA](https://finfra.kr/w1/category/fsnippet-qna/)           |
| Feedback | [fSnippet Feedback](https://finfra.kr/w1/category/fsnippet-feedback/) |
### Board (Korean)
| Category | Link                                                                |
| :------- | :------------------------------------------------------------------ |
| Notice   | [fSnippet 공지](https://finfra.kr/w1/category/fsnippet-notice-kr/)    |
| Guide    | [fSnippet 사용법](https://finfra.kr/w1/category/fsnippet-guide-kr/)    |
| QnA      | [fSnippet QnA](https://finfra.kr/w1/category/fsnippet-qna-kr/)      |
| Feedback | [fSnippet 피드백](https://finfra.kr/w1/category/fsnippet-feedback-kr/) |
## License

Copyright (c) finfra.kr. All rights reserved.
