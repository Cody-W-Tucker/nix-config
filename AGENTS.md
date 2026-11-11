# CodyOS

You are assisting a user working on a NixOS system config using flakes. Full documentation is available at `docs/`.

## Evidence Discipline

- Before declaring an audit or evidence report complete, verify every acceptance criterion with direct source or evaluated evidence; explicitly mark anything unverified. When a criterion requires behavioral confirmation, run a focused runtime test; source inspection alone is insufficient.
- Before citing a file, open and read it in the current session; grep/search output does not count. For exhaustive inventories, enumerate every relevant exact path and inspect every search hit and referenced file.
- Verify claims about upstream options, NixOS behavior, and override/build semantics in authoritative documentation, source, or tests; search snippets are not evidence.
- Count reads and checks as successful only when their status and output demonstrate success; on failure, inspect the error, correct the invocation, and rerun before concluding.

## Build Testing

Validate risky changes such as new services, complex module refactors, unfamiliar Nix patterns, flake-input swaps, and Home Manager module wiring with `nix flake check`. It is the only required check: it evaluates both hosts and runs formatting, statix, deadnix, and `check-imports`, so do not also run `nixos-rebuild dry-run` (it repeats the same evaluation). Do not call a risky change validated unless it succeeds. Simple package-list updates, existing-value changes, and minor configuration tweaks rarely need pre-testing; the user will catch issues during their `update` run.

If the check fails, read the logs and solve the issues.

```bash
# Checks both hosts and all flake outputs. Stage new files first.
nix flake check

# Optional: actually build a host when the derivations themselves are in doubt.
nixos-rebuild build --flake .#nas
```

Once the changes have settled, the user will run the `update` script to build and activate the system.

## High-value repo rules

### Editing

- Keep narrowly scoped edits minimal: preserve unrelated lines and comments, and avoid repository-wide formatting.

### Naming & Files

- Use lowercase kebab-case for all file names
- Match upstream package names when practical; use CLI-safe kebab-case for internal scripts
- Use quoted attribute names for secret keys with dashes: `sops.secrets."paperless-password"`

### Module Structure

- Naming: `modules/{location}/{item}/default.nix` and file.
- Keep `default.nix` short.
  - Use supporting files with self-explaining names if needed.
  - Examples: `module.nix`, `package.nix` and `service.nix`.
- Keep secrets declarations close to their consuming service

### Flakes & Git

- New files must be git-tracked or flakes won't see them
- When code changes invalidate local docs or package notes, update the affected documentation in the same change.
- Never commit raw secrets (use SOPS-NIX.)
- The user will need to add secrets via the sops edit command.

<!-- code-review-graph MCP tools -->

## MCP Tools: code-review-graph

Use code-review-graph tools before filesystem scanning for broad exploration,
impact analysis, relationship tracing, and reviews. For targeted verification of
already-named files, inspect those files directly. The graph is faster and gives
structural context (callers, dependents, test coverage) that file scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes_tool` or `query_graph_tool` instead of Grep
- **Understanding impact**: `get_impact_radius_tool` instead of manually tracing imports
- **Code review**: `detect_changes_tool` + `get_review_context_tool` instead of reading entire files
- **Finding relationships**: `query_graph_tool` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview_tool` + `list_communities_tool`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need. If the graph reports stale/not ready, update it and retry before using filesystem tools. This fallback rule applies to exploration, not targeted inspection of already-identified paths.

### Key Tools

| Tool                             | Use when                                               |
| -------------------------------- | ------------------------------------------------------ |
| `detect_changes_tool`            | Reviewing code changes — gives risk-scored analysis    |
| `get_review_context_tool`        | Need source snippets for review — token-efficient      |
| `get_impact_radius_tool`         | Understanding blast radius of a change                 |
| `get_affected_flows_tool`        | Finding which execution paths are impacted             |
| `query_graph_tool`               | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes_tool`     | Finding functions/classes by name or keyword           |
| `get_architecture_overview_tool` | Understanding high-level codebase structure            |
| `refactor_tool`                  | Planning renames, finding dead code                    |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes_tool` for code review.
3. Use `get_affected_flows_tool` to understand impact.
4. Use `query_graph_tool` pattern="tests_for" to check coverage.
