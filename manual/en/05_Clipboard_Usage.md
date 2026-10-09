---
title: fSnippetCli Clipboard History
description: Opening the clipboard history window, keys, pausing, retention, and querying over REST
date: 2026.10.09
---
# Clipboard History

fSnippetCli records what you copy and lets you paste it again with a global hotkey. It records text, images and file lists, stored in `clipboard/clipboard.db` in the data folder (original images in `clipboard/blobs/`).

## Opening the Window

| How      | Action                                                              |
| :------- | :------------------------------------------------------------------ |
| Hotkey   | **⌘;** (bundled default · `history.viewer.hotkey` in `_config.yml`) |
| Menu bar | **📋 Show Clipboard History**                                       |
| REST     | `GET /api/v2/clipboard/history` (query without a window)            |

The window appears over the app you were working in, and the item you pick is pasted into that app.

## Keys

| Key                    | Action                                                                                            |
| :--------------------- | :------------------------------------------------------------------------------------------------ |
| Type                   | Search                                                                                            |
| ↑ · ↓                  | Move between items (hold ⇧ to extend the selection)                                               |
| Enter                  | Paste the selected item into the original app. Multiple text items are joined and pasted together |
| ⌘1 – ⌘9                | Paste the item at that position                                                                   |
| ⌘-click · ⇧-click · ⌘A | Select multiple items                                                                             |
| Delete · Backspace     | Delete the selected item (if there is a search term, deletes its characters instead)              |
| Tab                    | Edit the text preview · show image details                                                        |
| Space                  | Show image details                                                                                |
| ⌘S                     | Image: save to a file · text: register as a new snippet — **text requires fSnippet**              |
| Esc                    | Clear the search term, or close the window if it is empty                                         |

* The first Delete right after the window opens is ignored to prevent accidents. Press an arrow key or Tab once and Delete works immediately

## Pausing and Clearing

| Task                     | How                                                                                                                      |
| :----------------------- | :----------------------------------------------------------------------------------------------------------------------- |
| Pause · resume recording | **⌃⌥⌘P** (`history.pause.hotkey`) · menu bar **📜 Clipboard ▸ Pause / Resume**                                           |
| Clear everything         | Menu bar **📜 Clipboard ▸ Clear Clipboard History** · REST `POST /api/v2/settings/history/clear`                         |
| Clipboard → snippet      | With an item selected in the history window, menu bar **📜 Clipboard ▸ Clipboard to Snippet** (same as ⌘S in the window) |

Pause recording before copying a password and it won't be stored.

## Settings (`_config.yml`)

| Key                               | Bundled default | Description                                        |
| :-------------------------------- | :-------------- | :------------------------------------------------- |
| `history.viewer.hotkey`           | `{⌘;}`          | History window hotkey                              |
| `history.pause.hotkey`            | `{^⌥⌘P}`        | Pause hotkey                                       |
| `history.isPaused`                | `false`         | Paused state                                       |
| `history.enable.plainText`        | `true`          | Record text                                        |
| `history.enable.images`           | `true`          | Record images                                      |
| `history.enable.fileLists`        | `true`          | Record file lists (files copied in Finder)         |
| `history.retentionDays.plainText` | `90`            | Days to keep text                                  |
| `history.retentionDays.images`    | `7`             | Days to keep images                                |
| `history.retentionDays.fileLists` | `30`            | Days to keep file lists                            |
| `history.moveDuplicatesToTop`     | `true`          | Copying the same content again moves it to the top |
| `history.showPreview`             | `true`          | Show the preview                                   |
| `history.viewer.width`            | `350`           | Window width (pt)                                  |

Expired items and unused image files are cleaned up automatically. Over REST, read and change these with `GET` · `PATCH /api/v2/settings/history`.

## Querying over REST and the Command Line

```bash
# The 10 most recent items
curl -s "http://localhost:3015/api/v2/clipboard/history?limit=10"

# Filter by kind and app (kind: plain_text | image | file_list)
curl -s "http://localhost:3015/api/v2/clipboard/history?kind=plain_text&app=Safari"

# Search
curl -s "http://localhost:3015/api/v2/clipboard/search?q=docker"

# Command line
fSnippetCli clipboard list --limit 10
fSnippetCli clipboard search docker
fSnippetCli clipboard get <id>
```

You can also insert the Nth history item into a snippet with the `{{clipboard:N}}` placeholder — [Placeholder Guide](../Placeholder.md).

## Next Steps

* [Menu Bar Usage](06_MenuBar_Usage.md)
* [REST API Usage](07_API_Usage.md)
