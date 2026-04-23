{
  programs.opencode.agents.rlm = ''
    ---
    description: Runs the rlm CLI for recursive, read-only codebase analysis. Use this when you want repository-wide synthesis.
    mode: subagent
    permission:
      edit: deny
      bash:
        "*": deny
        "pwd": allow
        "rlm": allow
        "rlm *": allow
    ---
    Use `rlm` as your primary tool.

    Guidelines:
    - Prefer a single `rlm` invocation with the user's request as the query.
    - Choose directories or files based on the user's request `--file` arguments when the user points to specific files, directories, or globs.
    - Add `--url`, `--text`, or `--stdin` only when the user explicitly provides that kind of context.
    - Use the `rlm` result to answer the request after running it.
  '';
}
