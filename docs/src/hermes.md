# Hermes

Hermes starts when the NAS boots and runs as its own system user. On beast, use [the Waybar voice button](speech.md#talking-to-hermes) for a spoken conversation.

## Open the dashboard

Join Tailscale and open [the Hermes dashboard](http://nas:9119). Hermes saves and recalls memories in the `cody` bank. Open [Hindsight](ai-tools.md) to browse them.

When Hermes Desktop is connected to the NAS, the microphone button sends audio to Hermes on the NAS for transcription. The desktop does not have to connect to the speech service separately.

Cron results and cross-platform messages go to the `#hermes-home` Discord channel and your Telegram DM. These home channels are set in Nix; `/sethome` does not last past the next activation.

## Apply a configuration change

Make changes to Nix-managed settings in Nix. Activation restores those settings and preserves settings Hermes manages, including skill toggles. Check the service on the NAS with `systemctl status hermes-agent hermes-backend` and its log with `journalctl -u hermes-agent`.

If you remove a key from Nix, remove it from the live configuration too. Activation does not delete keys omitted from Nix.

After rotating a Hermes secret and applying the new configuration, restart the affected system unit if needed: `sudo systemctl restart hermes-agent` for agent credentials or `sudo systemctl restart hermes-backend` for the dashboard.

## Have Hermes change CodyOS

Ask Hermes for a CodyOS change, for example by @mentioning it in reply to an [inbox](harness.md#inbox) note. Hermes cannot edit `/etc/nixos` or rebuild the system. It works in its own clone at `/var/lib/hermes/workspace/codyos`. The clone fetches from the NAS's `/etc/nixos`, so a branch starts from what the NAS last deployed: run `update --nas` first if the change builds on newer commits. Hermes makes one `inbox/<slug>` branch per request, commits there, and replies with the branch, what it checked, and what it could not check.

To review and take a branch on beast:

```bash
cd /etc/nixos
git fetch nas:/var/lib/hermes/workspace/codyos inbox/<slug>
git diff HEAD...FETCH_HEAD
git merge FETCH_HEAD
```

## What Hermes can reach

Hermes uses QMD to search your indexed notes; your home directory is not mounted in its terminal. The terminal has internet access, but ordinary SSH on port 22 and connections to private-network addresses are blocked except for the services configured for Hermes. Use `nix eval --offline` for CodyOS checks.

Once Google Workspace is authorized, ask Hermes to triage your inbox, reply to a message or add an event. Put attachments in its workspace. In the private secrets repo, open `sops edit secrets/hermes-gws.yaml`. Add the JSON from `gws auth export --unmasked` as a YAML block string under `oauth: |-`, indenting every JSON line by two spaces. Use a `gws` login with only the scopes you want Hermes to have, and keep the export out of terminal output and chat. Follow [the secret update steps](secrets.md#add-or-change-a-secret) to publish the encrypted file and update the NAS's lock. A login on your own account does not sign Hermes in.

The long-lived credential stays outside Hermes. `gws` in the terminal uses a short-lived access token; any command in that terminal can read it while it is valid. If `gws` reports no access token and `systemctl status hermes-gws-token.timer` says the unit is missing, finish enrollment above. If the timer exists, check `journalctl -u hermes-gws-token` for refresh errors.

To check Gmail access without sending anything, ask Hermes to run `gws gmail users labels list --params '{"userId":"me"}'` in its terminal. A successful token refresh alone does not verify that the terminal can use Gmail.

## Manage skills

Open **Skills** in the Hermes dashboard, or enter `/skills` in a chat. Install and enable skills in Hermes; a CodyOS update does not reinstall them.

To start the default profile with only CodyOS tool skills, use the starter files after the NAS update. Stop Hermes before moving its skill library. This keeps a copy of the old library and leaves chats, memory, and named profiles alone. Scheduled jobs that reference an archived skill need that skill restored before they can use it again.

```bash
sudo systemctl stop hermes-agent hermes-backend
sudo -u hermes bash -eu -c '
  cd /var/lib/hermes/.hermes
  for pack in cli deja google-workspace; do
    test -d "/etc/hermes/starter-skills/$pack"
  done
  archive=$(mktemp -d ./skills-backup.XXXXXXXX)
  install -d -m 2770 "$archive/starter"
  cp -rL --no-preserve=mode,ownership /etc/hermes/starter-skills/*/. "$archive/starter/"
  if [ -d skills ]; then mv -- skills "$archive/"; fi
  mv -- "$archive/starter" skills
  touch .no-bundled-skills
'
```

If the copy succeeds, start `hermes-agent` and `hermes-backend` again. Open **Skills** to check the starter list. Hermes can also include its own essential skills.

## Changing it

| To change | Edit |
| --- | --- |
| Service settings | [`_nixos/default.nix`](../../modules/ai/hermes-agent/_nixos/default.nix) |
| Memory provider settings | [`plugins/hindsight/default.nix`](../../modules/ai/hermes-agent/_nixos/plugins/hindsight/default.nix) |
| MCP tools | [`mcp/default.nix`](../../modules/ai/hermes-agent/_nixos/mcp/default.nix) |
| Instructions for working on CodyOS | [`documents/default.nix`](../../modules/ai/hermes-agent/_nixos/documents/default.nix) |
| Terminal filesystem and network access | [`plugins/bubblewrap/default.nix`](../../modules/ai/hermes-agent/_nixos/plugins/bubblewrap/default.nix), [`egress/default.nix`](../../modules/ai/hermes-agent/_nixos/egress/default.nix) |
| Google Workspace token refresh | [`_gws-token/`](../../modules/ai/_gws-token) |
| Secrets | [`secrets/default.nix`](../../modules/ai/hermes-agent/_nixos/secrets/default.nix) |
| Per-platform tool access | [`toolsets/`](../../modules/ai/hermes-agent/_nixos/toolsets) |
