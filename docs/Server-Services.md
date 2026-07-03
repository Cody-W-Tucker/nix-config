# Server Services

Server service implementation is owned by [`modules/server/README.md`](../modules/server/README.md). That local README is the source of truth for service categories, module ownership, domains, ports, storage, permissions, monitoring, and operational notes.

Use this page as the index only:

- Server host: [`hosts/server.nix`](../hosts/server.nix)
- Server module root: [`modules/server/default.nix`](../modules/server/default.nix)
- Server module docs: [`modules/server/README.md`](../modules/server/README.md)

Current service families covered there:

- Nginx ingress and ACME certificates
- Media stack: Jellyfin, Navidrome, Calibre, Arr services, Transmission VPN confinement
- Photos, documents, and Samba file sharing
- DNS filtering and Syncthing exposure
- Monitoring with Prometheus, Grafana, Loki, and Tempo
- Content, bookmarks, budget, ARM, Excalidraw, and dashboard services
