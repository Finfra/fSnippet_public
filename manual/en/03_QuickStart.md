---
title: fSnippetCli Quick Start
description: fSnippetCli quick start — create, expand, find in the popup, and check over REST in four steps
date: 2026.10.09
---
# Quick Start

Assuming you have installed fSnippetCli (`brew services start fsnippet-cli`) and granted Accessibility permission, let's create a first snippet and expand it in another app. It takes four steps.

| Step | Do                       | Result                                           |
| :--- | :----------------------- | :----------------------------------------------- |
| 1    | Create a first snippet   | One file, `Demo/hi===Greeting.txt`               |
| 2    | Expand it in another app | `dhi` + right ⌘ → `Hello, fSnippet!`             |
| 3    | Find it in the popup     | ⌥⇧Space → search → Enter                         |
| 4    | Check it over REST       | Look up the abbreviation and content with `curl` |

## Step 1: Create a First Snippet

A snippet is **a text file inside a subfolder of the snippet folder**. The file name follows `abbreviation===name.txt`, and the file content is the text to expand.

In Terminal:

```bash
mkdir -p ~/Documents/finfra/fSnippetData/snippets/Demo
printf 'Hello, fSnippet!' > ~/Documents/finfra/fSnippetData/snippets/Demo/hi===Greeting.txt
```

To use Finder instead, choose **⚙️ Configuration ▸ Open Snippet Folder** from the menu bar icon, create a `Demo` folder, and save a text file with the same name. You can also do it over the REST API.

```bash
curl -X POST http://localhost:3015/api/v2/folders \
  -H "Content-Type: application/json" -d '{"name":"Demo"}'
curl -X POST http://localhost:3015/api/v2/snippets \
  -H "Content-Type: application/json" \
  -d '{"folder":"Demo","keyword":"hi","name":"Greeting","content":"Hello, fSnippet!"}'
```

## Step 2: Expand It in Another App

An abbreviation is **folder prefix + abbreviation from the file name + trigger key**.

| Part          | Value   | Rule                                                  |
| :------------ | :------ | :---------------------------------------------------- |
| Folder prefix | `d`     | The capital `D` of the folder name `Demo`, lowercased |
| Abbreviation  | `hi`    | The part of the file name before `===`                |
| Trigger key   | right ⌘ | Default `snippet_trigger_key: "{right_command}"`      |

In any app — a text editor, Notes, a browser text field — type `dhi` and press **right ⌘ once**. `dhi` is removed and `Hello, fSnippet!` is inserted.

* New files are picked up automatically by the folder watcher. If not, choose **👻 Daemon ▸ Reload Snippets** from the menu bar or run `curl -X POST http://localhost:3015/api/v2/reload`
* If it still doesn't change, check Accessibility permission — [Installation › Accessibility Permission](02_Install.md#4-accessibility-permission)

## Step 3: Find It in the Popup

If you can't remember an abbreviation, find it in the snippet popup.

1. Put the cursor where you want to insert and press **⌥⇧Space** (the current hotkey is shown next to **⚡ Snippet Popup** in the menu)
2. Type `hi` in the search field
3. Pick with **↑ ↓** and press **Enter** (or **⌘1** – **⌘9** to pick directly) — the text goes into the original app
4. Press **Esc** to close

## Step 4: Check It over REST

```bash
curl -s "http://localhost:3015/api/v2/snippets/search?q=Greeting"
```

If `abbreviation` in the response is `dhi{right_command}`, the abbreviation from Step 2 is right. You can also pass the abbreviation and get only the expanded text back.

```bash
curl -s -X POST http://localhost:3015/api/v2/snippets/expand \
  -H "Content-Type: application/json" \
  -d '{"abbreviation":"dhi{right_command}"}'
```

## One More Step: A Date Snippet

Placeholders in the file content are filled in at expansion time.

```bash
printf '{{date}}' > ~/Documents/finfra/fSnippetData/snippets/Demo/td===Today.txt
```

`dtd` + right ⌘ inserts today's date, like `2026-10-09`. For the full syntax, see the [Placeholder Guide](../Placeholder.md).

## Prefer a GUI?

Writing snippets in an editor and changing settings in a window is provided by the wrapper app **fSnippet** — [fSnippet product page](https://finfra.kr/product/fSnippet/en/index.html).

## Next Steps

* [Snippet Usage](04_Snippet_Usage.md) — file name rules · trigger key · `_rule.yml` · popup
* [Clipboard History](05_Clipboard_Usage.md) — reuse what you copied with ⌘;
* [Menu Bar Usage](06_MenuBar_Usage.md) — menu · hotkeys · `_config.yml` · command line
* [REST API Usage](07_API_Usage.md) — all endpoints
