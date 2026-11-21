# Web apps

The NAS's web apps, each at `https://<name>.homehub.tv` with a valid certificate. The names resolve for any device that uses the NAS as its DNS server, at home or over Tailscale.

## Apps

| App | URL | Purpose |
| --- | --- | --- |
| Homepage | [homehub.tv](https://homehub.tv) | Dashboard: app links, NAS CPU, memory, temperature, disk, weather |
| Karakeep | [karakeep.homehub.tv](https://karakeep.homehub.tv) | Bookmarks; a local-LLM summary and tags appear shortly after saving |
| Miniflux | [rss.homehub.tv](https://rss.homehub.tv) | RSS. See [Feeds and bookmarks](feeds-and-bookmarks.md). |
| Mealie | [mealie.homehub.tv](https://mealie.homehub.tv) | Recipes (no Homepage card) |
| Actual Budget | [budget.homehub.tv](https://budget.homehub.tv) | Budget |
| Dawarich | [tracker.homehub.tv](https://tracker.homehub.tv) | Location history |
| Home Assistant | [home-assistant.homehub.tv](https://home-assistant.homehub.tv) | Home automation |
| Music Assistant | [music-assistant.homehub.tv](https://music-assistant.homehub.tv) | Music players |
| Excalidraw | [draw.homehub.tv](https://draw.homehub.tv) | Whiteboard |
| Immich | [photos.homehub.tv](https://photos.homehub.tv) | Photos and video |

Each app has its own accounts. Karakeep has sign-ups disabled (`DISABLE_SIGNUPS`).

Devices that use the NAS as their DNS server get ad and malware domains blocked (StevenBlack list): those names do not resolve.

## Changing it

| To change | Edit |
| --- | --- |
| Add an app | A new file in [`modules/web/`](../../modules/web); include its aspect in [`nas.nix`](../../modules/hosts/nas.nix). The file declares its own vhost and Homepage card. |
| Homepage layout and widgets | [`homepage.nix`](../../modules/web/homepage.nix) |
| An app, its vhost or its card | The app's file, for example [`karakeep.nix`](../../modules/web/karakeep.nix) |
| Unbound, blocklist, local zone | [`dns.nix`](../../modules/networking/dns.nix) |
| ACME, kTLS, `mkNginxVhost` | [`nginx.nix`](../../modules/web/nginx.nix) |
