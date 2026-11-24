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

## Sorted bookmarks

Every hour the NAS files new bookmarks in Karakeep, newest first, once Karakeep has summarized them. It adds tags and list entries and never removes any.

| In Karakeep | Means |
| --- | --- |
| `ai-topic:<name>` tag | The bookmark's topic. Topics are named by `qwen-3.5-9b` when they are first opened and keep their names. |
| `ai-duplicate` tag | Nearly the same as an older bookmark. |
| `ai-svc:<service>` tag and *Agency: \<service\>* list | Worth inspecting for that Agency service. |
| `ai-kind:method` / `ai-kind:capability` tag | Teaches a method / is something to install or call. |
| *CodyOS: candidates* list | Shows something CodyOS could adopt or adapt and what it would improve. Review candidates before adopting them. |

`svc:` and `svc-kind:` tags are different: a harvest agent put them there after reading the source.

The `ai-svc`, `ai-kind` and CodyOS answers come from the [local classifiers](ai-tools.md#local-classifiers). Where Vega is unsure, the bookmark's title, link and summary go to Jev on OpenCode Go. On weekdays from 8 am to 5 pm a run sorts at most 50 bookmarks, otherwise 400, so the first pass over the whole collection takes about a night. A bookmark that is not tagged yet is still waiting.

On the NAS, `sudo systemctl start karakeep-triage` runs it now, and `journalctl -u karakeep-triage` shows each run.

## Changing it

| To change | Edit |
| --- | --- |
| How strict the curator is (`autoMarkReadBelow`: higher marks more as read) | [`miniflux.nix`](../../modules/feeds/miniflux.nix) |
| Try the curator without marking (`dryRun = true`) | [`miniflux.nix`](../../modules/feeds/miniflux.nix) |
| Curator schedule and limits | [`miniflux.nix`](../../modules/feeds/miniflux.nix) |
| Karakeep and its models | [`karakeep.nix`](../../modules/web/karakeep.nix) |
| Bookmark sorting: schedule and per-run limits | [`karakeep-triage.nix`](../../modules/feeds/karakeep-triage.nix) |
| The questions the classifiers ask | [`_nas-classifiers.nix`](../../modules/ai/llama-swap/_nas-classifiers.nix) |

Curator source: [Cody-W-Tucker/miniflux-curator](https://github.com/Cody-W-Tucker/miniflux-curator).
