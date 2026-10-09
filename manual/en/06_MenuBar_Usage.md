---
title: fSnippetCli Menu Bar Usage
description: Menu bar menu, global hotkeys, key _config.yml settings, and the command line (CLI)
date: 2026.10.09
---
# Menu Bar Usage

fSnippetCli runs with no Dock icon — only a menu bar icon. Click it to open the menu below.

## Menu Items

Menu labels follow `language` in `_config.yml` (bundled default `en` for English, `ko` for Korean).

| Menu                                   | Action                                                                                                           |
| :------------------------------------- | :--------------------------------------------------------------------------------------------------------------- |
| About fSnippetCli                      | Version information                                                                                              |
| ⚡ Snippet Popup                       | Open the snippet search popup — [Snippet Popup](04_Snippet_Usage.md#snippet-popup)                               |
| 📋 Show Clipboard History              | Open the clipboard history window — [Clipboard History](05_Clipboard_Usage.md)                                   |
| 📜 Clipboard ▸ Pause / Resume          | Pause or resume clipboard recording                                                                              |
| 📜 Clipboard ▸ Clipboard to Snippet    | Register the item selected in the history window as a snippet (text requires fSnippet)                           |
| 📜 Clipboard ▸ Clear Clipboard History | Delete all history                                                                                               |
| 🔧 Open Settings Window                | Open fSnippet's settings window — **requires fSnippet**. Without it, an App Store prompt appears                 |
| 👻 Daemon ▸ Reload Snippets            | Re-read the snippet folder                                                                                       |
| 👻 Daemon ▸ Restart Daemon             | Run `brew services restart fsnippet-cli`                                                                         |
| 👻 Daemon ▸ Pause / Resume REST API    | Answer REST requests with `503` (except `/api/v2/cli/*`). Snippet expansion keeps working                        |
| ⚙️ Configuration ▸ Open Config File     | Open `_config.yml`                                                                                               |
| ⚙️ Configuration ▸ Open Snippet Folder  | Open `snippets/` in Finder                                                                                       |
| ⚙️ Configuration ▸ Open Data Folder     | Open `~/Documents/finfra/fSnippetData/`                                                                          |
| ⚙️ Configuration ▸ Open Log Folder      | Open `logs/`                                                                                                     |
| 🚀 Launch at Login                     | Toggle launch at login (kept in sync with the Homebrew service registration)                                     |
| Quit All                               | Quit fSnippetCli. While fSnippet is running, a "Quit fSnippet (⌘Q)" item also appears, and "Quit All" quits both |

* Quitting also stops the Homebrew service and quits a running fSnippet. To start again, run `brew services start fsnippet-cli`
* If the menu shows "⚠️ Service handoff failed — restart via brew services", restart with `brew services restart fsnippet-cli`

## Global Hotkeys

| Function                  | Bundled default | `_config.yml` key                |
| :------------------------ | :-------------- | :------------------------------- |
| Snippet popup             | ⌥⇧Space         | `snippet_popup_hotkey`           |
| Clipboard history window  | ⌘;              | `history.viewer.hotkey`          |
| Pause clipboard recording | ⌃⌥⌘P            | `history.pause.hotkey`           |
| Open settings (fSnippet)  | ⌃⇧⌘;            | `settings.hotkey`                |
| Toggle preview            | (none)          | `history.preview.hotkey`         |
| Register as snippet       | (none)          | `history.registerSnippet.hotkey` |
| Snippet expansion trigger | right ⌘         | `snippet_trigger_key`            |

* Hotkey values are written in braces with modifier symbols (⌃ ⌥ ⇧ ⌘; `^` also means ⌃) and the key, e.g. `{⌥⇧Space}`
* Read and change over REST: `GET /api/v2/settings/shortcuts` · `PUT` · `DELETE /api/v2/settings/shortcuts/{name}` — `name` is one of `popupHotkey`, `viewerHotkey`, `toggleCollectionPauseHotkey`, `settingsHotkey`, `togglePreviewHotkey`, `registerAsSnippetHotkey`

## Configuration File `_config.yml`

All settings live in one file, `~/Documents/finfra/fSnippetData/_config.yml`. On first launch the default file bundled with the app is copied there; it holds one `key: value` per line under `preferences:`.

```yaml
preferences:
  api_enabled: true
  api_port: 3015
  snippet_trigger_key: "{right_command}"
  history.viewer.hotkey: "{⌘;}"
```

* The config file is read when the app starts. After editing it by hand, apply it with **👻 Daemon ▸ Restart Daemon** (or `brew services restart fsnippet-cli`)
* While the app is running, the REST `settings/*` endpoints are the safer way to change settings — changes apply immediately and are saved to the file
* If an edit breaks something, `POST /api/v2/settings/actions/reset-settings` restores the defaults

### Key Settings

| Key                                          | Bundled default        | Description                                                                                   |
| :------------------------------------------- | :--------------------- | :-------------------------------------------------------------------------------------------- |
| `snippet_base_path`                          | `./snippets`           | Snippet folder (relative to the data folder)                                                  |
| `snippet_excluded_files`                     | `README.md` and 4 more | File and folder names not read as snippets                                                    |
| `snippet_trigger_key`                        | `{right_command}`      | Expansion trigger key                                                                         |
| `snippet_trigger_bias`                       | `0`                    | Backspace correction on expansion (-10 to 10)                                                 |
| `snippet_popup_hotkey`                       | `{⌥⇧Space}`            | Snippet popup hotkey                                                                          |
| `snippet_popup_quick_select_modifier_flags`  | `{command}`            | Modifier for quick select (1–9) in the popup                                                  |
| `snippet_popup_rows` · `snippet_popup_width` | `9` · `500`            | Popup rows · width                                                                            |
| `history.*`                                  | —                      | Clipboard history — [Clipboard History › Settings](05_Clipboard_Usage.md#settings-_configyml) |
| `api_enabled`                                | `true`                 | Turn on the REST API server                                                                   |
| `api_port`                                   | `3015`                 | REST API port (1024–65535)                                                                    |
| `api_allow_external`                         | `false`                | `true` allows access from other devices                                                       |
| `api_allowed_cidr`                           | `127.0.0.1/32`         | Address range allowed for external access                                                     |
| `language`                                   | `en`                   | Menu and notification language (`ko` for Korean). Applies from the next launch                |
| `appearance`                                 | `system`               | Appearance mode                                                                               |
| `launch_at_login` · `start_at_login`         | `true`                 | Launch at login                                                                               |
| `hide_menu_bar_icon`                         | `false`                | Hide the menu bar icon                                                                        |
| `show_notifications`                         | `true`                 | Show notifications                                                                            |
| `play_ready_sound`                           | `true`                 | Play a sound when ready                                                                       |
| `log_level`                                  | `info`                 | Log level                                                                                     |

* With `api_allow_external: true`, other devices on the network can read your snippets and clipboard history. Turn it on only when needed and narrow the range with `api_allowed_cidr`

## Command Line (CLI)

Given arguments, the fSnippetCli executable acts as a command-line tool that queries the running engine over REST (the service must be running). Without arguments it starts as the menu bar app.

```bash
alias fSnippetCli=/opt/homebrew/opt/fsnippet-cli/fSnippetCli.app/Contents/MacOS/fSnippetCli
fSnippetCli status
fSnippetCli snippet search docker --limit 5
```

| Command                                                          | Description                          |
| :--------------------------------------------------------------- | :----------------------------------- |
| `status` · `version`                                             | Service status · version             |
| `snippet list` · `search <query>` · `get <id>` · `expand <abbr>` | Look up snippets · expanded text     |
| `clipboard list` · `get <id>` · `search <query>`                 | Look up clipboard history            |
| `folder list` · `get <name>`                                     | Folders with their prefix and suffix |
| `stats top` · `stats history`                                    | Usage statistics                     |
| `settings get [key]` · `set <key> <value>`                       | Read · change settings               |
| `settings reset --confirm`                                       | Reset settings                       |
| `settings snapshot export [file]` · `import <file>`              | Back up · restore settings           |
| `trigger`                                                        | Current trigger key                  |
| `config`                                                         | Print the current general settings   |
| `import alfred <path>`                                           | Import Alfred snippets               |

| Option         | Description                    |
| :------------- | :----------------------------- |
| `-p`, `--port` | REST port (default 3015)       |
| `--json`       | Print raw JSON                 |
| `--limit`      | Number of results (default 20) |
| `--offset`     | Number of results to skip      |
| `-h` · `-v`    | Help · version                 |

Run `fSnippetCli --help` for full usage.

## Prefer a GUI?

A settings window (General · Popup · Clipboard · Shortcuts · Advanced tabs) is provided by the wrapper app **fSnippet** — [fSnippet product page](https://finfra.kr/product/fSnippet/en/index.html).

## Next Steps

* [REST API Usage](07_API_Usage.md)
* [FAQ](10_FAQ.md)
