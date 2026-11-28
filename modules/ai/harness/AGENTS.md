# Agent Harness

`den.aspects.harness` is the user-session AI harness every host gets: OpenCode, Claude Code, Codex, Pi, their shared context, shell, skills, plugins and MCP servers. It is one aspect spread over this directory; each file owns one concern and contributes `homeManager` settings directly. `harness.nix` adds it to `den.default.includes` once.

- `harness.nix`: extra agent CLIs, shared context, Claude Code and Codex, and `codyos.harness.claudePlugins`.
- `runtime.nix`: the agent shell (direnv-aware Bash with a baseline PATH) for OpenCode, Claude Code and, through OpenCode's setting, Pi.
- `opencode.nix`: everything OpenCode. Shared settings on `harness`, the NAS web server (`opencode`), Beast's remote alias (`opencode.remote`) and desktop app plus browse MCP (`opencode.desktop`).
- `pi.nix`, `deja.nix`, `inbox.nix`, `plugins.nix` (rtk, no-comments): one tool each, with its skill and MCP entry.
- `mcp.nix`: MCP servers that belong to no single tool here.
- `skills.nix`: `codyos.harness.skills`, which fans each skill out to Claude Code and `~/.agents/skills`.

Clients of NAS services live with the service and join the harness from there: `../hindsight/client.nix` and `../langfuse/client.nix` add `hindsight.client` and `langfuse.client` to `harness.includes`.

## Placement Rules

- Manage agents, skills, tools and configuration here. Do not edit `~/.config/opencode` or `~/.claude` directly.
- A tool brings its own skill, MCP entry, plugin and secrets in its own file. Set Home Manager options (`programs.opencode.*`, `programs.claude-code.*`, `programs.mcp.servers`) directly; the only registries are `codyos.harness.skills` (one skill, two harness locations) and `codyos.harness.claudePlugins` (stable Home Manager takes plugins only as a list).
- Read host facts through Den's `host` argument (`host.localAi`, `host.channel`), not import-time wrappers.
- Keep secrets out of this tree; use SOPS.

## Failure Modes

- Adding a file without tracking it, so the flake cannot see it.
- Defining the same MCP server in two files instead of in the tool or service file that owns it.
- Hiding long shell behavior inside Nix strings when a script or plugin file would be clearer.
- Renaming command names, skill paths or tool names that existing agents reference.
