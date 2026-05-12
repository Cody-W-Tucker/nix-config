---
name: obsidian-bases
description: Use when creating or editing Obsidian Bases `.base` files with filters, formulas, and views.
version: 1.0.0
author: Cody Tucker
license: MIT
metadata:
  hermes:
    tags: [obsidian, bases, yaml]
    related_skills: [obsidian-cli, obsidian-markdown]
---

# Obsidian Bases

Create valid `.base` YAML for Obsidian Bases.

## Workflow

1. Create a `.base` file.
2. Define `filters` to select notes.
3. Add `formulas` if computed properties are needed.
4. Configure one or more views such as `table`, `cards`, or `list`.
5. Validate YAML carefully before finishing.

## Minimal Shape

```yaml
filters:
  and: []

formulas:
  age_days: 'date(now()) - file.ctime'

views:
  - type: table
    name: Notes
    order:
      - file.name
      - tags
      - formula.age_days
```

## Common Pitfalls

- Invalid YAML quoting.
- Referencing `formula.X` without defining `X`.
- Using properties in a view that do not exist on the target notes.
- Forgetting that global `filters` apply to every view.

## Validation Guidance

- Quote formulas that contain YAML-sensitive characters.
- Keep view definitions explicit.
- Open the file in Obsidian after editing to confirm it renders without YAML errors.
