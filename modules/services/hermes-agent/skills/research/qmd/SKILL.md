---
name: qmd
description: Use when searching markdown knowledge bases, notes, and docs with QMD.
version: 1.0.0
author: Cody Tucker
license: MIT
metadata:
  hermes:
    tags: [knowledge, markdown, search, qmd]
    related_skills: [obsidian-cli, obsidian-markdown, obsidian-bases]
prerequisites:
  commands: [qmd]
---

# QMD

Use QMD as the fast local search engine for markdown content.

## When to Use

- Search notes, journals, docs, and transcripts.
- Look up exact terms, code identifiers, or names.
- Do semantic search when the right vocabulary is unclear.

## Query Modes

| Type | Best for |
|------|----------|
| `lex` | Exact keywords, phrases, names, code |
| `vec` | Natural-language questions |
| `hyde` | Hard topics where a hypothetical answer improves retrieval |
| `expand` | Let QMD derive query variants automatically |

## Good Query Patterns

### Lex

- Keep it to 2-5 sharp terms.
- Use quotes for exact phrases: `"connection pool"`
- Exclude terms with `-term`.
- Code identifiers are good lex queries.

### Vec

- Ask a full question.
- Include system or project context when relevant.

### HyDE

- Write a short 50-100 word version of the answer you expect.
- Use the vocabulary likely to appear in strong matches.

## Common Commands

```bash
qmd status
qmd query "how does the rate limiter handle burst traffic"
qmd query $'lex: rate limiter\nvec: how are bursts handled'
qmd query $'expand: how does the payment service process refunds'
qmd query --json --explain "consistency tradeoffs"
qmd search "exact keywords"
qmd get "#abc123"
qmd multi-get "journals/2026-*.md" -l 40
```

## MCP Query Shape

```json
{
  "searches": [
    { "type": "lex", "query": "CAP theorem consistency" },
    { "type": "vec", "query": "tradeoff between consistency and availability" }
  ],
  "collections": ["docs"],
  "limit": 10
}
```

## Retrieval Guidance

- Use `lex` first when you know the domain terms.
- Combine `lex` and `vec` for best recall.
- Add `intent` when a query is ambiguous.
- Put the strongest search first.
- Use `get` or `multi-get` after search to inspect the actual source material.

## Setup Reminder

If QMD is not installed or configured, check `qmd status`. Typical setup is:

```bash
qmd collection add ~/notes --name notes
qmd embed
```
