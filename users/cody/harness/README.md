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
- OpenCode and Claude Code use the shared QMD MCP connection. On other hosts it starts QMD over SSH on the NAS, using the same index and GPU backend as Hermes; NAS sessions run QMD locally. SSH requires noninteractive access to the NAS.
- OpenCode's Déjà auto-recall hooks are disabled; on-demand searches use the shared MCP server. Déjà uses the NAS llama-swap embedding model for semantic search. Run `deja embed` on each host after activation to create its local vector sidecar, and rerun it when Déjà reports the sidecar is stale. Embedding sends redacted indexed session text to the NAS and uses its model resources; lexical search remains available without the sidecar. Check `deja doctor` first: exclusions do not remove sessions already indexed, and rebuilding the index can drop sessions whose source transcripts no longer exist.
- Herdr: `herdr-core` (`hc`) is installed on every host from the `llm-agents` pin; the desktop profile adds `herdr-app`. The NAS core holds always-on agent terminals, and Beast's app adds it as an SSH machine. The core starts itself as a systemd user unit on first connect, relying on NAS linger. Keep both ends on the same pin and never use `hc machine add --install`. After an `update` changes the version, run `hc server restart` on the NAS; running terminals survive. The `hc --skill` agent instructions are not wired into any harness yet.
- `claude-code/langfuse/` — pinned upstream Langfuse Claude Code plugin (Stop/SessionEnd hooks) run with a Nix Python carrying langfuse 4.15.2. It reads `LANGFUSE_*` from the `opencode-langfuse-env` SOPS template sourced into zsh by `opencode/default.nix`, so only sessions started from an interactive zsh are traced.
- Pi loads the official Langfuse extension (0.1.2) globally. Home Manager installs its npm dependencies on first activation, requiring network access; it reuses the same zsh-sourced credentials. The extension sends prompts, model output, reasoning, tool activity, and images to Langfuse. Set `LANGFUSE_TRACING_ENABLED=false` to disable tracing for a run.

## Stack

| Component             | Tool                                         | Configuration Location                                                                                             |
| --------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Harness root          | Desktop harness import                       | `default.nix`                                                                                                      |
| MCP wiring            | User-session MCP servers and client exposure | `mcp.nix`                                                                                                          |
| Agent runtime surface | OpenCode                                     | `opencode/default.nix`                                                                                             |
| Knowledge and logging | Karakeep, Grafana and QMD MCP servers        | `mcp.nix`                                                                                                          |
| Custom tool plugins   | RTK, other OpenCode tools                    | `opencode/tools/`, `opencode/tools/rtk/`                                                                           |
| Context trimming      | RTK read/context reduction tool              | `opencode/tools/rtk/`                                                                                              |

## Layout Notes

- `opencode/agents/` contains agent definitions grouped by role or operating mode.
- `opencode/agents/*/skills/` contains skills that belong to a specific agent family.
- `opencode/skills/` contains shared OpenCode skills available across agents.
- `opencode/tools/` contains custom OpenCode tool plugins packaged for the user session.

RLM-related behavior is surfaced through the harness and OpenCode tooling rather than a separate top-level user area. Recursive language-model execution and CLI multiplexing for the desktop are represented here through the relevant tool or module files.
