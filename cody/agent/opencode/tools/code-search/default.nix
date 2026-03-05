{
  # These rules get added to the global AGENTS.md file for opencode
  programs.opencode.rules = ''
    ## Hybrid Code Search with ck

    Use `ck` as a drop-in grep replacement with semantic search capabilities. It understands meaning, not just keywords.

    ### When to Use ck vs grep

    | Use ck When | Use grep When |
    |-------------|---------------|
    | Searching by concept | Exact keyword matches |
    | Exploring unfamiliar codebases | Known function/variable names |
    | Finding code with unknown naming | Syntax/pattern matching |

    ### Search Modes

    - `--sem` - Semantic search (by meaning, finds conceptually similar code)
    - `--lex` - BM25 lexical search (full-text with ranking)
    - `--hybrid` - Combines regex + semantic
    - `--regex` - Classic grep behavior (default)

    ### Quick Reference

    ```
    # Index once per session (optional, auto-indexes on first --sem search)
    ck --index .

    # Semantic - find by concept
    ck --sem "authentication logic" src/

    # Lexical - full-text search
    ck --lex "user authentication" .

    # High-confidence results
    ck --sem --threshold 0.8 "error handling" src/

    # Interactive TUI mode
    ck --tui

    # Agent-friendly JSON output
    ck --jsonl --sem "bug fix" src/
    ```

    ### Common Options

    - `--sem, --lex, --hybrid, --regex` - Search modes
    - `--topk, --limit N` - Limit results (default: 10)
    - `--threshold SCORE` - Min score 0.0-1.0 (default: 0.6)
    - `--scores` - Show similarity scores
    - `-C NUM` - Context lines
    - `--jsonl` - JSONL for agents
    - `--model` - Embedding model (bge-small, nomic-v1.5, jina-code)
    - `--rerank` - Better relevance
    - `--tui` - Interactive mode
  '';
}
