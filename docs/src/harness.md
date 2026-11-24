# AI coding tools

Claude Code, OpenCode, Codex and Pi run on both hosts with one shared set of MCP servers, skills and memory. The NAS also serves OpenCode at [opencode.homehub.tv](https://opencode.homehub.tv).

## Starting a client

On beast, open **OpenCode** from the app launcher for the local desktop app.

| Command | Starts |
| --- | --- |
| `claude` | Claude Code |
| `op` | OpenCode on this host |
| `op-` | OpenCode attached to the NAS server, already authenticated |
| `codex`, `pi` | Codex, Pi |

Commands that an agent runs appear prefixed with `rtk`, which shortens long output. OpenCode never updates itself; new versions arrive with `update`.

## Shared agent runtime

OpenCode, Claude Code, and Pi share a Nix-managed runtime for agent commands on both hosts. It provides Bash, Python, Node.js, and common command-line tools independently of the login shell. Fix a missing or broken baseline tool in the shared runtime rather than in each harness.

The runtime loads the approved `.envrc` for each command's working directory. Project tools take precedence over the shared defaults. Codex runs outside the shared runtime and uses `direnv exec` to enter project environments.

If direnv blocks a file, review and approve it on the host where the agent runs. Then retry the command.

## Shared tools

All clients share these MCP servers: `deja` (past sessions), `hindsight` (memory), `qmd` (your Markdown notes), `karakeep` (bookmarks), `exa` (web), `context7` (library docs), `gh_grep` (GitHub code), `nixos-option-search`. On beast, `qmd` runs on the NAS and fails when the NAS is unreachable; the others keep working.

For semantic search across past sessions, run `deja doctor` on each host, then run `deja embed` if the vector index is missing or stale. Embedding sends redacted session text to the NAS. Search by exact terms still works without embeddings.

## Browse on beast

`op` on beast can use your Chromium profile through Browse. `op-` runs on the NAS and doesn't have access to it. After `update`, add [Browse from the Chrome Web Store](https://chromewebstore.google.com/detail/mfnicocicmmlkpjnaffgihfjhdgjkdjg) in the profile you want to use. Run `browse pair`, then enter the code under **Browse → Options → Pair with a code**. Run `browse status` to check the connection.

Browse uses the sites you're already signed in to. It works in tabs it opens or tabs you lend it from the toolbar.

## Herdr

In Herdr on beast, add the NAS under *Settings → Machines* to open its agent terminals over SSH. After `update` changes Herdr, run `hc server restart` on the NAS. Running terminals survive the restart.

## Memory

Claude Code and OpenCode add relevant memories before each prompt (not for prompts under five characters) and save each turn. Each repository has its own bank (`/etc/nixos` → `codyos`); `cody` holds what applies everywhere. To turn off one half in OpenCode, start it with `HINDSIGHT_AUTO_RECALL=false` or `HINDSIGHT_AUTO_RETAIN=false`. Calls are traced to [Langfuse](ai-tools.md).

For remote OpenCode, those flags go on the NAS server process, not on `op-`. Do not paste credentials into chat: automatic memory can include prompt and response text. Pi and Codex can use Hindsight through MCP but do not run the automatic memory hooks.

## Inbox

When an agent keeps running into something on the system, such as a missing tool or a recurring error, it posts a one-line note to the **#inbox** channel in Discord: what got in the way, where, the evidence, and the change that would remove it. The note ends with the agent and host that sent it. Hermes does not answer these notes. To hand one to Hermes, see [Have Hermes change CodyOS](hermes.md#have-hermes-change-codyos).

To post a note yourself, run `inbox "<note>"`.

## Changing it

`update` overwrites `~/.config/opencode` and the skill folders, so edit these files instead. All under [`modules/harness/_hm/`](../../modules/harness/_hm):

| To change | Edit |
| --- | --- |
| MCP servers | [`mcp.nix`](../../modules/harness/_hm/mcp.nix) |
| Skills | [`skills/default.nix`](../../modules/harness/_hm/skills/default.nix), or a folder in the [skill catalog](../../skills/) |
| Inbox command and when agents use it | [`inbox/`](../../modules/harness/_hm/inbox/default.nix) |
| Memory behavior, banks | [`plugins/hindsight/`](../../modules/harness/_hm/plugins/hindsight/default.nix) |
| Claude Code | [`claude-code/default.nix`](../../modules/harness/_hm/claude-code/default.nix) |
| OpenCode | [`opencode/default.nix`](../../modules/harness/_hm/opencode/default.nix) |
| Shared agent runtime and baseline tools | [`runtime.nix`](../../modules/harness/_hm/runtime.nix) |
| How agents enter project environments | [`context.nix`](../../modules/harness/_hm/context.nix) |
| OpenCode Desktop, the NAS server, `op-` | [`modules/ai/opencode.nix`](../../modules/ai/opencode.nix) |
