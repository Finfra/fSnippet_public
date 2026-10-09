---
title: fSnippetCli REST API Usage
description: fSnippetCli REST API v2 — access, response format, examples by endpoint group, security
date: 2026.10.09
---
# REST API Usage

fSnippetCli serves a REST API at `http://localhost:3015/api/v2`. curl, shell scripts, automation tools and AI tools (Skill, MCP) all use it, and the GUI wrapper fSnippet saves its settings through it too.

* Canonical spec: [openapi_v2.yaml](../../api/openapi_v2.yaml) — see it for every request and response field
* v1 (`/api/v1/*`) is retired and returns `410 Gone`. Use v2 only

## Basics

| Item           | Value                                             |
| :------------- | :------------------------------------------------ |
| Address        | `http://localhost:3015/api/v2`                    |
| Default state  | On (`api_enabled: true`)                          |
| Allowed access | `127.0.0.1/32` only (`api_allow_external: false`) |
| Format         | JSON (`Content-Type: application/json`)           |
| Authentication | None — restricted only by address range (CIDR)    |

Response format:

```json
{ "ok": true, "data": { ... }, "meta": { ... } }
{ "ok": false, "error": { "code": "not_found", "message": "..." } }
```

In list responses, `meta` holds the number of items returned (`count`), the total (`total`) and processing time (`durationMs`).

## Status

```bash
curl -s http://localhost:3015/api/v2/status
# {"ok":true,"data":{"app":"fSnippetCli","status":"ok", ...}}
```

## Snippets

| Method · path                            | Description                                                                               |
| :--------------------------------------- | :---------------------------------------------------------------------------------------- |
| `GET /snippets`                          | List (`folder`, `limit` default 50 · max 200, `offset`)                                   |
| `GET /snippets/search`                   | Search (`q` required, `folder`, `limit` default 20, `offset`)                             |
| `GET /snippets/by-abbreviation/{abbrev}` | Find by abbreviation — the full abbreviation including the trigger notation (URL-encoded) |
| `GET /snippets/{id}`                     | Get one — `id` is `folder/filename` (URL-encoded)                                         |
| `POST /snippets`                         | Create `{folder, keyword, name, content}` → `keyword===name.txt`                          |
| `DELETE /snippets/{id}`                  | Delete                                                                                    |
| `POST /snippets/expand`                  | Get only the expanded text `{abbreviation, placeholder_values}` (no keystrokes)           |

```bash
# Search
curl -s "http://localhost:3015/api/v2/snippets/search?q=docker&limit=5"

# Find by abbreviation ({right_command} is %7Bright_command%7D)
curl -s "http://localhost:3015/api/v2/snippets/by-abbreviation/drocv2%7Bright_command%7D"

# Create (404 if the folder doesn't exist, 409 if the file already exists)
curl -s -X POST http://localhost:3015/api/v2/snippets \
  -H "Content-Type: application/json" \
  -d '{"folder":"Docker","keyword":"dps","name":"docker ps","content":"docker ps -a"}'

# Expand (passing placeholder values)
curl -s -X POST http://localhost:3015/api/v2/snippets/expand \
  -H "Content-Type: application/json" \
  -d '{"abbreviation":"awsec2{right_command}","placeholder_values":{"clipboard":"i-0123"}}'
```

## Folders

| Method · path            | Description                                 |
| :----------------------- | :------------------------------------------ |
| `GET /folders`           | List folders (`?icons=true` includes icons) |
| `POST /folders`          | Create `{name}`                             |
| `GET /folders/{name}`    | Folder details and its snippets             |
| `DELETE /folders/{name}` | Delete — empty folders only                 |

## Clipboard History

| Method · path                 | Description                                                                        |
| :---------------------------- | :--------------------------------------------------------------------------------- |
| `GET /clipboard/history`      | List (`limit`, `offset`, `kind`=`plain_text`·`image`·`file_list`, `app`, `pinned`) |
| `GET /clipboard/history/{id}` | One item                                                                           |
| `GET /clipboard/search`       | Search (`q` required)                                                              |

## Stats and Triggers

