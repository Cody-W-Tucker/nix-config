# Hermes assistant

Hermes is the always-on assistant on the NAS. Voice, Telegram, Discord, the dashboard and the CLI all reach the same agent, with the same tools and memory.

## Reaching it

| Channel | Access |
| --- | --- |
| Voice (beast) | Waybar voice button; replies are spoken in a sentence or two. See [Speech](speech.md). |
| Telegram | Direct message to the bot |
| Discord | Mention the bot; it replies in a thread, and only when mentioned. A reaction shows that it is working. |
| Dashboard | `http://nas:9119` over Tailscale, with basic auth |
| CLI | `hermes` on the NAS |

If the voice button is stuck, run `hermes-waybar-repair` on beast.

## What it does

Hermes searches and reads the web, drives a browser, runs commands, schedules jobs, reads images, delegates to sub-agents, and uses Home Assistant, Mealie, Karakeep, your notes (qmd), past sessions (deja) and Google Workspace. Long tasks end with a short report of what changed and what is open.

The main model is hosted. Web-page extraction, conversation titles and other background tasks run on the NAS's own models, as does the voice button.

Its commands run in a sandbox that sees `~/hermes-workspace`, `/etc/nixos` and `~/Projects`; the rest of `$HOME` is hidden.

## Changing it

Settings changed in the dashboard, with `hermes config set` or `hermes mcp add` are lost at the next switch. Change them in Nix. To apply a change without a rebuild, run `systemctl --user restart hermes-agent` on the NAS.

All in [`modules/ai/hermes-agent/`](../../modules/ai/hermes-agent):

| To change | Edit |
| --- | --- |
| Model, Discord, Telegram | [`_hm/default.nix`](../../modules/ai/hermes-agent/_hm/default.nix) |
| Tools per channel | [`_hm/toolsets/platform-toolsets.nix`](../../modules/ai/hermes-agent/_hm/toolsets/platform-toolsets.nix) |
| Sandbox paths | [`_hm/plugins/bubblewrap/default.nix`](../../modules/ai/hermes-agent/_hm/plugins/bubblewrap/default.nix) |
| Skills | [`_hm/skills/`](../../modules/ai/hermes-agent/_hm/skills) |
| MCP servers | [`_hm/mcp/default.nix`](../../modules/ai/hermes-agent/_hm/mcp/default.nix) |
| What Hermes knows about you | [`_hm/documents/default.nix`](../../modules/ai/hermes-agent/_hm/documents/default.nix) |
| Voice button | [`_voice/client.nix`](../../modules/ai/hermes-agent/_voice/client.nix) |
