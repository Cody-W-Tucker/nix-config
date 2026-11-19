# Media

`den.aspects.media` (`media.nix`: media group, shared directory tree, includes one aspect per service) owns the media library and automation stack. The `vpn-confinement` NixOS module is imported once, by `media`, because `transmission.nix` declares the `wg` namespace and `arr-stack.nix` confines its services in it.

## Storage and permissions

The shared media tree lives under `/mnt/media` with flat category directories:

| Path | Purpose | Group |
| --- | --- | --- |
| `/mnt/media/Books` | E-books and audiobooks | `media` |
| `/mnt/media/Downloads` | Torrent download staging | `media` |
| `/mnt/media/Movies` | Movie library | `media` |
| `/mnt/media/Music` | Music library | `media` |
| `/mnt/media/TV Shows` | TV library | `media` |

`systemd.tmpfiles` enforces group ownership and setgid permissions so files created by one service remain writable by the rest of the media stack.

## Consumption

- Jellyfin serves video at `media.homehub.tv` and runs with access to the `media` group.
- Hardware transcoding uses the Intel iGPU; keep the Jellyfin user in `render` and `video` when changing acceleration settings.
- Navidrome serves `/mnt/media/Music` at `music.homehub.tv`.
- Calibre-Web provides the reader/Kobo-facing web layer, backed by Calibre Server and the books directory.

## Automation

The Arr stack is grouped by function:

- Prowlarr manages indexers.
- Radarr, Sonarr, Lidarr, and Readarr manage movies, TV, music, and books.
- Bazarr manages subtitles.
- Jellyseerr handles user-facing requests.

## Transmission VPN confinement

Transmission is intentionally isolated in a WireGuard network namespace through `vpn-confinement`.

- WireGuard config is supplied through SOPS.
- The service is bound with `systemd.services.transmission.vpnConfinement`.
- RPC is reachable at the namespace boundary so Arr services can talk to Transmission.
- Transmission uses a media-friendly umask so completed downloads stay writable by the `media` group.

Do not expose Transmission directly unless the network model is being deliberately changed.

