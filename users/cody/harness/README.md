# Cody Desktop Harness

This subtree owns Cody's user-session AI/operator harness: OpenCode configuration, MCP wiring, local tools, and agent/skill packaging used from the desktop.

Central docs should point here for harness implementation detail.

## Entry Points

- `default.nix` — harness import root for the desktop profile.
- `mcp.nix` — user-session MCP server/client wiring.
- `opencode/default.nix` — OpenCode user harness root.
- `claude-code/default.nix` — Claude Code user harness and shared MCP integration.
- `context.nix` — shared environment instructions.
- `plugins/default.nix` — shared plugins for OpenCode and Claude Code (`codyos.harness.plugins`), including `hindsight` (OpenCode 2 turn-end retain plugin + Claude Code Stop hook retaining to the project's Hindsight bank), `langfuse` (OpenCode 0.6.0 wrapper + pinned Claude Code 1.2.2 Stop/SessionEnd hook reading `LANGFUSE_*` from the zsh-sourced `opencode-langfuse-env` SOPS template), `rtk` (OpenCode plugin + Claude Code `PreToolUse` Bash rewrite hook + shared context), and `tokeneconomizer` (`pkgs.tokeneconomizer`).
- `skills/default.nix` — shared skills for every harness, including the deja-search, gnhf and no-mistakes skills from their pinned packages.
- `programs.mcp.servers` in `mcp.nix` is the one MCP list. Claude Code and OpenCode take it through `enableMcpIntegration`. Leave out `type`: each consumer derives it from `url`.
- Pi reads the same server list from `~/.pi/agent/mcp.json` and the shared instructions from `~/.pi/agent/AGENTS.md`. Home Manager manages these files; existing unmanaged files may need to be moved before activation. NAS imports the unstable Pi module until its stable Home Manager includes it.
- All harnesses use the shared QMD MCP connection. On other hosts it starts QMD over SSH on the NAS, using the same index and GPU backend as Hermes; NAS sessions run QMD locally. SSH requires noninteractive access to the NAS.
- OpenCode's Déjà auto-recall hooks are disabled; on-demand searches use the shared MCP server. Déjà uses the NAS llama-swap embedding model for semantic search. Run `deja embed` on each host after activation to create its local vector sidecar, and rerun it when Déjà reports the sidecar is stale. Embedding sends redacted indexed session text to the NAS and uses its model resources; lexical search remains available without the sidecar. Check `deja doctor` first: exclusions do not remove sessions already indexed, and rebuilding the index can drop sessions whose source transcripts no longer exist.
- Herdr: `herdr-core` (`hc`) is installed on every host from the `llm-agents` pin; the desktop profile adds `herdr-app`. The NAS core holds always-on agent terminals, and Beast's app adds it as an SSH machine. The core starts itself as a systemd user unit on first connect, relying on NAS linger. Keep both ends on the same pin and never use `hc machine add --install`. After an `update` changes the version, run `hc server restart` on the NAS; running terminals survive. The `hc --skill` agent instructions are not wired into any harness yet.
- Pi loads the official Langfuse extension (0.1.2) globally. Home Manager installs its npm dependencies on first activation, requiring network access; it reuses the same zsh-sourced credentials. The extension sends prompts, model output, reasoning, tool activity, and images to Langfuse. Set `LANGFUSE_TRACING_ENABLED=false` to disable tracing for a run.
- Hindsight auto-retain, RTK automatic command rewriting, and TokenEconomizer hooks are specific to OpenCode and Claude Code; they are not enabled in Pi. Hindsight remains available through MCP, and RTK and TokenEconomizer remain installed as commands.

## Stack

| Component             | Tool                                         | Configuration Location                                                                                             |
| --------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Harness root          | Desktop harness import                       | `default.nix`                                                                                                      |
| MCP wiring            | User-session MCP servers and client exposure | `mcp.nix`                                                                                                          |
| Agent runtime surface | OpenCode, Claude Code                        | `opencode/default.nix`, `claude-code/default.nix`                                                                  |
| Knowledge and logging | Karakeep and QMD MCP servers                 | `mcp.nix`                                                                                                          |
| Shared plugins        | Hindsight, Langfuse, RTK, TokenEconomizer    | `plugins/default.nix`, `plugins/hindsight/`, `plugins/langfuse/`, `plugins/rtk/`, `plugins/tokeneconomizer/`       |
| Shared skills         | Cognitive, Deja, GNHF, Humanizer, etc.       | `skills/default.nix`                                                                                               |

## Layout Notes

- `opencode/agents/` contains agent definitions grouped by role or operating mode.
- `opencode/agents/*/skills/` contains skills that belong to a specific agent family.
- `plugins/` contains shared plugins. Modules add entries to `codyos.harness.plugins`; `plugins/default.nix` wires them into OpenCode (`~/.config/opencode/plugins/` and `settings.plugins`), Claude Code (`programs.claude-code.plugins` and `settings.hooks`), `home.packages`, and shared context.
- `skills/` contains the shared skills. Modules add entries to `codyos.harness.skills`; `skills/default.nix` writes them to `~/.claude/skills` (Claude Code) and `~/.agents/skills` (Codex, Pi). OpenCode reads both directories.
- `opencode/tools/` contains OpenCode-only tool plugins packaged for the user session.

RLM-related behavior is surfaced through the harness and OpenCode tooling rather than a separate top-level user area. Recursive language-model execution and CLI multiplexing for the desktop are represented here through the relevant tool or module files.
