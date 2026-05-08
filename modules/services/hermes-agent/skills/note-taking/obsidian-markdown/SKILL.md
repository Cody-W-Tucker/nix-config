---
name: obsidian-markdown
description: Use when creating or editing Obsidian-flavored Markdown with wikilinks, embeds, callouts, and frontmatter.
version: 1.0.0
author: Cody Tucker
license: MIT
metadata:
  hermes:
    tags: [obsidian, markdown, wikilinks]
    related_skills: [obsidian-cli, obsidian-bases]
---

# Obsidian Flavored Markdown

Write valid Obsidian markdown, not just generic CommonMark.

## Use These Features

- Wikilinks: `[[Note Name]]`
- Aliased links: `[[Note Name|Display Text]]`
- Heading links: `[[Note Name#Heading]]`
- Embeds: `![[Note Name]]`, `![[image.png|300]]`
- Callouts: `> [!note]`
- Highlights: `==important==`
- Hidden comments: `%% hidden %%`

## Frontmatter Pattern

```yaml
---
title: My Note
tags:
  - project
aliases:
  - Alternate Name
cssclasses:
  - custom-class
---
```

## Workflow

1. Add frontmatter first.
2. Structure with standard markdown headings and lists.
3. Use wikilinks for internal vault references.
4. Use markdown links only for external URLs.
5. Add embeds and callouts where they improve navigation or readability.

## Examples

```markdown
[[Note Name]]
[[Note Name|Display Text]]
[[Note Name#Heading]]
![[Architecture Diagram.png|600]]

> [!warning] Key Risk
> This section needs review.
```

## Block References

Append a block ID to a paragraph when you need stable deep links:

```markdown
This paragraph can be linked directly. ^my-block-id
```

## Guidance

- Prefer `[[wikilinks]]` for anything inside the vault.
- Keep tags in either frontmatter or inline form like `#project/active`.
- Verify the note will render cleanly in Obsidian reading view.
