{
  # These rules get added to the global AGENTS.md file for opencode
  programs.opencode.rules = ''
    ## Hybrid Code Search with ck

    Use `ck` for finding code by meaning, not just keywords.

    ### Search Modes

    - `ck --sem "concept"` - Semantic search (by meaning)
    - `ck --lex "keyword"` - Lexical search (full-text)
    - `ck --hybrid "query"` - Combined regex + semantic
    - `ck --regex "pattern"` - Traditional regex search

    ### Best Practices

    ::: tip Recommended Usage Patterns
    1. **Index once per session**: Run `ck --index .` at project start
    2. **Use semantic for concepts**: "error handling", "database queries"
    3. **Use lexical for names**: "getUserById", "AuthController"
    4. **Tune threshold**: `--threshold 0.7` for high-confidence results
    5. **Limit results**: `--limit 20` for focused output
    :::

    ### Example Workflows

    # Find authentication logic
    ck --sem "user authentication" src/

    # Find all TODO comments
    ck --lex "TODO" .

    # Find error handling patterns with high confidence
        ck --sem --threshold 0.8 "error handling" src/
  '';
}
