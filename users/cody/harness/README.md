# Cody Desktop Harness

This subtree owns Cody's user-session AI/operator harness: OpenCode configuration, MCP wiring, local tools, and agent/skill packaging used from the desktop.

Central docs should point here for harness implementation detail.

## Entry Points

- `default.nix` — harness import root for the desktop profile.
- `mcp.nix` — user-session MCP server/client wiring.
- `opencode/default.nix` — OpenCode user harness root.
- `claude-code/default.nix` — Claude Code user harness and shared MCP integration.
- `context.nix` — shared environment instructions.
- The no-mistakes skill for both harnesses comes from the installed CLI's pinned source.
- Claude Code also receives the declarative OpenCode skills and the shared deja-search skill. OpenCode-specific plugins are not shared.
- OpenCode's Déjà auto-recall hooks are disabled; on-demand searches use the shared MCP server. Déjà uses the NAS llama-swap embedding model for semantic search. Run `deja embed` on each host after activation to create its local vector sidecar, and rerun it when Déjà reports the sidecar is stale. Embedding sends redacted indexed session text to the NAS and uses its model resources; lexical search remains available without the sidecar. Check `deja doctor` first: exclusions do not remove sessions already indexed, and rebuilding the index can drop sessions whose source transcripts no longer exist.
- `claude-code/langfuse/` — pinned upstream Langfuse Claude Code plugin (Stop/SessionEnd hooks) run with a Nix Python carrying langfuse 4.15.2. It reads `LANGFUSE_*` from the `opencode-langfuse-env` SOPS template sourced into zsh by `opencode/default.nix`, so only sessions started from an interactive zsh are traced.

## Stack

| Component             | Tool                                         | Configuration Location                                                                                             |
| --------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Harness root          | Desktop harness import                       | `default.nix`                                                                                                      |
| MCP wiring            | User-session MCP servers and client exposure | `mcp.nix`                                                                                                          |
| Agent runtime surface | OpenCode                                     | `opencode/default.nix`                                                                                             |
| Agent families        | Knowledge, Logging                           | `opencode/agents/knowledge/`, `opencode/agents/logging/`                                                           |
| Agent-local skills    | Family-specific skills                       | `opencode/agents/*/skills/`                                                                                        |
| Custom tool plugins   | RTK, other OpenCode tools                    | `opencode/tools/`, `opencode/tools/rtk/`                                                                           |
| Context trimming      | RTK read/context reduction tool              | `opencode/tools/rtk/`                                                                                              |

## Layout Notes

- `opencode/agents/` contains agent definitions grouped by role or operating mode.
- `opencode/agents/*/skills/` contains skills that belong to a specific agent family.
- `opencode/skills/` contains shared OpenCode skills available across agents.
- `opencode/tools/` contains custom OpenCode tool plugins packaged for the user session.

RLM-related behavior is surfaced through the harness and OpenCode tooling rather than a separate top-level user area. Recursive language-model execution and CLI multiplexing for the desktop are represented here through the relevant tool or module files.
