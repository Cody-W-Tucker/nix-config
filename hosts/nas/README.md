# NAS — Home Lab Server

`nas` is the always-on CodyOS services host. It runs the `homehub.tv` media stack, backup storage, local inference for the Hermes voice pipeline, and acts as a Tailscale subnet router for the LAN.

Central docs should point here instead of duplicating this host map.

## Layout

Host policy (identity, features, ZFS storage settings, networking, Home Manager) lives in `default.nix`; disks and kernel modules live in `hardware-configuration.nix`. The llama-swap inference catalog stays separate in `models.nix`.

| Path          | Role                                                                                                                                                                         |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `default.nix` | Host policy: `codyos.*` features, ZFS pool/ARC, Btrfs auto-scrub, home bind mounts, networking, Tailscale subnet router, Docker, CUDA toolkit, Home Manager entry. ZFS snapshot policy lives in `modules/nas/backups.nix`. |
| `hardware-configuration.nix` | Hardware: filesystems (Btrfs root, Btrfs appdata/projects/knowledge, ext4 media; all `noatime`) and initrd/kernel modules. |
| `models.nix`  | `llama-swap` enablement, CUDA acceleration (Blackwell sm_120a), CTranslate2 Blackwell override, model catalog (chat, embedding, OCR, audio STT/TTS).                         |

## Hardware profile

| Component    | Configuration                                                                                      |
| ------------ | -------------------------------------------------------------------------------------------------- |
| CPU          | Intel Core i5-14400F, 10 cores (6P+4E) / 16 threads, up to 4.7 GHz.                                |
| GPU          | NVIDIA GeForce RTX 5060, 8 GB VRAM, driver 595.71.05 (Blackwell, sm_120a).                         |
| RAM          | 64 GB DDR5-6000 (ZFS ARC capped at 8 GiB).                                                         |
| Boot NVMe    | WD Blue SN580 1 TB — Btrfs root (`/`, `/home`, `/nix`), vfat `/boot`.                              |
| Appdata NVMe | WD Blue SN580 1 TB — Btrfs with `@appdata`, `@tmp`, `@projects`, and `@knowledge` subvolumes, zstd compression (`@projects` mounted at `/mnt/projects`, `@knowledge` at `/mnt/knowledge`). |
| Media HDD    | Seagate ST8000VN004 8 TB — ext4 at `/mnt/media`.                                                   |
| ZFS pool     | `backup` — mirror of 2× Seagate ST4000VN006 4 TB (serials `ZW624NP8`, `ZW624PD8`), 3.62 TiB raw, auto-scrub enabled. |
| Unused SSDs  | Crucial MX300 2 TB and Kingston SUV400 120 GB on the ASMedia SATA card; old NTFS partitions, not mounted. |
| Kernel       | Linux 6.18 (NixOS 26.05 stable).                                                                   |
| NIC          | `enp6s0` — 192.168.1.2/24 (static), IPv6 ULA `fd43:fa14:b975:8::/64`.                              |

## Storage layout

Kernel names (`sdX`, `nvmeXn1`) change between boots; the config mounts by UUID. Both Btrfs filesystems are scrubbed monthly (`services.btrfs.autoScrub`, via `/` and `/mnt/appdata`).

| Mountpoint              | Source               | Filesystem | Purpose                                         |
| ----------------------- | -------------------- | ---------- | ----------------------------------------------- |
| `/`                     | Boot NVMe, part. 2   | Btrfs      | Root, home, nix store subvolumes (noatime).     |
| `/boot`                 | Boot NVMe, part. 1   | vfat       | EFI system partition.                           |
| `/mnt/appdata`          | Appdata NVMe `@appdata` | Btrfs   | High-write app data (zstd, noatime).            |
| `/mnt/tmp`              | Appdata NVMe `@tmp`  | Btrfs      | Scratch / temp (zstd, noatime).                 |
| `/mnt/media`            | ST8000VN004, part. 1 | ext4       | Media library (flat category directories).      |
| `/mnt/backup`           | `backup` ZFS pool    | ZFS        | Root of backup pool.                            |
| `/mnt/backup/Share`     | `backup/Share`       | ZFS        | Samba share (Syncthing with beast).             |
| `/mnt/backup/photos`    | `backup/photos`      | ZFS        | Immich media library.                           |
| `/mnt/backup/documents` | `backup/documents`   | ZFS        | Paperless-ngx storage.                          |
| `/mnt/backup/backups`   | `backup/backups`      | ZFS        | General backup target.                          |
| `/mnt/projects`         | Appdata NVMe `@projects` | Btrfs      | Project files (bind-mounted to `~/Projects`, NFS-exported to beast). |
| `/mnt/knowledge`        | Appdata NVMe `@knowledge` | Btrfs      | Knowledge base (bind-mounted to `~/Knowledge`, NFS-exported to beast). |

## Networking

| Interface    | Address                     | Role                                              |
| ------------ | --------------------------- | ------------------------------------------------- |
| `enp6s0`     | 192.168.1.2/24 static + IPv6 ULA | Primary LAN, DNS server for router.              |
| `tailscale0` | 100.81.249.65/32            | Tailscale mesh; subnet router for 192.168.1.0/24. |
| `wg-br`      | 192.168.15.5/24             | WireGuard namespace bridge (Transmission VPN).    |
| `docker0`    | 172.17.0.1/16               | Docker bridge.                                    |

## Services

- **Docker** (docker 29): Actual Budget MCP, Hermes agent, Excalidraw.
- **llama-swap**: CUDA-accelerated inference on RTX 5060 — chat (Qwen 3.5), embedding, OCR, Whisper STT, Kokoro TTS.
- **Tailscale**: Subnet router advertising `192.168.1.0/24`; Hermes API (8642) and Dashboard (9119) exposed over Tailscale only.
- **ZFS**: Auto-scrub enabled; ARC capped at 8 GiB via `zfs.zfs_arc_max`. Daily, weekly, and monthly snapshots cover `backup/photos`, `backup/documents`, `backup/Share`, and `backup/backups`.
- **Backups**: service-owned SQLite exports (plus Karakeep's catalog, captured assets and settings) stage on `backup/backups`; Restic includes those exports, Projects, Knowledge, Hermes, and Langfuse's MinIO objects. The shared module owns the Restic repository, PostgreSQL/ClickHouse dumps, and ZFS snapshot policy. Paperless originals live on the snapshotted `backup/documents` dataset, not the 8 TB media disk. Add `restic-nas-password` with `sops` before activation. No off-box copy or restore drill is configured; ZFS originals and the 8 TB media disk remain vulnerable to whole-NAS loss.
- **Syncthing**: NAS↔beast share sync; GUI at `nas-syncthing.homehub.tv` (port 8384 is open on Tailscale only).
- **Bluetooth**: Enabled for Home Assistant (future controller).
- **Wake-on-LAN**: `wake-beast` service can wake the desktop.
