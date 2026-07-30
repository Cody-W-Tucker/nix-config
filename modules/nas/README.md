# NAS modules

This directory owns the shared service modules, currently deployed on the `nas` host. The NAS is the `homehub.tv` service hub: Nginx ingress, ACME certificates, media automation, photos, documents, file sharing, DNS filtering, Syncthing, and observability.

## Operating model

- Host entry point: `hosts/nas/default.nix`
- Module entry point: `modules/nas/default.nix`
- Public interface: Nginx virtual hosts under `homehub.tv`
- Certificate model: ACME DNS-01 through Cloudflare, with Nginx in the `acme` group
- Remote access: Tailscale plus HTTPS subdomains
- Shared service storage: `/mnt/media`
- Media library root: `/mnt/media` (flat category directories)
- Main service group: `media`

The host uses NVMe for the OS and a large HDD mounted at `/mnt/media` for service data. The optical drive mount is reserved for the Automatic Ripping Machine workflow.

## Module map

| File | Owns |
| --- | --- |
| `default.nix` | Common server imports, ACME, Nginx defaults, cross-host proxying, Tika, firewall openings |
| `media.nix` | Jellyfin, Navidrome, Calibre, Arr stack, Jellyseerr, Transmission, VPN confinement, media vhosts |
| `photos.nix` | Immich, photo storage, upload proxy tuning, photo backup job |
| `paperless.nix` | Paperless-ngx, Tika integration, document consume behavior, document backup job |
| `samba.nix` | LAN file shares and WSDD discovery |
| `adguard.nix` | DNS filtering and local resolver integration |
| `nginx-syncthing.nix` | Syncthing web UI reverse proxy |
| `monitoring.nix` | Prometheus, Grafana, Loki, Tempo, exporters, dashboards, scrape targets |
| `homepage-dashboard.nix` | Homepage layout and service links |
| `content.nix` | RSS/content services |
| `karakeep.nix` | Bookmark/read-it-later service |
| `actual-budget.nix` | Personal finance service |
| `arm.nix` | Automatic Ripping Machine container/service integration |
| `ai-services.nix` | Open WebUI, Qdrant vector search, AI firewall ports |
| `excalidraw.nix` | Excalidraw whiteboard service |
| `security.nix` | Fail2Ban and server hardening |

## Ingress and domains

Nginx is the single HTTPS entry point for local server services and selected services running elsewhere. `default.nix` sets the shared proxy behavior and wildcard certificate handling, then service modules add their own virtual hosts.

Common service mappings:

| Service | Domain | Port / target | Module |
| --- | --- | --- | --- |
| Homepage | `homehub.tv` | `8082` | `homepage-dashboard.nix` |
| Jellyfin | `media.homehub.tv` | `8096` | `media.nix` |
| Navidrome | `music.homehub.tv` | `4533` | `media.nix` |
| Calibre-Web | `books.homehub.tv` | `8083` | `media.nix` |
| Paperless | `paperless.homehub.tv` | `28981` | `paperless.nix` |
| Immich | `photos.homehub.tv` | `2283` | `photos.nix` |
| Grafana | `monitoring.homehub.tv` | `3001` | `monitoring.nix` |
| Tika | `tika.homehub.tv` | `9998` | `default.nix` |
| Syncthing UI | `nas-syncthing.homehub.tv` | `8384` | `nginx-syncthing.nix` |
| Beast Syncthing UI | `beast-syncthing.homehub.tv` | `100.108.143.19:8384` | `nginx-syncthing.nix` |
| Open WebUI | `ai.homehub.tv` | `8080` | `ai-services.nix` |
| Qdrant REST | `qdrant.homehub.tv` | `6333` | `ai-services.nix` |

`default.nix` also proxies selected `homehub.tv` subdomains to the `beast` workstation, including Open-WebUI and Qdrant. Keep that cross-host routing in the ingress layer, not inside unrelated service modules.

## Media stack

`media.nix` owns the media library and automation stack.

### Storage and permissions

The shared media tree lives under `/mnt/media` with flat category directories:

| Path | Purpose | Group |
| --- | --- | --- |
| `/mnt/media/Books` | E-books and audiobooks | `media` |
| `/mnt/media/Downloads` | Torrent download staging | `media` |
| `/mnt/media/Movies` | Movie library | `media` |
| `/mnt/media/Music` | Music library | `media` |
| `/mnt/media/TV Shows` | TV library | `media` |

`systemd.tmpfiles` enforces group ownership and setgid permissions so files created by one service remain writable by the rest of the media stack.

### Consumption

- Jellyfin serves video at `media.homehub.tv` and runs with access to the `media` group.
- Hardware transcoding uses the Intel iGPU; keep the Jellyfin user in `render` and `video` when changing acceleration settings.
- Navidrome serves `/mnt/media/Music` at `music.homehub.tv`.
- Calibre-Web provides the reader/Kobo-facing web layer, backed by Calibre Server and the books directory.

### Automation

The Arr stack is grouped by function:

- Prowlarr manages indexers.
- Radarr, Sonarr, Lidarr, and Readarr manage movies, TV, music, and books.
- Bazarr manages subtitles.
- Jellyseerr handles user-facing requests.

### Transmission VPN confinement

Transmission is intentionally isolated in a WireGuard network namespace through `vpn-confinement`.

