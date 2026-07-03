# Media Stack: Jellyfin, Arr Suite, and Transmission

The media stack is implemented in [`modules/server/media.nix`](../modules/server/media.nix) and documented with the rest of the server modules in [`modules/server/README.md`](../modules/server/README.md#media-stack).

That local README owns the details for:

- `/mnt/media/Media` layout and `media` group permissions
- Jellyfin hardware acceleration and reverse proxying
- Navidrome and Calibre services
- Prowlarr, Radarr, Sonarr, Lidarr, Readarr, Bazarr, and Jellyseerr
- Transmission WireGuard namespace confinement
- Dashboard and monitoring integration

Keep this central page as a pointer so the implementation notes stay beside the Nix module.
