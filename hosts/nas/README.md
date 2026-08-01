# NAS — Home Lab Server

`nas` is the always-on CodyOS services host. It runs the `homehub.tv` media stack, backup storage, local inference for the Hermes voice pipeline, and acts as a Tailscale subnet router for the LAN.

Central docs should point here instead of duplicating this host map.

## Layout

Host-local files are split into two Nix files. Machine identity, drives, networking, and boot config live in `default.nix`. The llama-swap inference catalog stays separate.

| Path          | Role                                                                                                                                                                         |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `default.nix` | Full host definition: boot/kernel, filesystems (Btrfs root, Btrfs appdata, ext4 media, ZFS backup), networking, Tailscale subnet router, Docker, NVIDIA, Home Manager entry. |
| `models.nix`  | `llama-swap` enablement, CUDA acceleration (Blackwell sm_120a), CTranslate2 Blackwell override, model catalog (chat, embedding, OCR, audio STT/TTS).                         |

## Hardware profile

| Component    | Configuration                                                                                      |
| ------------ | -------------------------------------------------------------------------------------------------- |
| CPU          | Intel Core i5-14400F, 10 cores (6P+4E) / 16 threads, up to 4.7 GHz.                                |
| GPU          | NVIDIA GeForce RTX 5060, 8 GB VRAM, driver 595.71.05 (Blackwell, sm_120a).                         |
| RAM          | 64 GB DDR5-6000 (ZFS ARC capped at 32 GiB).                                                        |
| Boot NVMe    | WD Blue SN580 1 TB (`nvme0n1`) — Btrfs root (`/`, `/home`, `/nix`), vfat `/boot`.                  |
| Appdata NVMe | WD Blue SN580 1 TB (`nvme1n1`) — Btrfs with `@appdata` and `@tmp` subvolumes, zstd compression.    |
| Media HDD    | Seagate ST8000VN004 8 TB (`sda`) — ext4 at `/mnt/media`.                                           |
| ZFS pool     | `backup` — mirror of 2× Seagate ST4000VN006 4 TB (`sdb`, `sdd`), 3.62 TiB raw, auto-scrub enabled. |
| Kernel       | Linux 6.18 (NixOS 26.05 stable).                                                                   |
| NIC          | `enp6s0` — 192.168.1.108/24, IPv6 ULA `fd43:fa14:b975:8::/64`.                                     |

## Storage layout

| Mountpoint              | Source               | Filesystem | Purpose                                         |
| ----------------------- | -------------------- | ---------- | ----------------------------------------------- |
| `/`                     | `nvme0n1p2`          | Btrfs      | Root, home, nix store subvolumes.               |
| `/boot`                 | `nvme0n1p1`          | vfat       | EFI system partition.                           |
| `/mnt/appdata`          | `nvme1n1[@appdata]`  | Btrfs      | High-write app data (zstd, noatime).            |
| `/mnt/tmp`              | `nvme1n1[@tmp]`      | Btrfs      | Scratch / temp (zstd, noatime).                 |
| `/mnt/media`            | `sda1` (ST8000VN004) | ext4       | Media library (flat category directories).      |
| `/mnt/backup`           | `backup` ZFS pool    | ZFS        | Root of backup pool.                            |
| `/mnt/backup/Share`     | `backup/Share`       | ZFS        | Samba share (Syncthing with beast).             |
| `/mnt/backup/photos`    | `backup/photos`      | ZFS        | Immich media library.                           |
| `/mnt/backup/documents` | `backup/documents`   | ZFS        | Paperless-ngx storage.                          |
| `/mnt/backup/backups`   | `backup/backups`     | ZFS        | General backup target.                          |
| `/mnt/knowledge`        | `backup/knowledge`   | ZFS        | Knowledge base (bind-mounted to `~/Knowledge`). |
| `/mnt/projects`         | `backup/projects`    | ZFS        | Project files (bind-mounted to `~/Projects`).   |

## Networking

| Interface    | Address                     | Role                                              |
| ------------ | --------------------------- | ------------------------------------------------- |
| `enp6s0`     | 192.168.1.108/24 + IPv6 ULA | Primary LAN.                                      |
| `tailscale0` | 100.81.249.65/32            | Tailscale mesh; subnet router for 192.168.1.0/24. |
| `wg-br`      | 192.168.15.5/24             | WireGuard namespace bridge (Transmission VPN).    |
| `docker0`    | 172.17.0.1/16               | Docker bridge.                                    |

## Services

- **Docker** (docker 29): Actual Budget MCP, Hermes agent, Excalidraw.
- **llama-swap**: CUDA-accelerated inference on RTX 5060 — chat (Qwen 3.5), embedding, OCR, Whisper STT, Kokoro TTS.
- **Tailscale**: Subnet router advertising `192.168.1.0/24`; Hermes API (8642) and Dashboard (9119) exposed over Tailscale only.
- **ZFS**: Auto-scrub enabled; ARC capped at 32 GiB via `zfs.zfs_arc_max`.
- **Syncthing**: NAS↔beast share sync; GUI on LAN port 8384.
- **Bluetooth**: Enabled for Home Assistant (future controller).
- **Wake-on-LAN**: `wake-beast` service can wake the desktop.
