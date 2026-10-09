---
title: fSnippetCli FAQ
description: fSnippetCli FAQ — relationship to fSnippet, when expansion fails, abbreviations, clipboard, REST, data, license
date: 2026.10.09
---
# Frequently Asked Questions (FAQ)

## fSnippetCli and fSnippet

**Q. Can I use fSnippetCli on its own?**
Yes. Snippet expansion, the popup, placeholders, clipboard history, the REST API, the command line and Alfred import are all fSnippetCli features. You manage settings through `_config.yml` and REST, and snippets as files.

**Q. What does fSnippet (the App Store app) add?**
A GUI: a settings window and a snippet editor. fSnippet works through fSnippetCli, so fSnippetCli must be installed alongside it — [fSnippet product page](https://finfra.kr/product/fSnippet/en/index.html).

**Q. An "Only support the paid version" window appears.**
It appears when you use something that opens fSnippet without fSnippet installed: menu bar **🔧 Open Settings Window**, **Tab** in the snippet popup, or **⌘S** on a text item in clipboard history. You can do the same things through `_config.yml`, REST, or by editing snippet files.

## When Expansion Doesn't Work

**Q. I type an abbreviation and nothing happens.**
Check in this order.

1. Service running: `brew services info fsnippet-cli` · `curl -s http://localhost:3015/api/v2/status`
2. Accessibility permission: `accessibility` is `true` in `curl -s http://localhost:3015/api/v2/settings/general/permissions` — if not, see [Installation › Accessibility Permission](02_Install.md#4-accessibility-permission)
3. The abbreviation: check the real `abbreviation` with `fSnippetCli snippet search <query>`. Forgetting the folder prefix (`Docker` → `d`) is common
4. Trigger key: the default is the **right** ⌘. The left ⌘ does not expand — `curl -s http://localhost:3015/api/v2/triggers`

**Q. Expansion stopped after a brew update.**
Toggle fSnippetCli off and on in the Accessibility list (or remove it with `-` and add it again), then run `brew services restart fsnippet-cli`.

**Q. Expansion deletes too few or too many characters.**
Adjust `snippet_trigger_bias` in `_config.yml` (default `0`, -10 to 10). If it happens only in one folder, set `trigger_bias` for that folder in `_rule.yml` — [Snippet Usage › Folder Rules](04_Snippet_Usage.md#folder-rules-_ruleyml).

**Q. A snippet I just created isn't recognized.**
The folder watcher normally picks it up; if not, use **👻 Daemon ▸ Reload Snippets** in the menu bar or `curl -X POST http://localhost:3015/api/v2/reload`. Snippet files must be **inside a folder** directly under `snippets/`.

## Settings

**Q. I edited `_config.yml` but nothing changed.**
The config file is read at startup. Apply it with **👻 Daemon ▸ Restart Daemon**, or change settings through REST `settings/*` in the first place, which applies immediately — [Menu Bar Usage › Configuration File](06_MenuBar_Usage.md#configuration-file-_configyml).

**Q. How do I show the menu in Korean?**
Set `language` in `_config.yml` to `ko` and restart (bundled default `en`).

**Q. How do I go back to the default settings?**
Use `fSnippetCli settings reset --confirm` or `POST /api/v2/settings/actions/reset-settings`. Back up first with `fSnippetCli settings snapshot export <file>` so you can restore with `import`.

## Clipboard History

**Q. I'm worried about passwords ending up in the history.**
Pause recording with **⌃⌥⌘P** before copying, and delete existing items by selecting them in the history window and pressing Delete. To delete everything, use **📜 Clipboard ▸ Clear Clipboard History** in the menu bar.

**Q. How long is history kept?**
The bundled defaults are 90 days for text, 7 days for images and 30 days for file lists — [Clipboard History › Settings](05_Clipboard_Usage.md#settings-_configyml).

## REST API and Security

**Q. How do I turn the REST API off?**
Set `api_enabled: false` in `_config.yml` and restart. To block it briefly, use **👻 Daemon ▸ Pause REST API** in the menu bar (requests get `503`; snippet expansion keeps working). Note that fSnippet, the Skill and MCP all work over REST, so they stop too.

**Q. Can other devices connect?**
By default only this Mac is allowed. The REST API has no authentication, so open external access only when needed, narrowly, with `api_allow_external` and `api_allowed_cidr` — [REST API Usage › Security](07_API_Usage.md#security).

## Data and Backup

**Q. What should I back up?**
Copy the whole data folder `~/Documents/finfra/fSnippetData/` — it contains snippets, rules, settings and clipboard history. If you only want to manage snippets, you can keep `snippets/` in a Git repository.

**Q. Can I keep the data folder somewhere else?**
Set the `fSnippetCli_config` environment variable to a path and that folder is used. How to pass the variable when running as a Homebrew service needs verification.

**Q. Can I bring over my Alfred snippets?**
Yes: `fSnippetCli import alfred <path to snippets.alfdb>` — [Snippet Usage › Importing Alfred Snippets](04_Snippet_Usage.md#importing-alfred-snippets).

## License and Uninstalling

**Q. Can I use it at work?**
The source code is Apache-2.0. The official distribution installed with Homebrew is free without limit for individuals, education, non-profits and open-source projects, and free for other organizations up to 250 concurrent copies. Beyond that, see the [commercial license](../../COMMERCIAL.md); the full terms are in the [official distribution terms](../../DISTRIBUTION-TERMS.md).

**Q. How do I remove it completely?**
Run `brew services stop fsnippet-cli` → `brew uninstall fsnippet-cli`. To remove data as well, delete `~/Documents/finfra/fSnippetData/` and remove fSnippetCli from the Accessibility list.

## Next Steps

* [Manual contents](../README.md)
* [Functional Specification](../FunctionalSpecification.md)
