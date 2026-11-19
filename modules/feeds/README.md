# Feeds

The feed-reading stack on the NAS: Miniflux (RSS reader) and the miniflux-curator, a scheduled
oneshot that scores unread entries against embeddings of recent Karakeep bookmarks (via the
llama-swap embedding model) and marks low-relevance entries as read.

| File | Aspect | Owns |
| --- | --- | --- |
| `miniflux.nix` | `miniflux` (nas) | The Miniflux service on `localhost:7777`, its nginx vhost (`rss.<domain>`), admin credentials and API keys (SOPS), and the values for the curator (URLs, embedding model, `autoMarkReadBelow`, `limitUnread`, `dryRun`, `schedule`). |
| `miniflux-curator.nix` | `miniflux-curator` (nas) | The reusable curator module: the `services.miniflux-curator.*` options, the `miniflux-curator` oneshot service (scheduled with `startAt`), its system user and `/var/lib/miniflux-curator` state directory. |

## Operations

```bash
systemctl list-timers miniflux-curator.timer   # next/last run
systemctl start miniflux-curator               # run now
systemctl status miniflux-curator
journalctl -u miniflux-curator -f              # logs
systemctl reset-failed miniflux-curator        # after start-limit-hit
```

Set `dryRun = true` in `miniflux.nix` to log what the curator would do without changing entries.
Secrets are SOPS entries declared next to their consumer in `miniflux.nix`
(`miniflux/ADMIN_USERNAME`, `miniflux/ADMIN_PASSWORD`, `miniflux/API_KEY`, `karakeep-api-key`;
quote dashed names). The curator's state file is `/var/lib/miniflux-curator/state.json`.

See `AGENTS.md` for placement rules and failure modes of scheduled jobs.
