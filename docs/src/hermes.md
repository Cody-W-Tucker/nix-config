# Hermes

Hermes runs on the NAS and stays up when you log out. On beast, use [the Waybar voice button](speech.md#talking-to-hermes) for a spoken conversation.

## Open the dashboard

Join Tailscale and open [the Hermes dashboard](http://nas:9119). Hermes saves and recalls memories in the `cody` bank. Open [Hindsight](ai-tools.md) to browse them.

## Apply a configuration change

Make lasting settings changes in Nix. The next activation replaces edits made through `hermes config set` or the dashboard. If Hermes is still using old settings after activation, run `systemctl --user restart hermes-agent` on the NAS as `codyt`. Check the user journal with `journalctl --user -u hermes-agent`.

After rotating a Hermes secret and applying the new configuration, restart the affected user unit so it reads the new value: `hermes-agent` for agent credentials or `hermes-backend` for the dashboard.

## Changing it

| To change | Edit |
| --- | --- |
| Service settings | [`_hm/default.nix`](../../modules/ai/hermes-agent/_hm/default.nix) |
| Memory provider settings | [`plugins/hindsight/default.nix`](../../modules/ai/hermes-agent/_hm/plugins/hindsight/default.nix) |
| MCP tools | [`mcp/default.nix`](../../modules/ai/hermes-agent/_hm/mcp/default.nix) |
| Secrets | [`secrets/default.nix`](../../modules/ai/hermes-agent/_hm/secrets/default.nix) |
| Installed skills or per-platform tool access | [`skills/`](../../modules/ai/hermes-agent/_hm/skills), [`toolsets/`](../../modules/ai/hermes-agent/_hm/toolsets) |
