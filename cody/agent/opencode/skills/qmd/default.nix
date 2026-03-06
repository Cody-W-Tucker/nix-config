{
  programs.opencode.skills = {
    qmd = ''
      ---
      name: qmd
      description: Search markdown knowledge bases, notes, and documentation using QMD. Use when users ask to search notes, find documents, or look up information.
      license: MIT
      metadata:
        author: tobi
        version: "2.0.0"
      allowed-tools: Bash(qmd:*)
      ---

      # QMD - Quick Markdown Search

      Local search engine for markdown content.

      ## Status

      !`qmd status 2>/dev/null`

      ### Query Types

      | Type | Method | Input |
      |------|--------|-------|
      | `lex` | BM25 | Keywords — exact terms, names, code |
      | `vec` | Vector | Question — natural language |
      | `hyde` | Vector | Answer — hypothetical result (50-100 words) |

      ### Writing Good Queries

      **lex (keyword)**
      - 2-5 terms, no filler words
      - Exact phrase: `"connection pool"` (quoted)
      - Exclude terms: `performance -sports` (minus prefix)
      - Code identifiers work: `handleError async`

      **vec (semantic)**
      - Full natural language question
      - Be specific: `"how does the rate limiter handle burst traffic"`
      - Include context: `"in the payment service, how are refunds processed"`

      **hyde (hypothetical document)**
      - Write 50-100 words of what the *answer* looks like
      - Use the vocabulary you expect in the result

      **expand (auto-expand)**
      - Use a single-line query (implicit) or `expand: question` on its own line
      - Lets the local LLM generate lex/vec/hyde variations
      - Do not mix `expand:` with other typed lines — it's either a standalone expand query or a full query document

      ### Combining Types

      | Goal | Approach |
      |------|----------|
      | Know exact terms | `lex` only |
      | Don't know vocabulary | Use a single-line query (implicit `expand:`) or `vec` |
      | Best recall | `lex` + `vec` |
      | Complex topic | `lex` + `vec` + `hyde` |

      First query gets 2x weight in fusion — put your best guess first.

      ### Lex Query Syntax

      | Syntax | Meaning | Example |
      |--------|---------|---------|
      | `term` | Prefix match | `perf` matches "performance" |
      | `"phrase"` | Exact phrase | `"rate limiter"` |
      | `-term` | Exclude | `performance -sports` |

      Note: `-term` only works in lex queries, not vec/hyde.

      ### Collection Filtering

      ```json
      { "collections": ["docs"] }              // Single
      { "collections": ["docs", "notes"] }     // Multiple (OR)
      ```

      Omit to search all collections.

      ## CLI

      ```bash
      qmd query "question"              # Auto-expand + rerank
      qmd query $'lex: X\nvec: Y'       # Structured
      qmd query $'expand: question'     # Explicit expand
      qmd search "keywords"             # BM25 only (no LLM)
      qmd get "#abc123"                 # By docid
      qmd multi-get "journals/2026-*.md" -l 40  # Batch pull snippets by glob
      qmd multi-get notes/foo.md,notes/bar.md   # Comma-separated list, preserves order
      ```
    '';
  };
}
