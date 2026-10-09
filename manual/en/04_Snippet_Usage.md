---
title: fSnippetCli Snippet Usage
description: Snippet file and folder rules, trigger key, _rule.yml Prefix/Suffix, snippet popup, placeholders, Alfred import
date: 2026.10.09
---
# Snippet Usage

A snippet is a **text file** in the snippet folder (`~/Documents/finfra/fSnippetData/snippets/`). Adding, editing or deleting a file is picked up right away by the folder watcher, so you can manage snippets with Finder, an editor, Git, or scripts.

## Folder and File Layout

```
snippets/
├── _rule.yml                  # per-folder Prefix/Suffix rules
├── _rule_for_import.yml       # mapping rules for Alfred import
├── Docker/                    # one folder = one snippet collection
│   ├── rocv2===Docker_Run.txt
│   └── dps===docker ps.txt
└── AWS/
    └── ec2===EC2.txt
```

* Put snippets **inside a folder** directly under `snippets/`. Each folder is one collection
* `.txt` is the usual extension. `.md`, text extensions such as `.sh`, `.py` and `.json`, and files without an extension are also read; binary files are ignored
* Files starting with `.` and names in the exclusion list (`snippet_excluded_files` in `_config.yml`; by default `README.md`, `_README.md`, `z_old`, `.gitignore`, `.DS_Store`) are not read as snippets

## File Name Rules

| File name format  | Meaning                                                                                                   | Example (`Docker` folder)           |
| :---------------- | :-------------------------------------------------------------------------------------------------------- | :---------------------------------- |
| `abbr===name.txt` | Standard format. Before `===` is the abbreviation, after it a description (shown in search and the popup) | `rocv2===Docker_Run.txt` → `drocv2` |
| `===name.txt`     | No abbreviation — the folder prefix alone becomes the abbreviation                                        | `===Docker.txt` → `d`               |
| `===name_.txt`    | No abbreviation + trailing `_` — the first letter of the prefix is capitalized                            | `===Docker_.txt` → `D`              |
| `abbr.txt`        | No `===` — the whole file name is the abbreviation                                                        | `dps.txt` → `ddps`                  |

Characters that cannot (or should not) appear in file names are written as tokens. They are turned into the real characters when the abbreviation is computed.

| Token                  | Char      | Token                          | Char          |
| :--------------------- | :-------- | :----------------------------- | :------------ |
| `{gt}` · `{lt}`        | `>` · `<` | `{semicolon}`                  | `;`           |
| `{pipe}`               | `\|`      | `{apostrophe}` · `{backtick}`  | `'` · `` ` `` |
| `{caret}`              | `^`       | `{exclamation}` · `{question}` | `!` · `?`     |
| `{underbar}`           | `_`       | `{tilde}`                      | `~`           |
| `{equal}` · `{equals}` | `=`       | `{lbracket}` · `{rbracket}`    | `[` · `]`     |
| `{hash}`               | `#`       | `{comma}`                      | `,`           |

## How Abbreviations Are Formed

