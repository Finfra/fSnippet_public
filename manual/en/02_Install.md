---
title: Installing fSnippetCli
description: Installing fSnippetCli · Accessibility permission · service management · checking the REST API
date: 2026.10.09
---
# Installation and Permissions

## 1. System Requirements

| Item       | Requirement                                          |
| :--------- | :--------------------------------------------------- |
| macOS      | 14.0 or later                                        |
| Installer  | Homebrew                                             |
| Permission | Accessibility permission (required)                  |
| Build      | Xcode 15.0 or later (only when building from source) |

## 2. Install with Homebrew (recommended)

> **Terms notice before installing.** The source code is Apache-2.0, so building it yourself comes with no restrictions. The **official distribution** installed by the commands below is free without limit for individuals, education, non-profits and open-source projects, and free for other organizations up to **250 concurrent copies**. Beyond that, or for resale, bundling or hosting, you need a [commercial license](../../COMMERCIAL.md). Installing the official distribution means you accept the [official distribution terms](../../DISTRIBUTION-TERMS.md).

```bash
brew tap finfra/tap
brew install finfra/tap/fsnippet-cli
brew services start fsnippet-cli     # start now and at every login
```

The app is installed at `$(brew --prefix)/opt/fsnippet-cli/fSnippetCli.app` (`/opt/homebrew/opt/fsnippet-cli/fSnippetCli.app` on Apple Silicon). Once running, its icon appears in the menu bar. It does not appear in the Dock.

| Task       | Command                                                           |
| :--------- | :---------------------------------------------------------------- |
| Status     | `brew services info fsnippet-cli`                                 |
| Stop       | `brew services stop fsnippet-cli`                                 |
| Restart    | `brew services restart fsnippet-cli`                              |
| Update     | `brew upgrade fsnippet-cli`                                       |
| Uninstall  | `brew services stop fsnippet-cli` → `brew uninstall fsnippet-cli` |
| Remove tap | `brew untap finfra/tap` (optional)                                |

* Uninstalling keeps your snippets, settings and clipboard history in `~/Documents/finfra/fSnippetData/`. Delete that folder yourself to remove everything
* Service logs go to `$(brew --prefix)/var/log/fsnippet-cli.log` and `fsnippet-cli.err.log`; the engine log is `logs/flog_cliApp.log` in the data folder

## 3. Build from Source

```bash
git clone https://github.com/Finfra/fSnippet_public.git
cd fSnippet_public/cli
xcodebuild -scheme fSnippetCli -configuration Release build
```

Output: `~/Library/Developer/Xcode/DerivedData/fSnippetCli-*/Build/Products/Release/fSnippetCli.app`

Source builds include the fSnippet icon. The icon is a Finfra trademark and not covered by the Apache license, so follow [TRADEMARK.md](../../TRADEMARK.md) when redistributing a build that contains it — details: [cli/README.md](../../cli/README.md).

## 4. Accessibility Permission

To watch keystrokes and insert text, **fSnippetCli** needs Accessibility permission.

1. **System Settings** › **Privacy & Security** › **Accessibility**
2. Turn on **fSnippetCli** (if it is missing, add `/opt/homebrew/opt/fsnippet-cli/fSnippetCli.app` with `+`)
3. Verify: `curl -s http://localhost:3015/api/v2/settings/general/permissions` → `"accessibility" : true`

| Symptom                                       | Fix                                                                               |
| :-------------------------------------------- | :-------------------------------------------------------------------------------- |
| Enabled in the list but nothing expands       | Toggle it off and on, or remove it with `-`, add it again and restart the service |
| Permission lost after a source build          | Each build has a different signature, so add it again                             |
| The menu opens but abbreviations don't expand | Permission is off — repeat steps 1–2 and restart fSnippetCli                      |

## 5. Check the REST API

The REST server is **on by default** (port 3015, `127.0.0.1` only).

```bash
curl -s http://localhost:3015/api/v2/status
```

If you see `"status":"ok"`, it works. Turning the server off, changing the port, or allowing external access is done in `_config.yml` — [Menu Bar Usage › Configuration File](06_MenuBar_Usage.md#configuration-file-_configyml). v1 (`/api/v1/*`) is retired and returns `410 Gone`.

## 6. (Optional) The fSnippet GUI Wrapper

For a settings window and a snippet editor, also install the App Store app **fSnippet**. fSnippet works through this fSnippetCli — [fSnippet product page](https://finfra.kr/product/fSnippet/en/index.html).

## Next Steps

* [Quick Start](03_QuickStart.md)
* [Menu Bar Usage](06_MenuBar_Usage.md)
