# AI coding tools

Claude Code, OpenCode, Codex and Pi run on both hosts with one shared set of MCP servers, skills and memory. The NAS also serves OpenCode at [opencode.homehub.tv](https://opencode.homehub.tv).

## Starting a client

| Command | Starts |
| --- | --- |
| `claude` | Claude Code |
| `op` | OpenCode on this host |
| `op-` | OpenCode attached to the NAS server, already authenticated |
| `codex`, `pi` | Codex, Pi |

Commands that an agent runs appear prefixed with `rtk`, which shortens long output. OpenCode never updates itself; new versions arrive with `update`.

## Shared tools

Every client sees the same MCP servers: `deja` (past sessions), `hindsight` (memory), `qmd` (your Markdown notes), `karakeep` (bookmarks), `exa` (web), `context7` (library docs), `gh_grep` (GitHub code), `nixos-option-search`. On beast, `qmd` runs on the NAS and fails when the NAS is unreachable; the others keep working.

After `update`, run `deja embed` on each host so that new sessions are searchable.

## Memory

Claude Code and OpenCode add relevant memories before each prompt (not for prompts under five characters) and save each turn. Each repository has its own bank (`/etc/nixos` → `codyos`); `cody` holds what applies everywhere. To turn off one half in OpenCode, start it with `HINDSIGHT_AUTO_RECALL=false` or `HINDSIGHT_AUTO_RETAIN=false`. Calls are traced to [Langfuse](ai-tools.md).

## Changing it

`update` overwrites `~/.config/opencode` and the skill folders, so edit these files instead. All under [`modules/harness/_hm/`](../../modules/harness/_hm):

| To change | Edit |
| --- | --- |
| MCP servers | [`mcp.nix`](../../modules/harness/_hm/mcp.nix) |
| Skills | [`skills/default.nix`](../../modules/harness/_hm/skills/default.nix), or a folder in [`skills/`](../../skills/README.md) |
| Memory behavior, banks | [`plugins/hindsight/`](../../modules/harness/_hm/plugins/hindsight/default.nix) |
| Claude Code | [`claude-code/default.nix`](../../modules/harness/_hm/claude-code/default.nix) |
| OpenCode | [`opencode/default.nix`](../../modules/harness/_hm/opencode/default.nix) |
| The NAS OpenCode server, `op-` | [`modules/ai/opencode.nix`](../../modules/ai/opencode.nix) |
