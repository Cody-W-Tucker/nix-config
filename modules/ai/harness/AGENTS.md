# Agent Harness

`den.aspects.harness` is the user-session AI harness every host gets: OpenCode, Claude Code, Codex, Pi, their shared context, shell, skills, plugins and MCP servers. It is one aspect spread over this directory; each file owns one concern and contributes `homeManager` settings directly. `harness.nix` adds it to `den.default.includes` once.

- `harness.nix`: extra agent CLIs, Claude Code and Codex, and which context each agent reads. The prose lives in `context/*.md`.
- `runtime.nix`: how the agents run. The agent shell (direnv-aware Bash with a baseline PATH), rtk's command rewriting, and the OpenCode, Claude Code and Pi packages, which source `codyos.harness.agentEnvFiles` so secrets reach those three and nothing else.
- `compat.nix`: every bridge for the NAS's stable Home Manager, behind one workaround entry. Delete it when the NAS's channel catches up.
- `opencode.nix`: everything OpenCode. Shared settings on `harness`, the NAS web server (`opencode.web`), Beast's remote alias (`opencode.remote`) and desktop app plus browse MCP (`opencode.desktop`).
- `pi.nix`, `deja.nix`, `inbox.nix`, `no-comments.nix`: one tool each, with its skill and MCP entry.
- `mcp.nix`: MCP servers that belong to no single tool here.
- `skills.nix`: `codyos.harness.skills`, which fans each skill out to Claude Code and `~/.agents/skills`.

Clients of NAS services live with the service and join the harness from there: `../hindsight/client.nix` and `../langfuse/client.nix` add `hindsight.client` and `langfuse.client` to `harness.includes`.

## Rules

- Manage agents, skills, tools and configuration here. Do not edit `~/.config/opencode` or `~/.claude` directly.
- A tool brings its own skill, MCP entry, plugin and secrets in its own file. Set Home Manager options (`programs.opencode.*`, `programs.claude-code.*`, `programs.mcp.servers`) directly; the only harness options are `codyos.harness.skills` (one skill, two harness locations), `codyos.harness.agentEnvFiles` (secret env for the agents) and `codyos.harness.claudePlugins` (in `compat.nix`, because stable Home Manager takes plugins only as a list).
- `codyos.harness.skills` carries coding skills only. Skills for personal-assistant tools such as Google Workspace and the CRM ship to Hermes alone, as starter skills under `/etc/hermes/starter-skills`, even when the tool's CLI is also installed for Cody.
- An agent-only secret goes in `codyos.harness.agentEnvFiles`, never a shell profile.
- Define each MCP server once, in the file of the tool or service that owns it.
- Keep long shell behavior and agent prose in script or Markdown files, not Nix strings.
- Do not rename commands, skill paths or tool names that existing agents reference.
