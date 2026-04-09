---
name: SKILL
description: Executes Markdown-based folder tests for fSnippet to verify file monitoring and rule application logic.
---

# Folder Test Runner Skill

This skill executes the folder-based regression tests defined in Markdown tables using `Tests/FolderTest/FolderTestRunner.swift`.

## Usage

1.  **Run Folder Tests**:
    ```bash
    ./_tool/verify/run_folder_tests.sh
    ```

## Scope

-   **Source**: `Tests/FolderTest/testTable_org.md` (Input Markdown Table)
-   **Runner**: `Tests/FolderTest/FolderTestRunner.swift`
-   **Output**: `Tests/FolderTest/Result/result_latest.md` (Generated Result Table)
-   **Purpose**: Verify file system interactions, `_rule.yml` generation, and abbreviation matching in a sandbox environment based on a declarative table.

## Implementation Details

The runner parses the input Markdown table, generates a corresponding file structure and `_rule.yml` in a sandbox, and verifies if the expected abbreviations and triggers are correctly matched. It outputs a formatted Markdown table with validation results.
