# Feeds and bookmarks

RSS in Miniflux, bookmarks in Karakeep. At 07:15 and 23:15 a curator compares new articles with your bookmarks and marks the unrelated ones as read.

## Reading and saving

| URL | Use |
| --- | --- |
| [rss.homehub.tv](https://rss.homehub.tv) | Miniflux: subscribe and read. Articles the curator dismissed are under *Read*. Old read entries are cleaned up every 48 h. |
| [karakeep.homehub.tv](https://karakeep.homehub.tv) | Karakeep: save links. A summary and tags appear shortly after saving; images get descriptions. |

The AI work runs on the NAS's graphics card.

| What happens | Done by |
| --- | --- |
| Karakeep summary and tags | `qwen-3.5-9b` |
| Karakeep image descriptions | `qwen-3.5-4b` |
| The curator's comparison | `qwen3-embedding-0.6b` |

The curator compares each unread article with your bookmarks. Topics you bookmark stay unread; topics you never bookmark are marked read.

## Check or run the curator

On the NAS, run `systemctl list-timers miniflux-curator.timer` to see its last and next runs. Run `sudo systemctl start miniflux-curator.service` to score unread articles now. Read the result with `journalctl -u miniflux-curator.service`. With `dryRun` on, the journal shows what the curator would mark without changing article status.

## Changing it

| To change | Edit |
| --- | --- |
| How strict the curator is (`autoMarkReadBelow`: higher marks more as read) | [`miniflux.nix`](../../modules/feeds/miniflux.nix) |
| Try the curator without marking (`dryRun = true`) | [`miniflux.nix`](../../modules/feeds/miniflux.nix) |
| Curator schedule and limits | [`miniflux.nix`](../../modules/feeds/miniflux.nix) |
| Karakeep and its models | [`karakeep.nix`](../../modules/web/karakeep.nix) |

Curator source: [Cody-W-Tucker/miniflux-curator](https://github.com/Cody-W-Tucker/miniflux-curator).
