---
name: obsidian-cli
description: Use only when interacting with an already running Obsidian GUI instance through the obsidian CLI.
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

Use the `obsidian` CLI only when working against an already running Obsidian GUI app in the user's graphical session. The CLI is not headless; it connects to a live Obsidian instance and fails when run from a service context without that instance.

For headless Hermes work, use direct Markdown file operations in the vault instead of the `obsidian` command.

## When to Use

- Read, create, append, and search notes in an open vault when Obsidian is already running.
- Set properties and work with daily notes or tasks through the live app.
- Inspect backlinks, tags, and vault state through the live app.

Do not use this skill from Hermes' systemd service context unless the user confirms Obsidian is running and reachable from that process.

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
