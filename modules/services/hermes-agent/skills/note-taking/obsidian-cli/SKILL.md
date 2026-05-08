---
name: obsidian-cli
description: Use when interacting with a running Obsidian instance through the obsidian CLI.
version: 1.0.0
author: Cody Tucker
license: MIT
metadata:
  hermes:
    tags: [obsidian, notes, cli]
    related_skills: [obsidian-markdown, obsidian-bases, qmd]
prerequisites:
  commands: [obsidian]
---

# Obsidian CLI

Use the `obsidian` CLI when working against the live app. This is preferred for note edits that should immediately appear in Obsidian and trigger plugin or view updates.

## When to Use

- Read, create, append, and search notes in an open vault.
- Set properties and work with daily notes or tasks.
- Inspect backlinks, tags, and vault state.

## Rules

- The user's primary vault is `Personal`.
- Commands target the most recently focused vault by default.
- Use `vault=<name>` first when you need a specific vault.
- Quote parameter values that contain spaces.

## Common Commands

```bash
obsidian help
obsidian read file="My Note"
obsidian create name="New Note" content="# Hello" silent
obsidian append file="My Note" content="New line"
obsidian search query="search term" limit=10
obsidian daily:read
obsidian daily:append content="- [ ] New task"
obsidian property:set name="status" value="done" file="My Note"
obsidian tasks daily todo
obsidian tags sort=count counts
obsidian backlinks file="My Note"
```

## Targeting

- `file=<name>` resolves like a wikilink.
- `path=<path>` uses an exact path from vault root.

## Notes

- Use `silent` to avoid opening files unnecessarily.
- Use `--copy` when clipboard output is useful.
- Use `obsidian help` for the up-to-date command list, including developer commands.
