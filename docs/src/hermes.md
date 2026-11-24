# Hermes

Hermes runs on the NAS and stays up when you log out. On beast, use [the Waybar voice button](speech.md#talking-to-hermes) for a spoken conversation.

## Open the dashboard

Join Tailscale and open [the Hermes dashboard](http://nas:9119). Hermes saves and recalls memories in the `cody` bank. Open [Hindsight](ai-tools.md) to browse them.

Cron results and cross-platform messages go to the `#hermes-home` Discord channel and your Telegram DM. These home channels are set in Nix; `/sethome` does not last past the next activation.

## Apply a configuration change

Make lasting settings changes in Nix. The next activation replaces edits made through `hermes config set` or the dashboard. If Hermes is still using old settings after activation, run `systemctl --user restart hermes-agent` on the NAS as `codyt`. Check the user journal with `journalctl --user -u hermes-agent`.

After rotating a Hermes secret and applying the new configuration, restart the affected user unit so it reads the new value: `hermes-agent` for agent credentials or `hermes-backend` for the dashboard.

## Have Hermes change CodyOS

Ask Hermes for a CodyOS change, for example by @mentioning it in reply to an [inbox](harness.md#inbox) note. Hermes cannot edit `/etc/nixos` or rebuild. It works in its own clone at `~/Projects/codyos`, with no network. The clone fetches from the NAS's `/etc/nixos`, so a branch starts from what the NAS last deployed: run `update --nas` first if the change builds on newer commits. Hermes makes one `inbox/<slug>` branch per request, commits there, and replies with the branch, what it checked, and what it could not check.

`~/Projects` is the same folder on beast. To review and take a branch on beast:

```bash
cd /etc/nixos
git fetch ~/Projects/codyos inbox/<slug>
git diff HEAD...FETCH_HEAD
git merge FETCH_HEAD
```

## Changing it

| To change | Edit |
| --- | --- |
| Service settings | [`_hm/default.nix`](../../modules/ai/hermes-agent/_hm/default.nix) |
| Memory provider settings | [`plugins/hindsight/default.nix`](../../modules/ai/hermes-agent/_hm/plugins/hindsight/default.nix) |
| MCP tools | [`mcp/default.nix`](../../modules/ai/hermes-agent/_hm/mcp/default.nix) |
| Instructions for working on CodyOS | [`documents/default.nix`](../../modules/ai/hermes-agent/_hm/documents/default.nix) |
| Folders Hermes can read or write | [`plugins/bubblewrap/default.nix`](../../modules/ai/hermes-agent/_hm/plugins/bubblewrap/default.nix) |
| Secrets | [`secrets/default.nix`](../../modules/ai/hermes-agent/_hm/secrets/default.nix) |
| Installed skills or per-platform tool access | [`skills/`](../../modules/ai/hermes-agent/_hm/skills), [`toolsets/`](../../modules/ai/hermes-agent/_hm/toolsets) |
