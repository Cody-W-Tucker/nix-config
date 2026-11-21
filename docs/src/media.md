# Media

Movies, TV, music, books and audiobooks on the NAS. A request in Seerr downloads through the VPN and lands in the matching library.

## Watch, listen, read

| To | Open |
| --- | --- |
| Watch movies and TV | [media.homehub.tv](https://media.homehub.tv) (Jellyfin) |
| Listen to music | [music.homehub.tv](https://music.homehub.tv) (Navidrome) |
| Listen to audiobooks and podcasts | [audiobooks.homehub.tv](https://audiobooks.homehub.tv) (Audiobookshelf) |
| Read books; sync a Kobo (point it at this URL) | [books.homehub.tv](https://books.homehub.tv) (Calibre-Web) |

## Get something new

| To | Open |
| --- | --- |
| Request a movie, show or book | [request.homehub.tv](https://request.homehub.tv) (Seerr) |
| Search and download an ebook or audiobook | [shelfmark.homehub.tv](https://shelfmark.homehub.tv) (Shelfmark). Audiobooks appear in Audiobookshelf. Ebooks wait in `/mnt/media/Downloads/Shelfmark` for manual import into Calibre. |

```mermaid
flowchart LR
    req["Request in Seerr"] --> arr["Radarr / Sonarr /<br/>Lidarr / Readarr"]
    arr --> dl["Transmission<br/>(through the VPN)"]
    dl --> app["Jellyfin, Navidrome, …"]
```

Downloads are throttled 08:00–23:00, Monday to Saturday. Torrents stop seeding at ratio 1.0 or after 30 idle minutes. Download status is on each automation app's page: [radarr](https://radarr.homehub.tv), [sonarr](https://sonarr.homehub.tv), [lidarr](https://lidarr.homehub.tv), [readarr](https://readarr.homehub.tv), [bazarr](https://bazarr.homehub.tv) (subtitles), [prowlarr](https://prowlarr.homehub.tv) (indexers). Transmission has no page of its own.

## Changing it

Which app handles which request, and the library paths, are set in each app's web UI. To address one app from another there, see [Networking and VPN](networking.md).

All in [`modules/media/`](../../modules/media):

| To change | Edit |
| --- | --- |
| Library folders | [`media.nix`](../../modules/media/media.nix) |
| Download schedule, limits, VPN | [`transmission.nix`](../../modules/media/transmission.nix) |
| Automation apps | [`arr-stack.nix`](../../modules/media/arr-stack.nix) |
| Shelfmark destinations | [`shelfmark.nix`](../../modules/media/shelfmark.nix) |
| One app | Its file, for example [`jellyfin.nix`](../../modules/media/jellyfin.nix) |
