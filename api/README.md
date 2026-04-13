---
title: fSnippet REST API Documentation
description: fSnippet REST API reference and usage guide
date: 2026-03-26
---

# Overview

fSnippet is a macOS text snippet expansion tool that provides a REST API through a lightweight NWListener-based HTTP server embedded in the app.
The API exposes snippet search/expansion, clipboard history, usage statistics, and trigger key information.

| Item         | Value                                                   |
| :----------- | :------------------------------------------------------ |
| Server       | macOS native app (Swift / Network.framework NWListener) |
| Default Port | 3015                                                    |
| API Enabled  | OFF by default (must be explicitly enabled in Settings) |
| Binding      | `127.0.0.1` (localhost only) by default                 |
> OpenAPI 3.0 specs:
> - v1 (read operations): [openapi_v1.yaml](./openapi_v1.yaml)
> - v2 (settings CRUD): [openapi_v2.yaml](./openapi_v2.yaml)

---

# Security

- By default, the API accepts connections on all interfaces but filters requests by CIDR (default `127.0.0.1/32`, localhost only).
- External access can be enabled via Settings > Advanced > "Allow External Access" checkbox.
- When external access is enabled, the allowed CIDR field becomes editable (e.g. `192.168.0.0/24`).
- Requests from IPs outside the configured CIDR range are rejected.

| Setting               | Default        | Notes                                                |
| :-------------------- | :------------- | :--------------------------------------------------- |
| API enabled           | **OFF**        | Must be explicitly enabled in Settings               |
| Port                  | `3015`         | Configurable in Settings                             |
| Allowed CIDR          | `127.0.0.1/32` | Localhost only                                       |
| Allow external access | **OFF**        | When unchecked, CIDR field is locked to 127.0.0.1/32 |
---

# Endpoints

# 1. Health Check

```
GET /
```

**Response (200)**:
```json
{
  "status": "ok",
  "app": "fSnippet",
  "version": "2.1.0",
  "port": 3015,
  "uptime_seconds": 3600,
  "snippet_count": 1937,
  "clipboard_count": 245
}
```

---

# 2. Search Snippets

```
GET /api/snippets/search?q={query}
```

### Parameters

| Field    | Type    | Required | Default | Description                       |
| :------- | :------ | :------- | :------ | :-------------------------------- |
| `q`      | string  | Yes      | -       | Search query                      |
| `limit`  | integer | No       | 20      | Maximum number of results (1–100) |
| `offset` | integer | No       | 0       | Pagination offset                 |
| `folder` | string  | No       | -       | Filter by folder name             |
### Response

**Success (200)**: Snippet list sorted by relevance score

**Error**:

| Status Code | Cause                | Example                                                                              |
| :---------- | :------------------- | :----------------------------------------------------------------------------------- |
| 400         | Missing search query | `{"success": false, "error": {"code": "MISSING_QUERY", "message": "Missing query"}}` |
---

# 3. Get Snippet by Abbreviation

```
GET /api/snippets/by-abbreviation/{abbrev}
```

| Field    | Type          | Required | Description                                              |
| :------- | :------------ | :------- | :------------------------------------------------------- |
| `abbrev` | string (path) | Yes      | Abbreviation (URL-encoded, e.g. `awsec2{right_command}`) |
**Success (200)**: Snippet detail (content, tags, placeholders, etc.)

**Error**: 404 – Snippet not found

---

# 4. Get Snippet Detail by ID

```
GET /api/snippets/{id}
```

| Field | Type          | Required | Description                                                |
| :---- | :------------ | :------- | :--------------------------------------------------------- |
| `id`  | string (path) | Yes      | Snippet ID (URL-encoded, e.g. `AWS%2Fec2%3D%3D%3DEC2.txt`) |
**Success (200)**: Snippet detail

**Error**: 404 – Snippet not found

---

# 5. Expand Snippet

```
POST /api/snippets/expand
Content-Type: application/json
```

### Parameters

| Field                | Type   | Required | Description                                                    |
| :------------------- | :----- | :------- | :------------------------------------------------------------- |
| `abbreviation`       | string | Yes      | Abbreviation to expand                                         |
| `placeholder_values` | object | No       | Placeholder value mapping (key: name, value: replacement text) |
### Request Example

```json
{
  "abbreviation": "awsec2{right_command}",
  "placeholder_values": {
    "clipboard": "i-0123456789abcdef0"
  }
}
```

### Response

**Success (200)**:
```json
{
  "success": true,
  "data": {
    "original_abbreviation": "awsec2{right_command}",
    "snippet_id": "AWS/ec2===EC2.txt",
    "expanded_text": "ssh ec2-user@i-0123456789abcdef0",
    "delete_count": 8,
    "placeholders_resolved": ["clipboard"]
  }
}
```

