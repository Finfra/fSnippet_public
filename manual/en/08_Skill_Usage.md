---
title: fSnippetCli Claude Code Skill Usage
description: Working with fSnippetCli snippets and clipboard in natural language through the Claude Code plugin (Skill)
date: 2026.10.09
---
# Claude Code Skill Usage

Install the Claude Code plugin **fsnippet** to search, expand and create snippets in natural language inside Claude Code, and to look up clipboard history and usage stats. The plugin calls the fSnippetCli [REST API](07_API_Usage.md).

## Prerequisites

* fSnippetCli must be running with the REST API on — `curl -s http://localhost:3015/api/v2/status`
* If the server is down, the plugin does not start the app for you; it tells you how to start it (`brew services start fsnippet-cli`)

## Installation

The plugin lives in `fSnippet/` of the shared plugin repository [Finfra/f-claude-plugins](https://github.com/Finfra/f-claude-plugins).

In Claude Code:

```
/plugin marketplace add Finfra/f-claude-plugins
/plugin install fsnippet@f-claude-plugins
```

Manual installation (from your project folder):

```bash
git clone https://github.com/Finfra/f-claude-plugins.git
mkdir -p .claude-plugin .claude
cp f-claude-plugins/fSnippet/plugin.json .claude-plugin/plugin.json
cp -r f-claude-plugins/fSnippet/skills .claude/skills
```

## Examples

| Input                                                          | Action                           |
| :------------------------------------------------------------- | :------------------------------- |
| `/fsnippet:fsnippet docker`                                    | Search snippets for `docker`     |
| `/fsnippet:fsnippet bb{right_command}`                         | Show the expanded text of `bb`   |
| `/fsnippet:fsnippet clipboard history`                         | Recent clipboard history         |
| `/fsnippet:fsnippet folders`                                   | List snippet folders             |
| `/fsnippet:fsnippet stats top 5`                               | Top 5 most-used snippets         |
| `/fsnippet:fsnippet create snippet in Docker`                  | Create a new snippet in `Docker` |
| `/fsnippet:fsnippet delete snippet Docker/dps===docker ps.txt` | Delete a snippet                 |

You can also just say "find snippets about ps in the Docker folder" without the slash command; when a request matches the Skill's description, Claude Code picks this Skill. You can also ask it to pause or resume the engine and to reload snippets.

## Troubleshooting

| Symptom                 | Check                                                                                                                         |
| :---------------------- | :---------------------------------------------------------------------------------------------------------------------------- |
| Cannot reach the server | `brew services info fsnippet-cli` · `curl -s http://localhost:3015/api/v2/status`                                             |
| `503` responses         | Menu bar **👻 Daemon ▸ Resume REST API** (or `POST /api/v2/cli/resume`)                                                       |
| You changed the port    | The Skill uses `http://localhost:3015`. With a different port, change the address in the installed `skills/fsnippet/SKILL.md` |

## Next Steps

* [MCP Server](09_MCP_Usage.md) — use it from Claude Desktop and other MCP clients
* [REST API Usage](07_API_Usage.md)
