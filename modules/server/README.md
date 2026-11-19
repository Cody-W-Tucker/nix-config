# NAS modules (not yet relocated)

Services still here: `media/`, `paperless.nix`, `paperless-gpt.nix`, `tika.nix`, `open-webui.nix`, `langfuse/`. Each is a `den.aspects.<service>` included directly by `modules/hosts/nas.nix`. Ingress, web apps, monitoring and backups are documented in `modules/web/README.md`, `modules/observability/README.md` and `modules/backups/README.md`.

## Media stack

`media/` owns the media library and automation stack.

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

## Documents and file sharing

### Paperless and Tika

`paperless.nix` runs Paperless-ngx at `paperless.homehub.tv`. Apache Tika is provided by `tika.nix` and Paperless points to the local Tika endpoint for richer document extraction.

Paperless consume behavior is tuned for operator convenience:

- Recursive consume is enabled.
- Subdirectories become tags.
- Polling is frequent for quick ingest.
- Samba exposes a `PaperlessConsume` drop zone.

### Samba

`modules/file-sharing/samba.nix` provides LAN-only file sharing and WSDD discovery. Shares are limited to the local subnet and localhost.

| Share | Path | Purpose |
| --- | --- | --- |
| `codytHome` | `/mnt/media/Share` | General personal storage |
| `Music` | `/mnt/media/Music` | Music library management |
| `PaperlessConsume` | `/var/lib/paperless/consume` | Document OCR drop zone |

## Langfuse

`langfuse/` runs Langfuse v4 LLM observability at `langfuse.homehub.tv`, built from the upstream Docker Compose paradigm (six default services) as OCI/Docker containers.

### Services and storage

All six upstream default services are deployed as Docker OCI containers on an isolated `langfuse` docker network:

- `langfuse-web` (exposed to Nginx on `127.0.0.1:3000` only)
- `langfuse-worker` (internal only)
- `postgres` (17)
- `clickhouse` (25.12)
- `minio` (chainguard, object storage)
- `redis` (7)

Data is persisted as explicit bind mounts under `/mnt/appdata/langfuse` (not opaque named volumes), with ownership set via `systemd.tmpfiles`:

| Path | Service | Owner |
| --- | --- | --- |
| `/mnt/appdata/langfuse/postgres` | Postgres | `999:999` |
| `/mnt/appdata/langfuse/clickhouse` | ClickHouse | `101:101` |
| `/mnt/appdata/langfuse/clickhouse-logs` | ClickHouse logs | `101:101` |
| `/mnt/appdata/langfuse/redis` | Redis | `999:999` |
| `/mnt/appdata/langfuse/minio` | MinIO | `root` (world-writable; see note) |

The MinIO data directory is created world-writable because the Chainguard `minio` image's runtime UID is image-dependent; tighten it to the image's UID (after first run, `docker inspect <id> --format '{{.Config.User}}'`) if you want to drop the `0777` mode.

### Secrets

No credentials are hardcoded. A single SOPS secret, `langfuse-env`, is injected as `--env-file` into every container (see `modules/server/langfuse/langfuse-env.example` for the exact required keys and safe placeholders). The sops-nix-rendered file is read by the root-owned container units, matching the existing `paperless-gpt.nix` pattern. Add the secret for the `nas` host in the private secrets repo's `.sops.yaml` recipients, then populate it.

### Networking and startup ordering

The compose file's `depends_on` uses `condition: service_healthy`, which **compose2nix cannot translate** into systemd. Instead:

- Containers attach to an isolated `langfuse` docker network (created by a `docker-network-langfuse` oneshot unit) and reach each other by network alias (`postgres`, `redis`, `minio`, `clickhouse`, `langfuse-web`, `langfuse-worker`).
- `langfuse-web` and `langfuse-worker` declare `dependsOn` on `postgres`/`redis`/`minio`/`clickhouse`, producing real systemd `After`/`Requires` ordering.
- Only `langfuse-web` publishes a host port (`127.0.0.1:3000`); the dependency services are reachable only inside the docker network. The MinIO console and dependency ports are intentionally not exposed.

**Residual behavior:** `dependsOn` waits for the dependency *container* to start, not for the service inside to be *healthy*. Postgres/ClickHouse/Redis/MinIO may still be initializing when web/worker start. Langfuse retries connections with backoff, which covers this in practice; if a cold start races, restart the web/worker units. There are no health-gated systemd dependencies.

### Backups

Three independent stores must be backed up:

1. **Postgres** — `/mnt/appdata/langfuse/postgres` (primary relational store).
2. **ClickHouse** — `/mnt/appdata/langfuse/clickhouse` (event/observability store).
3. **MinIO** — `/mnt/appdata/langfuse/minio` (S3 media + event export bucket).

Follow the repo's existing ZFS-snapshot/backup pattern and include the `/mnt/appdata/langfuse` tree. Do not invent a new backup script; the three bind paths above are the backup surface. For transactionally consistent Postgres/ClickHouse snapshots, snapshot while the service is quiesced or rely on the engines' crash-recovery on restore.

### Update boundary

Images are pinned in `modules/server/langfuse/langfuse.nix`:

- `langfuse` / `langfuse-worker`: `4.68.0` (both images use explicit matching tags)
- `clickhouse-server`: `25.12`
- `redis`: `7`
- `postgres`: `17`
- `minio` (chainguard): rolling (no fixed tag)

For production, pin `postgres`/`redis` to a concrete patch and `minio` to a Chainguard digest rather than the rolling tag. The baseline was generated with compose2nix 0.3.3 from upstream `main` at inspection; re-run compose2nix against a new upstream compose and re-fold changes when upgrading major versions.