**Error**:

| Status Code | Cause                               |
| :---------- | :---------------------------------- |
| 400         | JSON parse failure                  |
| 404         | No snippet matches the abbreviation |
> This endpoint does not simulate keyboard input; it returns text data only.

---

# 6. Get Clipboard History

```
GET /api/clipboard/history
```

### Parameters

| Field    | Type    | Required | Default | Description                                                 |
| :------- | :------ | :------- | :------ | :---------------------------------------------------------- |
| `limit`  | integer | No       | 50      | Maximum number of results (1–200)                           |
| `offset` | integer | No       | 0       | Pagination offset                                           |
| `kind`   | string  | No       | -       | Filter by content kind (`plain_text`, `image`, `file_list`) |
| `app`    | string  | No       | -       | Filter by source app bundle ID (e.g. `com.apple.Safari`)    |
| `pinned` | boolean | No       | -       | Filter pinned items only                                    |
**Success (200)**: Clipboard history in reverse chronological order

---

# 7. Get Clipboard Item Detail

```
GET /api/clipboard/history/{id}
```

| Field | Type           | Required | Description       |
| :---- | :------------- | :------- | :---------------- |
| `id`  | integer (path) | Yes      | Clipboard item ID |
**Success (200)**: Full text and metadata

**Error**: 404 – Item not found

---

# 8. Search Clipboard History

```
GET /api/clipboard/search?q={query}
```

| Field    | Type    | Required | Default | Description               |
| :------- | :------ | :------- | :------ | :------------------------ |
| `q`      | string  | Yes      | -       | Search query              |
| `limit`  | integer | No       | 50      | Maximum number of results |
| `offset` | integer | No       | 0       | Pagination offset         |
**Error**: 400 – Missing search query

---

# 9. List Folders

```
GET /api/folders
```

**Success (200)**: List of snippet folders with rule information

---

# 10. Get Folder Detail with Snippets

```
GET /api/folders/{name}
```

| Field    | Type          | Required | Default | Description                |
| :------- | :------------ | :------- | :------ | :------------------------- |
| `name`   | string (path) | Yes      | -       | Folder name (URL-encoded)  |
| `limit`  | integer       | No       | 50      | Maximum number of snippets |
| `offset` | integer       | No       | 0       | Pagination offset          |
**Error**: 404 – Folder not found

---

# 11. Top N Usage Statistics

```
GET /api/stats/top
```

| Field   | Type    | Required | Default | Description                  |
| :------ | :------ | :------- | :------ | :--------------------------- |
| `limit` | integer | No       | 10      | Number of top results (1–50) |
**Success (200)**: Most frequently used snippets

---

# 12. Usage History

```
GET /api/stats/history
```

| Field    | Type    | Required | Default | Description               |
| :------- | :------ | :------- | :------ | :------------------------ |
| `limit`  | integer | No       | 100     | Maximum number of results |
| `offset` | integer | No       | 0       | Pagination offset         |
| `from`   | string  | No       | -       | Start date (ISO 8601)     |
| `to`     | string  | No       | -       | End date (ISO 8601)       |
**Success (200)**: Usage history in chronological order

---

# 13. Get Trigger Keys

```
GET /api/triggers
```

**Success (200)**:
```json
{
  "success": true,
  "data": {
    "default": {
      "symbol": "{right_command}",
      "key_code": 42,
      "description": "Option+X"
    },
    "active": [...]
  }
}
```

---

# v2 API — Settings CRUD (Advanced)

The v2 API provides comprehensive read/write access to all fSnippet settings, enabling full-featured remote configuration and automation.

## Security & Constraints

- **Write Protection**: All PATCH/PUT/POST/DELETE operations are restricted to localhost (`127.0.0.1`).
- **Confirmation Guard**: Destructive operations (reset-settings, reset-snippets, factory-reset) require a confirmation token in the request body.
- **Partial Updates**: All PATCH endpoints support partial updates — only provide the fields you want to change.

### Confirmation Guard Pattern

```json
// Request
POST /api/v2/settings/actions/factory-reset
{
  "confirm": "YES-I-KNOW"
}

// Response (403 if wrong confirm)
{
  "ok": false,
  "error": {
    "code": "confirmation_mismatch",
    "message": "Confirmation token does not match",
    "statusCode": 403
  }
}
```

## Common v2 Response Format

**Success**:
```json
{
  "ok": true,
  "data": { ... }
}
```

**Error**:
```json
{
  "ok": false,
  "error": {
    "code": "invalid_argument",
    "message": "...",
    "statusCode": 400
  }
}
```

## Example: Update Popup Settings