| Method · path        | Description                                                    |
| :------------------- | :------------------------------------------------------------- |
| `GET /stats/top`     | Most-used snippets                                             |
| `GET /stats/history` | Usage history (`from`, `to`)                                   |
| `GET /triggers`      | Default trigger key (`default`) and triggers in use (`active`) |

## Engine Management

| Method · path                          | Description                                                                                          |
| :------------------------------------- | :--------------------------------------------------------------------------------------------------- |
| `POST /reload`                         | Reload snippets and rules                                                                            |
| `POST /import/alfred`                  | Alfred import `{db_path}` (omit it to open a file picker)                                            |
| `GET /cli/status` · `GET /cli/version` | Engine status · version                                                                              |
| `POST /cli/pause` · `POST /cli/resume` | Pause · resume the REST API — other requests get `503` while paused; snippet expansion keeps working |
| `POST /cli/quit`                       | Quit the engine — requires the header `X-Confirm: true`                                              |

```bash
curl -s -X POST http://localhost:3015/api/v2/reload
curl -s -X POST http://localhost:3015/api/v2/cli/quit -H "X-Confirm: true"
```

## Settings (`/settings/*`)

Almost every item in `_config.yml` can be read and changed. Changes apply immediately and are saved to the file.

| Path                                                                       | Contents                                                                       |
| :------------------------------------------------------------------------- | :----------------------------------------------------------------------------- |
| `/settings/general` · `language` · `appearance` · `paths` · `logging`      | General settings                                                               |
| `/settings/general/trigger-key` · `trigger-bias` · `quick-select-modifier` | Trigger key · correction · popup quick-select modifier                         |
| `/settings/general/permissions`                                            | Accessibility permission status (read-only)                                    |
| `/settings/popup` · `/settings/behavior`                                   | Popup · app behavior (launch at login, menu bar icon, etc.)                    |
| `/settings/shortcuts` · `/settings/shortcuts/{name}`                       | Global hotkeys                                                                 |
| `/settings/snippet-folders/{folder}`                                       | Per-folder prefix and suffix (`PATCH {prefix, suffix}`)                        |
| `/settings/excluded-files/...`                                             | Excluded files                                                                 |
| `/settings/history` · `/settings/history/clear`                            | Clipboard history settings · clear                                             |
| `/settings/advanced/api`                                                   | REST server (`enabled`, `port`, `allowExternal`, `allowedCidr`)                |
| `/settings/advanced/alfred-import`                                         | Alfred import settings · run (`/run`)                                          |
| `/settings/snapshot`                                                       | Export (`GET`) · import (`PUT`) all settings                                   |
| `/settings/actions/reset-settings` etc.                                    | Resets — `reset-settings` · `reset-snippets` · `clear-stats` · `factory-reset` |

```bash
# Check the trigger key
curl -s http://localhost:3015/api/v2/settings/general/trigger-key

# Keep clipboard text for 30 days
curl -s -X PATCH http://localhost:3015/api/v2/settings/history \
  -H "Content-Type: application/json" -d '{"historyRetentionDaysPlainText":30}'
```

Request body field names may differ from the `_config.yml` keys (e.g. `api_allow_external` ↔ `allowExternal`). Check the schemas in [openapi_v2.yaml](../../api/openapi_v2.yaml) for the exact names.

`/paidapp/*`, `/changes`, `/key-capture/*` and `/log/paidapp` are used by fSnippet (the GUI wrapper) to talk to the engine.

## Security

* By default, only this Mac (`127.0.0.1`) can connect. There is no authentication, so open external access only when you need it
* To allow external access, send `PATCH /settings/advanced/api` with both `allowExternal: true` and `allowedCidr` (e.g. `192.168.0.0/24`). With `allowExternal: false`, the CIDR is forced to `127.0.0.1/32`
* Changing the port or turning the server off and on rebinds the server. After changing the port, also update the command line `-p` and the MCP `FSNIPPET_SERVER`

## Next Steps

* [Claude Code Skill](08_Skill_Usage.md)
* [MCP Server](09_MCP_Usage.md)
