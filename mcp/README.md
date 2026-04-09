---
title: fSnippet MCP Server
description: MCP server that exposes the fSnippet REST API as tools
date: 2026-03-30
---

An [MCP (Model Context Protocol)](https://modelcontextprotocol.io/) server that exposes the fSnippet REST API as tools.
Search snippets, expand abbreviations, browse clipboard history, and view usage statistics directly from AI agents such as Claude Code and Claude Desktop.

## Prerequisites

The fSnippet macOS app must be running with the REST API enabled:

1. Launch **fSnippet.app**
2. Open **Settings > Advanced**
3. Enable **REST API**

Default server address: `http://localhost:3015`

---

## Installation

### Option 1: Global Install (Recommended)

```bash
npm install -g fsnippet-mcp
```

### Option 2: npx (No Installation Required)

Run directly via `npx` in your MCP configuration.

### Option 3: From Source

```bash
git clone https://github.com/finfra/fSnippet_public.git
cd fSnippet_public/mcp
npm install
```

---

## Configuration

### Claude Code

Add to `~/.claude/settings.json` or project `.claude/settings.json`:

```json
{
  "mcpServers": {
    "fsnippet": {
      "command": "npx",
      "args": ["-y", "fsnippet-mcp"]
    }
  }
}
```

If running from source:

```json
{
  "mcpServers": {
    "fsnippet": {
      "command": "node",
      "args": [
        "{PROJECT_ROOT}/mcp/index.js"
      ]
    }
  }
}
```

### Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "fsnippet": {
      "command": "npx",
      "args": ["-y", "fsnippet-mcp"]
    }
  }
}
```

If running from source:

```json
{
  "mcpServers": {
    "fsnippet": {
      "command": "node",
      "args": [
        "{PROJECT_ROOT}/mcp/index.js"
      ]
    }
  }
}
```

### Custom Server Address

To change the server address, add `--server=<url>` to the args:

```json
{
  "mcpServers": {
    "fsnippet": {
      "command": "npx",
      "args": ["-y", "fsnippet-mcp", "--server=http://192.168.0.10:3015"]
    }
  }
}
```

### After Global Install

```json
{
  "mcpServers": {
    "fsnippet": {
      "command": "fsnippet-mcp"
    }
  }
}
```

---

## Tools

### 1. `health_check`

Check the fSnippet server status including version, uptime, and counts.

**Parameters**: None

**Response example**:
```json
{
  "status": "ok",
  "app": "fSnippet",
  "version": "2.1.0",
  "port": 3015,
  "snippet_count": 1937,
  "clipboard_count": 245
}
```

---

### 2. `search_snippets`

Search snippets by keyword across abbreviations, folder names, tags, and descriptions.

**Parameters**:

| Name     | Type   | Required | Default | Description              |
| -------- | ------ | -------- | ------- | ------------------------ |
| `query`  | string | Yes      | -       | Search keyword           |
| `limit`  | number | No       | 20      | Max results (up to 100)  |
| `folder` | string | No       | -       | Filter by folder name    |
| `offset` | number | No       | -       | Result offset (paging)   |

**Usage example** (ask Claude):
```
Search for snippets related to "docker"
```

---

### 3. `get_snippet`

Retrieve snippet details by abbreviation or ID. Returns full content, placeholders, and metadata.

**Parameters**:

| Name           | Type   | Required | Description                        |
| -------------- | ------ | -------- | ---------------------------------- |
| `abbreviation` | string | No       | Snippet abbreviation (e.g. `bb{right_command}`) |
| `id`           | string | No       | Snippet ID (e.g. `AWS/ec2===EC2.txt`) |

One of `abbreviation` or `id` must be provided.

---

### 4. `expand_snippet`

Expand an abbreviation to its full text. Supports placeholder value substitution.

**Parameters**:

| Name                 | Type   | Required | Description                          |
| -------------------- | ------ | -------- | ------------------------------------ |
| `abbreviation`       | string | Yes      | Abbreviation to expand               |
| `placeholder_values` | object | No       | Key-value map for placeholder values |

**Usage example** (ask Claude):
```
Expand the snippet "bb{right_command}"
```

---

### 5. `clipboard_history`

Retrieve clipboard history with optional filtering.

**Parameters**:

| Name     | Type    | Required | Default | Description                        |
| -------- | ------- | -------- | ------- | ---------------------------------- |
| `limit`  | number  | No       | 50      | Max results (up to 200)            |
| `kind`   | string  | No       | -       | Filter: `plain_text`, `image`, `file_list` |
| `app`    | string  | No       | -       | Filter by source app bundle ID     |
| `pinned` | boolean | No       | -       | Filter pinned items only           |
| `offset` | number  | No       | -       | Result offset (paging)             |

---

### 6. `clipboard_search`

Search text within clipboard history.

**Parameters**:

| Name     | Type   | Required | Default | Description            |
| -------- | ------ | -------- | ------- | ---------------------- |
| `query`  | string | Yes      | -       | Search keyword         |
| `limit`  | number | No       | 50      | Max results            |
| `offset` | number | No       | -       | Result offset (paging) |

---

### 7. `list_folders`

List all snippet folders with rule information. Optionally retrieve a specific folder's snippets.

**Parameters**:

| Name     | Type   | Required | Description                              |
| -------- | ------ | -------- | ---------------------------------------- |
| `name`   | string | No       | Folder name to get detail with snippets  |
| `limit`  | number | No       | Max snippets (when folder specified)     |
| `offset` | number | No       | Snippet offset (when folder specified)   |

---

### 8. `get_stats`

Retrieve snippet usage statistics.

**Parameters**:

| Name     | Type   | Required | Default | Description                              |
| -------- | ------ | -------- | ------- | ---------------------------------------- |
| `type`   | string | No       | `top`   | `top` (most used) or `history` (log)     |
| `limit`  | number | No       | 10      | Number of results                        |
| `from`   | string | No       | -       | Start date ISO 8601 (history only)       |
| `to`     | string | No       | -       | End date ISO 8601 (history only)         |
| `offset` | number | No       | -       | Result offset (history only, paging)     |

---

### 9. `get_triggers`

Retrieve active trigger key information including default and active trigger keys.

**Parameters**: None

---

## Debugging

### Test with MCP Inspector

```bash
npx @modelcontextprotocol/inspector npx fsnippet-mcp
```

Opens the Inspector UI in your browser to test each tool interactively.

### Verify Server Connection

```bash
# Check if the fSnippet REST API server is running
curl http://localhost:3015/
```

---

## Publishing to npm

```bash
cd mcp
npm publish
```

---

## Architecture

```
Claude Code / Claude Desktop
    |
    | MCP (stdio)
    v
fsnippet-mcp (this server)
    |
    | HTTP (REST API)
    v
fSnippet.app (localhost:3015)
    └── macOS Native App (Swift/SwiftUI)
```

---

## License

MIT
