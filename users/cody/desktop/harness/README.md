# Cody Desktop Harness

This subtree owns Cody's user-session AI/operator harness: OpenCode configuration, Herdr, MCP wiring, local tools, and agent/skill packaging used from the desktop.

Central docs should point here for harness implementation detail.

## Entry Points

- `default.nix` — harness import root for the desktop profile.
- `mcp.nix` — user-session MCP server/client wiring.
- `herdr/default.nix` — Herdr user configuration and theme integration.
- `herdr/module.nix` — local Herdr module logic.
- `opencode/default.nix` — OpenCode user harness root.

## OpenCode Layout

Primary directories:

- `opencode/agents/` — agent definitions grouped by role or operating mode.
- `opencode/agents/*/skills/` — skills that belong to a specific agent family.
- `opencode/skills/` — shared OpenCode skills available across agents.
- `opencode/tools/` — custom OpenCode tool plugins packaged for the user session.

Current notable pieces:

- `opencode/agents/business/` — business/operator agent configuration and its task, CRM, and Google Workspace skills.
- `opencode/agents/knowledge/` — knowledge/Obsidian-oriented agent configuration and QMD/Obsidian skills.
- `opencode/agents/logging/` — logging-oriented agent configuration.
- `opencode/agents/verify-alignment/` — alignment/review agent configuration.
- `opencode/skills/agent-browser/` — browser automation skill packaging.
- `opencode/skills/cognitive/` — local cognitive/decision-support skill packaging.
- `opencode/skills/humanizer/` — writing cleanup skill packaging.
- `opencode/tools/voice/` — TTS/status voice plugin.
- `opencode/tools/model-router/` — model routing plugin/configuration.
- `opencode/tools/rtk/` — read/context trimming tool plugin used to keep long tool results operator-sized.

## Herdr and RLM

Herdr is the terminal-native launcher/multiplexer for agent work. Keep its theme and behavior close to `herdr/default.nix`; keep reusable module behavior in `herdr/module.nix`.

RLM-related behavior is surfaced through the harness and OpenCode tooling rather than a separate top-level user area. If a change affects model routing, recursive language-model execution, or CLI multiplexing from the desktop, start here and then follow the specific tool/module file.

## MCP

`mcp.nix` owns MCP wiring for Cody's user harness. Keep server definitions and client exposure there unless a server belongs entirely to one packaged skill or tool.

When adding a server:

- Keep secrets out of the repo; use SOPS or existing secret plumbing.
- Prefer stable command names and explicit packages.
- Document the operator-facing purpose here if it changes how agents are run.

## Tool and Skill Rules

- Put OpenCode plugin implementation files beside their Nix packaging (`plugin.ts` next to `default.nix`).
- Keep agent-specific skills under that agent when they are not generally reusable.
- Promote a skill to `opencode/skills/` only when multiple agents should share it.
- Avoid hiding long shell fragments in Nix strings when a script/tool file would be clearer.
- Keep tool names CLI-safe and lowercase kebab-case.

## Change Checklist

- Touch `users/cody/README.md` only for user/desktop-level behavior; keep harness internals documented here.
- Update central `docs/OpenCode-*` or `docs/Herdr-*` pages only as short pointers.
- Verify module imports when adding a new agent, tool, or skill.
- Add new files to git before expecting the flake to include them.
