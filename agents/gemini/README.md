---
title: fSnippet Gemini CLI Agent Extensions
description: Workflows and skills for Gemini CLI to interact with fSnippet via REST API
date: 2026-03-26
---

This directory contains workflows and skills for the [Gemini CLI](https://github.com/google/gemini-cli) to interact with the running **fSnippet** application via its REST API.

## Contents

- `workflows/`: Workflows that can be used in Gemini CLI (as `/command` format)
- `skills/`: Single-purpose functional units utilized by Gemini CLI

## Installation

To install these workflows and skills for your local project environment, copy them into the `.agent` directory at the root of the fSnippet project.

```bash
# Copy the workflow
mkdir -p .agent/workflows
cp agents/gemini/workflows/fsnippet-api.md .agent/workflows/

# Copy the skill
mkdir -p .agent/skills/fsnippet-api-skill
cp agents/gemini/skills/fsnippet-api-skill.md .agent/skills/fsnippet-api-skill/SKILL.md
```

Alternatively, to install them globally for Gemini CLI, you can copy them to your global Gemini CLI configuration directory.

## Provided Extensions

### Workflows
- `fsnippet-api.md`: A workflow that guides the Gemini Agent on how to interact with the fSnippet API (port 3015) to perform tasks such as searching snippets, testing snippet expansion, and checking clipboard history.

### Skills
- `fsnippet-api-skill.md`: Equips the Gemini Agent with the specific `curl` commands needed to query the fSnippet API endpoints seamlessly. It allows the agent to fetch stats, search snippets, and validate text replacements without needing to interact with the UI.

## Usage

1. Ensure fSnippet is running.
2. Ensure the API is enabled in fSnippet Preferences (Settings > Advanced > API enabled). The default port is `3015`.
3. Run the Gemini CLI and invoke the workflow:
   ```bash
   gemini /fsnippet-api
   ```
4. Ask the agent to perform API-related tasks, for example:
   > "Search for 'aws' snippets using the API."
   > "Show me the top 5 most used snippets."