- WireGuard config is supplied through SOPS.
- The service is bound with `systemd.services.transmission.vpnConfinement`.
- RPC is reachable at the namespace boundary so Arr services can talk to Transmission.
- Transmission uses a media-friendly umask so completed downloads stay writable by the `media` group.

Do not expose Transmission directly unless the network model is being deliberately changed.

## Photos, documents, and file sharing

### Immich

`photos.nix` runs Immich at `photos.homehub.tv` with data under `/mnt/media/Photos`. The Immich user is placed in the `video` and `render` groups for hardware acceleration. The Nginx vhost is tuned for large uploads with a high body-size limit and extended proxy timeouts.

### Paperless and Tika

`paperless.nix` runs Paperless-ngx at `paperless.homehub.tv`. Apache Tika is provided by `default.nix` and Paperless points to the local Tika endpoint for richer document extraction.

Paperless consume behavior is tuned for operator convenience:

- Recursive consume is enabled.
- Subdirectories become tags.
- Polling is frequent for quick ingest.
- Samba exposes a `PaperlessConsume` drop zone.

### Samba

`samba.nix` provides LAN-only file sharing and WSDD discovery. Shares are limited to the local subnet and localhost.

| Share | Path | Purpose |
| --- | --- | --- |
| `codytHome` | `/mnt/media/Share` | General personal storage |
| `Music` | `/mnt/media/Music` | Music library management |
| `PaperlessConsume` | `/var/lib/paperless/consume` | Document OCR drop zone |

### Backups

Photo and document modules include BorgBackup job definitions for backing up important personal data to the `beast` workstation. Treat these as service-local backup ownership: photo backup changes belong in `photos.nix`; document backup changes belong in `paperless.nix`.

## Network services

The server also owns core local-network utilities:

- `adguard.nix` handles AdGuard Home DNS filtering.
- AdGuard is the LAN-facing filter and exposes its web UI on port `8000`.
- Unbound is the local recursive resolver behind AdGuard and listens on `127.0.0.1:5335`.
- DNS fallback is configured so the host can stay reachable during resolver bootstrap or local resolver failure.
- `nginx-syncthing.nix` exposes Syncthing UIs through Nginx.
- Shared Syncthing service configuration may live under `modules/services/`; only server-specific proxying belongs here.

Syncthing is a two-host mesh between `nas` and `beast`. The shared service module owns device and folder declarations; this directory owns the server-side reverse proxies.

| UI | Target | Notes |
| --- | --- | --- |
| `nas-syncthing.homehub.tv` | `127.0.0.1:8384` | Local NAS Syncthing GUI |
| `beast-syncthing.homehub.tv` | `100.108.143.19:8384` | Beast Syncthing GUI over Tailscale |

The shared folder paths are host-specific: NAS uses `/mnt/media/Share`; beast uses `/mnt/backup/Share`.

Keep DNS and sync changes small and explicit. These services affect the rest of the LAN.

## Monitoring

`monitoring.nix` owns the LGTM-style stack:

- Prometheus for metrics.
- Grafana at `monitoring.homehub.tv` for dashboards.
- Loki for logs, including Nginx log ingestion.
- Tempo for traces and OTLP ingestion.
- Exporters for host, Nginx, SMART, GPU, and remote targets as configured.

Prometheus scrapes the server and selected `beast` metrics. Important endpoints and roles:

| Component | Endpoint / port | Role |
| --- | --- | --- |
| Grafana | `3001` | Dashboard UI behind `monitoring.homehub.tv` |
| Prometheus | `9001` | Metrics store and scrape scheduler |
| Server node exporter | `9002` | Server host and systemd metrics |
| Server Nginx exporter | `9115` | Nginx status metrics from the local stub status endpoint |
| Server nginxlog exporter | `9117` | Nginx access-log metrics |
| Loki | `3090` | Log storage and query backend |
| Tempo | `3200` | Trace storage and query backend |
| Tempo OTLP gRPC | `127.0.0.1:4327` | Trace ingest |
| Tempo OTLP HTTP | `127.0.0.1:4328` | Trace ingest |
| Beast node exporter | `beast:9002` | Remote host metrics |
| Beast Nvidia GPU exporter | `beast:9835` | GPU metrics for AI workloads |
| SMART exporters | host-specific | Drive health metrics |

Loki is configured as a single-binary filesystem-backed deployment with short retention. Nginx access logs are routed explicitly so both log and metric ingestion stay predictable.

If adding a service, add the exporter and scrape target in the same module that owns the monitoring integration, then expose it in Grafana only when it is useful to operate.

## Security notes

- Keep the public attack surface behind Nginx unless a protocol requires direct LAN access.
- Firewall openings are deliberate: HTTPS/HTTP for ingress plus required LAN services such as NFS/RPC.
- Fail2Ban policy lives in `security.nix`.
- VPN credentials and other secrets must stay in SOPS, close to the consuming service declaration.
- New files must be git-tracked before flakes can see them.

## Change checklist

When adding or changing a server service:

1. Put the implementation in the narrowest owning module.
2. Add storage permissions with tmpfiles if another service must read or write the data.
3. Add the Nginx vhost in the service module unless it is a cross-host proxy owned by `default.nix`.
4. Keep secrets in SOPS and quote dashed secret names.
5. Add dashboard and monitoring entries only if they help operate the service.
6. For risky service or networking changes, dry-run the NAS build with `nixos-rebuild dry-run --flake .#nas`.