```bash
# PATCH /api/v2/settings/popup
curl -X PATCH http://localhost:3015/api/v2/settings/popup \
  -H "Content-Type: application/json" \
  -d '{
    "popupRows": 8,
    "searchScope": "keyword"
  }'

# Response (200)
{
  "ok": true,
  "data": {
    "searchScope": "keyword",
    "popupRows": 8,
    "popupWidth": 350,
    "previewWindowWidth": 400
  }
}
```

## Example: Add Excluded File

```bash
# POST /api/v2/settings/advanced/excluded-files/global/entries
curl -X POST http://localhost:3015/api/v2/settings/advanced/excluded-files/global/entries \
  -H "Content-Type: application/json" \
  -d '{"filename": ".DS_Store"}'

# Response (201 created) / (409 duplicate)
```

## Example: Snapshot Export & Restore

```bash
# Export settings
curl http://localhost:3015/api/v2/settings/snapshot > backup.json

# Restore (partial)
curl -X PUT http://localhost:3015/api/v2/settings/snapshot \
  -H "Content-Type: application/json" \
  -d '{
    "version": "2.0.0",
    "general": {...},
    "popup": {...}
  }'

# Response (204 no content)
```

## Example: Async Job (Alfred Import)

```bash
# Start import job (returns immediately)
curl -X POST http://localhost:3015/api/v2/settings/advanced/alfred-import/run

# Response (202 accepted)
{
  "jobId": "550e8400-e29b-41d4-a716-446655440000"
}
```

For complete endpoint reference, see [openapi_v2.yaml](./openapi_v2.yaml).

---

# Common Error Response

All errors follow a consistent format:

```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "Snippet not found"
  }
}
```

| Status Code | Code                                | Description                                                      |
| :---------- | :---------------------------------- | :--------------------------------------------------------------- |
| 400         | `MISSING_QUERY` / `INVALID_REQUEST` | Invalid request (JSON parse failure, missing required parameter) |
| 404         | `NOT_FOUND`                         | Resource not found                                               |
---

# Examples

# cURL

```bash
# Health check
curl http://localhost:3015/

# Search snippets
curl "http://localhost:3015/api/snippets/search?q=docker&limit=10"

# Get snippet by abbreviation
curl "http://localhost:3015/api/snippets/by-abbreviation/awsec2%E2%97%8A"

# Expand snippet
curl -X POST http://localhost:3015/api/snippets/expand \
  -H "Content-Type: application/json" \
  -d '{"abbreviation": "bb{right_command}"}'

# Expand with placeholder values
curl -X POST http://localhost:3015/api/snippets/expand \
  -H "Content-Type: application/json" \
  -d '{"abbreviation": "awsec2{right_command}", "placeholder_values": {"clipboard": "i-0123456789abcdef0"}}'

# Clipboard history
curl "http://localhost:3015/api/clipboard/history?limit=20"

# Search clipboard
curl "http://localhost:3015/api/clipboard/search?q=password"

# List folders
curl http://localhost:3015/api/folders

# Folder detail (AWS)
curl "http://localhost:3015/api/folders/AWS"

# Top 10 usage statistics
curl "http://localhost:3015/api/stats/top?limit=10"

# Usage history (date range)
curl "http://localhost:3015/api/stats/history?from=2026-01-01T00:00:00Z&to=2026-03-18T23:59:59Z"

# Trigger keys
curl http://localhost:3015/api/triggers
```

# Python

```python
import requests

BASE = "http://localhost:3015"

# Health check
resp = requests.get(f"{BASE}/")
print(resp.json())

# Search snippets
resp = requests.get(f"{BASE}/api/snippets/search", params={"q": "docker", "limit": 10})
for s in resp.json()["data"]:
    print(f"{s['abbreviation']} -> {s['description']}")

# Expand snippet
resp = requests.post(f"{BASE}/api/snippets/expand", json={"abbreviation": "bb{right_command}"})
print(resp.json()["data"]["expanded_text"])

# Clipboard history
resp = requests.get(f"{BASE}/api/clipboard/history", params={"limit": 5})
for item in resp.json()["data"]:
    print(f"[{item['kind']}] {item['text_preview']}")
```

---

# Testing

```bash
# Automated test (17 items)
bash api/test-api.sh

# Remote server test
bash api/test-api.sh --server=http://192.168.0.10:3015
```

Test items:
1. Health check (GET `/`)
2. Snippet search and result validation
3. Snippet search – missing query (400)
4. Snippet expansion (POST)
5. Snippet expansion – invalid JSON (400)
6. Snippet by abbreviation – not found (404)
7. Snippet by ID – not found (404)
8. Clipboard history retrieval
9. Clipboard search
10. Clipboard search – missing query (400)
11. Clipboard detail – not found (404)
12. Folder list
13. Folder detail – not found (404)
14. Top N usage statistics
15. Usage history
16. Trigger key information
17. Unknown path – 404 response
