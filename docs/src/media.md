# Media

The NAS hosts video, music, books, and audiobooks. Open these apps at home or over [Tailscale](networking.md).

## Watch, listen, read or request

| To | Open |
| --- | --- |
| Watch movies or TV | [Jellyfin](https://media.homehub.tv) |
| Listen to music | [Navidrome](https://music.homehub.tv) |
| Read or sync books to Kobo | [Calibre-Web](https://books.homehub.tv) |
| Listen to audiobooks | [Audiobookshelf](https://audiobooks.homehub.tv) |
| Request a movie or series | [Seerr](https://request.homehub.tv) |
| Find a book | [Shelfmark](https://shelfmark.homehub.tv) |

If downloads stop but the apps still open, check the [media VPN](networking.md#the-vpn). To add music from another computer, use the `Music` [SMB share](file-sharing.md#from-other-devices).

## Changing it

| To change | Edit |
| --- | --- |
| Jellyfin hardware transcoding | The Jellyfin dashboard; GPU access in [`jellyfin.nix`](../../modules/media/jellyfin.nix) |
| Shared library directories | [`media.nix`](../../modules/media/media.nix) |
| Indexers, library automation or subtitles | [`arr-stack.nix`](../../modules/media/arr-stack.nix) |
| Other media apps | Their files under [`modules/media/`](../../modules/media) |
