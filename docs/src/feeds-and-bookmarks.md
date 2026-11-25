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

Every hour the NAS files new bookmarks in Karakeep, newest first, once Karakeep has summarized them. It adds list entries and the `ai-route:unsure` tag, and never removes any. A bookmark Jev could not be reached for is tried again on a later run.

| In Karakeep | Means |
| --- | --- |
| *Agency: \<service\>* list | Most worth inspecting for that Agency service. |
| *CodyOS: candidates* list | Most worth inspecting for something CodyOS could adopt or adapt. Review candidates before adopting them. |
| `ai-route:unsure` tag | Jev was not confident where it belongs. |

`svc:` and `svc-kind:` tags are different: a harvest agent put them there after reading the source.

Each bookmark gets at most one of these lists; one that fits none gets neither. Bookmarks filed before November 25, 2026 may be in several lists and may carry `ai-kind:` tags from the earlier classifiers. `ai-topic:`, `ai-svc:` and `ai-duplicate` tags on older bookmarks are left over from before November 25, 2026; the lists replace them.

Every *Agency* list and *CodyOS: candidates* exists from the first run, even while empty. The lists are yours to curate: once you add a bookmark to a list or take one out, the next run teaches Vega the one list it is now in, or `none` if it is in none, as your own answer, and that bookmark is not sorted again. A bookmark in several lists teaches nothing until only one is left. Entries you leave alone teach nothing. The NAS never puts back a bookmark you took out, and the tags are not read back.

A bookmark tagged `ai-route:unsure` is one Jev answered without confidence, so it is in no list. These are the most useful ones to file by hand.

The list answers come from the [local classifiers](ai-tools.md#local-classifiers). Where Vega is unsure, the bookmark's title, link and summary go to Jev on OpenCode Go. On weekdays from 8 am to 5 pm a run sorts at most 50 bookmarks, otherwise 400, so the first pass over the whole collection takes about a night. A bookmark in no list and without `ai-route:unsure` fits none, or is still waiting.

On the NAS, `sudo systemctl start karakeep-triage` runs it now, and `journalctl -u karakeep-triage` shows each run, ending with how many bookmarks Vega routed on its own, how many went to Jev, how many Jev was unsure of, and how many could not reach Jev and wait for the next run.

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