For a regular folder (one whose name doesn't start with `_` and has no rule in `_rule.yml`):

**abbreviation = folder prefix + abbreviation from the file name + trigger key**

* **Folder prefix**: the capital letters of the folder name, lowercased — `Docker` → `d`, `AWS` → `aws`, `MyFolder` → `mf`. A folder with no capitals (`demo`) has no prefix
* **Trigger key**: **right ⌘** by default — see "Trigger Key" below

| Folder · file             | Type                   |
| :------------------------ | :--------------------- |
| `Docker/rocv2===…txt`     | `drocv2`, then right ⌘ |
| `AWS/ec2===EC2.txt`       | `awsec2`, then right ⌘ |
| `MyFolder/x===Sample.txt` | `mfx`, then right ⌘    |

To see the exact abbreviation, check `abbreviation` in the output of `fSnippetCli snippet search <query>` or REST `GET /api/v2/snippets/search?q=` (e.g. `drocv2{right_command}`). `fSnippetCli folder list` shows every folder's prefix and suffix at a glance.

## Trigger Key

The trigger key signals "I've finished typing the abbreviation". Type an abbreviation, press the trigger key, and the abbreviation is removed and the snippet content inserted.

| Item                    | Value · how                                                                                                    |
| :---------------------- | :------------------------------------------------------------------------------------------------------------- |
| Default                 | right ⌘ (`snippet_trigger_key: "{right_command}"` in `_config.yml`)                                            |
| Check the current value | `curl -s http://localhost:3015/api/v2/triggers` · `fSnippetCli trigger`                                        |
| Change it               | Edit `snippet_trigger_key` in `_config.yml` · REST `PUT /api/v2/settings/general/trigger-key`                  |
| Backspace correction    | `snippet_trigger_bias` (default `0`, -10 to 10) — adjust when expansion deletes too few or too many characters |

* To use a different trigger (suffix) per folder, use `_rule.yml`

## Folder Rules `_rule.yml`

`snippets/_rule.yml` sets a per-folder prefix and suffix. An empty rules file is created on first launch.

```yaml
collections:
  - name: "ANsible"        # folder name
    suffix: "!"            # typed after the abbreviation (acts as the trigger)
  - name: "_emoji"
    prefix: ",,"           # typed before the abbreviation
    suffix: "{keypad_comma}"
    trigger_bias: 0        # (optional) backspace correction for this folder only
    description: "Emoji"   # (optional) description
```

| Field          | Description                                                                                                  |
| :------------- | :----------------------------------------------------------------------------------------------------------- |
| `name`         | Folder the rule applies to                                                                                   |
| `prefix`       | String typed before the abbreviation                                                                         |
| `suffix`       | String typed after the abbreviation. Typing the suffix expands immediately. `" "` (a space) expands on Space |
| `trigger_bias` | Backspace correction for this folder only (falls back to the global value)                                   |
| `description`  | Description                                                                                                  |

* With a rule, the abbreviation = `prefix` + automatic prefix (only for folders not starting with `_`) + abbreviation + `suffix`. Example: folder `ANsible` with `suffix: "!"` and `pb===Playbook.txt` → `anpb!`
* If both `prefix` and `suffix` are empty, the default trigger key is appended
* Folders starting with `_` (such as folders imported from Alfred) get no automatic prefix, so set their abbreviation through `_rule.yml`
* After editing the file, apply it with **👻 Daemon ▸ Reload Snippets** in the menu bar or `curl -X POST http://localhost:3015/api/v2/reload`
* You can also change rules over REST: `GET` · `PATCH /api/v2/settings/snippet-folders/{folder}` (`prefix`, `suffix`)

## Snippet Popup

A window to search for and insert snippets without knowing the abbreviation. The popup does not steal focus from the app you were working in, and it moves the mouse pointer aside so the pointer doesn't cover it.

| Key     | Action                                                                                   |
| :------ | :--------------------------------------------------------------------------------------- |
| ⌥⇧Space | Open the popup (default · menu bar **⚡ Snippet Popup**)                                 |
| Type    | Search                                                                                   |
| ↑ · ↓   | Move between items                                                                       |
| Enter   | Insert the selected snippet into the original app                                        |
| ⌘1 – ⌘9 | Insert the item at that position (modifier: `snippet_popup_quick_select_modifier_flags`) |
| Esc     | Close                                                                                    |
| Tab     | Create a new snippet · edit the selected one — **requires fSnippet (GUI wrapper)**       |

| `_config.yml` key             | Bundled default | Description        |
| :---------------------------- | :-------------- | :----------------- |
| `snippet_popup_hotkey`        | `{⌥⇧Space}`     | Popup hotkey       |
| `snippet_popup_rows`          | `9`             | Visible rows       |
| `snippet_popup_width`         | `500`           | Popup width (pt)   |
| `snippet_popup_preview_width` | `400`           | Preview width (pt) |
| `snippet_popup_search_scope`  | `content`       | Search scope       |

## Placeholders

Write `{{...}}` in snippet content and the value is filled in at expansion time.

| Example                             | Action                                                      |
| :---------------------------------- | :---------------------------------------------------------- |
| `{{date}}` · `{{time}}`             | Today's date · current time                                 |
| `{{isodate:yyyy.MM.dd}}`            | Date in a format you choose                                 |
| `{{clipboard}}` · `{{clipboard:1}}` | Current clipboard · Nth item of clipboard history           |
| `{{cursor}}`                        | Move the cursor here after expansion                        |
| A name such as `{{customer}}`       | Ask for the value in an input window right before expansion |

Full syntax: [Placeholder Guide](../Placeholder.md)

## Managing Snippets over REST and the Command Line

| Task                   | REST                                                                          | Command line                        |
| :--------------------- | :---------------------------------------------------------------------------- | :---------------------------------- |
| Search                 | `GET /api/v2/snippets/search?q=docker`                                        | `fSnippetCli snippet search docker` |
| List                   | `GET /api/v2/snippets?folder=Docker`                                          | `fSnippetCli snippet list`          |
| See expanded text      | `POST /api/v2/snippets/expand`                                                | `fSnippetCli snippet expand <abbr>` |
| Create a snippet       | `POST /api/v2/snippets`                                                       | —                                   |
| Delete a snippet       | `DELETE /api/v2/snippets/{id}`                                                | —                                   |
| Create · delete folder | `POST /api/v2/folders` · `DELETE /api/v2/folders/{name}` (empty folders only) | `fSnippetCli folder list` (view)    |
| Reload                 | `POST /api/v2/reload`                                                         | —                                   |

Examples and response format: [REST API Usage](07_API_Usage.md); command line: [Menu Bar Usage › Command Line](06_MenuBar_Usage.md#command-line-cli).

## Importing Alfred Snippets

Converts Alfred's snippet database (`snippets.alfdb`) into fSnippetCli folders.

```bash
# Command line (omit the path to open a file picker)
fSnippetCli import alfred "$HOME/Library/Application Support/Alfred/Databases/snippets.alfdb"

# REST
curl -X POST http://localhost:3015/api/v2/import/alfred \
  -H "Content-Type: application/json" \
  -d '{"db_path":"~/Library/Application Support/Alfred/Databases/snippets.alfdb"}'
```

* Only Alfred snippets with auto expand turned on and a keyword are imported
* Each Alfred collection becomes one folder under `snippets/`, and the collection icon is copied to the folder's `icon.png`
* Per-collection prefix and suffix mapping follows `snippets/_rule_for_import.yml`
* Back up your `snippets/` folder before importing
* The database location may differ depending on your Alfred sync settings (needs verification)

## Prefer a GUI?

The snippet editor (new snippet, edit, bulk-convert to `{{placeholder}}` with a regex) and the folder rules screen are provided by the wrapper app **fSnippet** — [fSnippet product page](https://finfra.kr/product/fSnippet/en/index.html).

## Next Steps

* [Clipboard History](05_Clipboard_Usage.md)
* [Menu Bar Usage](06_MenuBar_Usage.md)
* [REST API Usage](07_API_Usage.md)
