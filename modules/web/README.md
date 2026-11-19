# Web apps and ingress

Owns the NAS ingress (`nginx.nix`: the universal `mkNginxVhost` helper on every host and `den.aspects.nginx.server`, the NAS wildcard certificate and nginx service) and one `den.aspects.<service>` per self-hosted single-service web app (`homepage`, `actual-budget`, `dawarich`, `excalidraw`, `home-assistant`, `karakeep`, `mealie`, `photos`). The NAS is the `homehub.tv` service hub; `modules/hosts/nas.nix` lists every feature it includes. See `AGENTS.md` for the rules.

## Operating model

- Host entry point: `modules/hosts/nas.nix`
- Public interface: Nginx virtual hosts under `homehub.tv`
- Certificate model: ACME DNS-01 through Cloudflare, with Nginx in the `acme` group (`nginx.server`)
- Remote access: Tailscale plus HTTPS subdomains
- Shared service storage: `/mnt/media`; main service group: `media`

The host uses NVMe for the OS and a large HDD mounted at `/mnt/media` for service data.

## Where the NAS features live

| Path | Owns |
| --- | --- |
| `web/` | Ingress, homepage, and the single-service web apps |
| `feeds/` | Miniflux and the miniflux-curator |
| `containers/docker.nix` | `docker` and `docker.oci-backend` |
| `observability/`, `backups/` | Monitoring, uptime checks; Restic jobs and backup health |
| `file-sharing/`, `networking/`, `sync/`, `nix/` | `samba.server`, `nfs.server`; `dns`, `strict-fail2ban`; `syncthing`, `syncthing.nginx`; `binary-cache.server` |
| `server/` | Services not yet moved: media, paperless, tika, langfuse, open-webui |

## Ingress and domains

Nginx is the single HTTPS entry point for local server services and selected services running elsewhere. `nginx.server` (`nginx.nix`) sets the shared proxy behavior and wildcard certificate handling, then service modules add their own virtual hosts.

Common service mappings:

| Service | Domain | Port / target | Module |
| --- | --- | --- | --- |
| Homepage | `homehub.tv` | `8082` | `homepage.nix` |
| Jellyfin | `media.homehub.tv` | `8096` | `../server/media/` |
| Navidrome | `music.homehub.tv` | `4533` | `../server/media/` |
| Calibre-Web | `books.homehub.tv` | `8083` | `../server/media/` |
| Paperless | `paperless.homehub.tv` | `28981` | `../server/paperless.nix` |
| Immich | `photos.homehub.tv` | `2283` | `photos.nix` |
| Grafana | `monitoring.homehub.tv` | `3001` | `../observability/monitoring.nix` |
| Tika | `tika.homehub.tv` | `9998` | `../server/tika.nix` |
| Syncthing UI | `nas-syncthing.homehub.tv` | `8384` | `../sync/syncthing.nix` |
| Beast Syncthing UI | `beast-syncthing.homehub.tv` | `100.108.143.19:8384` | `../sync/syncthing.nix` |
| Open WebUI | `chat.homehub.tv` | `8080` | `../server/open-webui.nix` |
| Langfuse | `langfuse.homehub.tv` | `3000` | `../server/langfuse/` |

Keep cross-host routing in the ingress layer, not inside unrelated service modules.


## Photos

### Immich

`photos.nix` runs Immich at `photos.homehub.tv` with data under `/mnt/media/Photos`. The Immich user is placed in the `video` and `render` groups for hardware acceleration. The Nginx vhost is tuned for large uploads with a high body-size limit and extended proxy timeouts.

## Network services

The NAS also relies on these local-network utilities:

- `modules/networking/dns.nix` (`dns`) handles AdGuard Home DNS filtering.
- AdGuard is the LAN-facing filter and exposes its web UI on port `8000`.
- Unbound is the local recursive resolver behind AdGuard and listens on `127.0.0.1:5335`.
- DNS fallback is configured so the host can stay reachable during resolver bootstrap or local resolver failure.
- `modules/sync/syncthing.nix` (`syncthing.nginx`) exposes Syncthing UIs through Nginx.
- The shared Syncthing configuration and its `syncthing.nginx` reverse proxy are in `modules/sync/syncthing.nix`.

Syncthing is a two-host mesh between `nas` and `beast`. The shared service module owns device and folder declarations; `syncthing.nginx` owns the server-side reverse proxies.

| UI | Target | Notes |
| --- | --- | --- |
| `nas-syncthing.homehub.tv` | `127.0.0.1:8384` | Local NAS Syncthing GUI |
| `beast-syncthing.homehub.tv` | `100.108.143.19:8384` | Beast Syncthing GUI over Tailscale |

The shared folder paths are host-specific: NAS uses `/mnt/media/Share`; beast uses `/mnt/backup/Share`.

Keep DNS and sync changes small and explicit. These services affect the rest of the LAN.

## Security notes

- Keep the public attack surface behind Nginx unless a protocol requires direct LAN access.
- Firewall openings are deliberate: HTTPS/HTTP for ingress plus required LAN services such as NFS/RPC.
- Fail2Ban policy lives in `modules/networking/networking.nix` (`strict-fail2ban`).
- VPN credentials and other secrets must stay in SOPS, close to the consuming service declaration.
- New files must be git-tracked before flakes can see them.

## Change checklist

When adding or changing a server service:

1. Put the implementation in the narrowest owning module.
2. Add storage permissions with tmpfiles if another service must read or write the data.
3. Add the Nginx vhost in the service module unless it is a cross-host proxy owned by `nginx.server`.
4. Keep secrets in SOPS and quote dashed secret names.
5. Add dashboard and monitoring entries only if they help operate the service.
6. For risky service or networking changes, dry-run the NAS build with `nixos-rebuild dry-run --flake .#nas`.
