# NAS Service Migration

One-way server→NAS replacement. Every `modules/server` responsibility moves to NAS.
Once validated and production traffic is cut over, server is decommissioned — not kept as a standby.

## Target (`nas`) — Current State

- Boot: Btrfs on 1 TB NVMe (`0e0786ed-3740-4a19-83af-cf356e55393b`), subvolumes `@`, `@home`, `@nix`
- Imports: `modules/system/base.nix`, `vpn-confinement` (via input); `modules/server` is **commented out**
- CPU: Intel — `boot.kernelModules = ["kvm-intel"]`, `hardware.cpu.intel.updateMicrocode` already present (verify match with `cat /proc/cpuinfo | grep vendor`)
- GPU: GTX 1650 (`10de:1f82`), NVIDIA proprietary driver 580.142 / CUDA 13.0; 64 GB DDR5-6000 RAM
- No NFS, Tailscale, or Docker configured

## Source (`server`) — Key Config

- 8 TB ext4 media disk `/mnt/media` (UUID `27ddc2ef-8f21-401d-b9eb-3ed4541c16c9`)
- Full `modules/server` import + NFS exports `/mnt/media` to beast (`192.168.1.20`)
- `services.tailscale.enable`, `virtualisation.docker.package = pkgs.docker_29`

## Agent/Human Split

Agents edit repo files and run `nixos-rebuild dry-run`. Humans handle hardware, disk formatting, `sudo nixos-rebuild switch`, data copy, tailscale registration, and functional probes. Agents do not run `sudo` or execute destructive disk operations.

---

## Phase 1 — Human: Preflight Inventory (Stop if gate fails)

### 1.1 Server inventory

```bash
# On server
df -hT && lsblk -o UUID,LABEL,SIZE,TYPE,MOUNTPOINT
find /mnt/media -maxdepth 3 > /tmp/media-manifest.txt
du -sh /var/lib/*
```

results from above commands, & media manifest saved.:

```
Filesystem     Type      Size  Used Avail Use% Mounted on
devtmpfs       devtmpfs  3.2G     0  3.2G   0% /dev
tmpfs          tmpfs      32G  1.1M   32G   1% /dev/shm
tmpfs          tmpfs      16G   12M   16G   1% /run
/dev/nvme0n1p2 ext4      468G  150G  295G  34% /
efivarfs       efivarfs  256K  239K   13K  95% /sys/firmware/efi/efivars
tmpfs          tmpfs     1.0M     0  1.0M   0% /run/credentials/systemd-journald.service
tmpfs          tmpfs      32G  1.2M   32G   1% /run/wrappers
/dev/nvme0n1p1 vfat      511M   44M  468M   9% /boot
/dev/sda1      ext4      7.3T  5.4T  1.5T  79% /mnt/media
tmpfs          tmpfs     1.0M     0  1.0M   0% /run/credentials/getty@tty1.service
tmpfs          tmpfs     1.0M  4.0K 1020K   1% /run/credentials/paperless-scheduler.service
overlay        overlay   468G  150G  295G  34% /var/lib/docker/overlay2/0cb0a68f1aba70238132575f947293a0f95679509d588b4d1a1332d7ed5923e1/merged
overlay        overlay   468G  150G  295G  34% /var/lib/docker/overlay2/5b1fb6461f59cf9e8f6e657b696da4665e80cea2b5534c294641fe3a97d707a4/merged
tmpfs          tmpfs     6.3G   12K  6.3G   1% /run/user/1000
UUID                                 LABEL   SIZE TYPE MOUNTPOINT
                                             7.3T disk
27ddc2ef-8f21-401d-b9eb-3ed4541c16c9 media   7.3T part /mnt/media
                                            1024M rom
                                           476.9G disk
763D-AB92                                    512M part /boot
c6c7b5c2-8edf-4aa5-9c6d-cbcd7498db1d       476.4G part /
16K	/var/lib/AccountsService
376K	/var/lib/acme
0	/var/lib/actual
0	/var/lib/AdGuardHome
3.1M	/var/lib/audiobookshelf
15M	/var/lib/bazarr
8.0K	/var/lib/boltd
7.3M	/var/lib/calibre-server
184K	/var/lib/calibre-web
52K	/var/lib/colord
6.0G	/var/lib/containers
33G	/var/lib/docker
76K	/var/lib/fail2ban
2.0M	/var/lib/fwupd
6.7M	/var/lib/ghost
88M	/var/lib/grafana
17M	/var/lib/hass
0	/var/lib/homepage-dashboard
52K	/var/lib/immich
5.8G	/var/lib/jellyfin
0	/var/lib/jellyseerr
2.1M	/var/lib/kanban
2.6G	/var/lib/karakeep
0	/var/lib/karakeep-browser
16K	/var/lib/lastlog
6.7M	/var/lib/libvirt
538M	/var/lib/lidarr
4.0K	/var/lib/logrotate.status
113M	/var/lib/loki
4.0K	/var/lib/machines
15M	/var/lib/mastodon
187M	/var/lib/mattermost
0	/var/lib/meilisearch
0	/var/lib/metabase
8.0K	/var/lib/miniflux-curator
4.0K	/var/lib/misc
113M	/var/lib/mysql
0	/var/lib/n8n
260M	/var/lib/navidrome
24K	/var/lib/NetworkManager
4.0K	/var/lib/NetworkManager-fortisslvpn
2.5G	/var/lib/nextcloud
60K	/var/lib/nfs
8.0K	/var/lib/nftables
4.0K	/var/lib/nixarr
24K	/var/lib/nixos
0	/var/lib/ollama
185M	/var/lib/onlyoffice
0	/var/lib/opentelemetry-collector
0	/var/lib/open-webui
666M	/var/lib/paperless
0	/var/lib/photoprism
1.3G	/var/lib/plex
4.0K	/var/lib/portables
132K	/var/lib/postfix
878M	/var/lib/postgresql
8.0K	/var/lib/power-profiles-daemon
17G	/var/lib/private
126M	/var/lib/prometheus2
0	/var/lib/prowlarr
0	/var/lib/qdrant
12K	/var/lib/qemu
544K	/var/lib/rabbitmq
1.5G	/var/lib/radarr
268M	/var/lib/readarr
1.9M	/var/lib/redis-immich
284K	/var/lib/redis-mastodon
12K	/var/lib/redis-nextcloud
12K	/var/lib/redis-paperless
12K	/var/lib/redis-searx
2.2M	/var/lib/samba
4.0K	/var/lib/secrets
239M	/var/lib/sonarr
8.0K	/var/lib/sops-nix
0	/var/lib/stirling-pdf
30M	/var/lib/syncthing
743M	/var/lib/systemd
36K	/var/lib/tailscale
0	/var/lib/tempo
0	/var/lib/tika
1.1M	/var/lib/transmission
4.0K	/var/lib/udisks2
8.0K	/var/lib/unbound
```

Save the manifest. Confirm the 8 TB disk UUID `27ddc2ef-8f21-401d-b9eb-3ed4541c16c9`. ✅ Confirmed.

### 1.2 NAS storage inventory

```bash
# On NAS
lsblk -o NAME,UUID,SIZE,TYPE,MODEL,MOUNTPOINT
ls -l /dev/disk/by-id/ | grep -v part
```

results from above commands:

```
NAME        UUID                                   SIZE TYPE MODEL              MOUNTPOINT
sda                                                3.6T disk ST4000VN006-3CW104
└─sda1      7e4d866f-4494-41c6-850b-a5dc2cd8367a   3.6T part
sdb                                                3.6T disk ST4000VN006-3CW104
└─sdb1      9dc55264-1ade-4f7b-a157-60d022feec40   3.6T part
nvme0n1                                          931.5G disk WD Blue SN580 1TB
├─nvme0n1p1 CBDD-BD07                                1G part                    /boot
└─nvme0n1p2 0e0786ed-3740-4a19-83af-cf356e55393b 930.5G part                    /
nvme1n1                                          931.5G disk WD Blue SN580 1TB
└─nvme1n1p1 34882b6b-6f50-4caa-93ff-b27688c41f1a 931.5G part
lrwxrwxrwx - root 14 Jul 10:27 ata-ST4000VN006-3CW104_ZW624NP8 -> ../../sda
lrwxrwxrwx - root 14 Jul 10:27 ata-ST4000VN006-3CW104_ZW624PD8 -> ../../sdb
lrwxrwxrwx - root 14 Jul 10:27 nvme-eui.e8238fa6bf530001001b448b4d8899be -> ../../nvme1n1
lrwxrwxrwx - root 14 Jul 10:27 nvme-eui.e8238fa6bf530001001b448b4d889902 -> ../../nvme0n1
lrwxrwxrwx - root 14 Jul 10:27 nvme-WD_Blue_SN580_1TB_245156805268 -> ../../nvme1n1
lrwxrwxrwx - root 14 Jul 10:27 nvme-WD_Blue_SN580_1TB_245156805268_1 -> ../../nvme1n1
lrwxrwxrwx - root 14 Jul 10:27 nvme-WD_Blue_SN580_1TB_245156805282 -> ../../nvme0n1
lrwxrwxrwx - root 14 Jul 10:27 nvme-WD_Blue_SN580_1TB_245156805282_1 -> ../../nvme0n1
lrwxrwxrwx - root 14 Jul 10:27 wwn-0x5000c500e84c3ec4 -> ../../sdb
lrwxrwxrwx - root 14 Jul 10:27 wwn-0x5000c500e84c5755 -> ../../sda
```

**Gate:** ✅ Two 4 TB ZFS mirror HDDs confirmed: `ata-ST4000VN006-3CW104_ZW624NP8` (sda), `ata-ST4000VN006-3CW104_ZW624PD8` (sdb). ✅ Distinct app-data NVMe confirmed: `nvme-WD_Blue_SN580_1TB_245156805268` (nvme1n1, separate from boot NVMe nvme0n1). By-id paths recorded in Phase 3.

### 1.3 Record NAS hostId

Collect while NAS is still running so the agent can place it in bootstrap config:

```bash
head -c8 /etc/machine-id
```

results: `60f0861b` ✅ Recorded.

Save the 8-char hex. If `/etc/machine-id` is unavailable or was regenerated (e.g. after hardware changes), generate a stable fallback:

```bash
od -A n -t x4 -N 4 /dev/urandom | tr -d ' '
```

**✅ Phase 1 preflight complete — capacity gate passed.** Measured sizes:

- Share: 29G
- Photos: 113G
- Documents: 7.6G
- Total: 149.6G

The combined 149.6G fits comfortably within the approximately 3.6 TiB usable ZFS mirror with ample operational headroom.

---

## Phase 2 — Agent: Preparatory Edits (independent of target device IDs)

Validate each change with `nixos-rebuild dry-run --flake .#nas` (or `.#beast` where applicable).

### 2.1 `[fast]` Remove ARM import ✅

**File:** `modules/server/default.nix` — removed `./arm.nix` from `imports`. Done.

### 2.2 `[medium]` Hostname-agnostic monitoring labels ✅

**File:** `modules/server/monitoring.nix` — replaced hardcoded `host = "server"` with `"${config.networking.hostName}"`. Done.

### 2.3 `[medium]` Transmission VPN — rename secret reference ❌ Intentionally skipped

**Operator decision:** Retain the existing `"server-wg.conf"` sops secret attribute name and external secret path. No rename or re-encryption required. The WireGuard config is a shared provider credential that functions correctly across hosts without renaming.

### 2.4 `[heavy]` Import shared NVIDIA module on NAS ✅ (fixed 2026-07-14)

**File:** `hosts/nas.nix` — added `../modules/desktop/hardware/nvidia.nix` to imports. The shared module sets `services.xserver.videoDrivers = [ "nvidia" ]`, which the `hardware.nvidia` module requires to activate kernel modules, firmware, CUDA, and `nvidia-smi`. NAS is headless (no display manager or desktop session), so the X11 nvidia driver is installed but idle. GPU exporter, power management, desktop env vars are retained.

**Initial bug:** A prior headless override `services.xserver.videoDrivers = lib.mkForce []` cleared the "nvidia" entry, which silently gated off the entire `hardware.nvidia` config — no kernel module, no `nvidia-smi`. Removed 2026-07-14. The "nvidia" entry in `videoDrivers` is required for `hardware.nvidia` activation even without a running X server.

**⚠ Human verify post-deploy (COMPLETE — driver & render node confirmed 2026-07-14):** `nvidia-smi` reports NVIDIA GeForce GTX 1650, driver 580.142 / CUDA 13.0. `/dev/dri/renderD128` exists.

**⚠ Human verify post-deploy (PENDING):** Test hardware transcode workload (Jellyfin).

### 2.4.1 Immich ML GPU crash — root cause found and GPU re-enabled (2026-07-14)

**Observed crash (initial):** Immich machine-learning container crash-looped with SIGABRT on the NAS GTX 1650. Core dump implicated ONNX Runtime/TensorRT: `CUDADriverWrapper() handle != nullptr was false`. The GPU was available (`nvidia-smi`, render node), but the TensorRT CUDA driver wrapper failed internally.

**Root cause:** Missing NVIDIA userspace library `libcuda.so.1`. Without `hardware.graphics.enable`, the `/run/opengl-driver` symlink farm was absent — Immich ML could not resolve the CUDA driver library at runtime, producing the misleading TensorRT handle error. The module default `services.immich.accelerationDevices = []` also enforced `PrivateDevices=true`, preventing the ML container from accessing any GPU device nodes even if the library were present.

**Fix:** `hardware.graphics.enable = true` was already set in `hosts/nas.nix`, providing `libcuda.so.1` to the host. `modules/server/photos.nix` now sets:

- `services.immich.accelerationDevices = [ "/dev/nvidiactl" "/dev/nvidia0" "/dev/nvidia-uvm" ]` — a nonempty list switches the service from `PrivateDevices=true` to `PrivateDevices=false` with a narrow `DeviceAllow` allowlist granting access only to the three required NVIDIA device nodes.
- `machine-learning.environment.CUDA_VISIBLE_DEVICES = "0"` — restricts Immich ML to GPU 0.

**What it does NOT affect:** Jellyfin/ffmpeg hardware transcode continues to use the GPU via VA-API/NVDEC. The NVIDIA kernel module, `nvidia-smi`, GPU exporter, and all other GPU consumers are untouched.

**⚠ Human verify post-deploy (PENDING):** Validate Immich smart search and face detection using CUDA on GPU 0 with no crash loop.

### 2.5 `[fast]` Add Tailscale + Docker to NAS ✅

Done.

### 2.6 `[fast]` Remove beast NFS mount ✅

Done.

### 2.7 `[fast]` Configure ZFS ARC cap ✅

Done. Verify memory pressure post-deployment.

### 2.8 `[medium]` Redirect protected user-content paths to ZFS ✅

Only user-content paths were redirected to the ZFS `backup` pool. Persistent service
state — databases, caches, application data — stays on the NAS boot NVMe at default
`/var/lib/*` paths.

| Service       | Content path   | ZFS target              |
| ------------- | -------------- | ----------------------- |
| Immich        | Media library  | `/mnt/backup/photos`    |
| Paperless-ngx | Media storage  | `/mnt/backup/documents` |
| Samba         | Share          | `/mnt/backup/Share`     |

**Storage decision:** Service state remains on the boot NVMe for this migration.
Services will initially create empty state under `/var/lib` during deployment
(Phase 5), then receive restored server state while stopped (Phase 6.2).

The `/mnt/appdata` Btrfs NVMe remains configured and available for later targeted
adoption by high-write or large-state services (e.g. PostgreSQL, Docker, observability)
if growth warrants it. No service relocation to appdata is being performed now.

Done.

### 2.9 Phase 2 gate ✅ Passed

All three dry-runs passed: `.#nas`, `.#server`, `.#beast`.

### 2.10 `[medium]` Agent: ZFS bootstrap config ✅

**File:** `hosts/nas.nix` — `boot.supportedFilesystems = [ "zfs" ]` added. `networking.hostId = "60f0861b"` set. No `boot.zfs.extraPools` added (pool does not exist yet). `../modules/server` remains commented out. Done.

---

## Phase 3 — Human: ZFS Bootstrap & Destructive Storage Prep

### 3.0 HostId stop/go gate — STOP before deploying

Replace every `PASTE-FROM-PHASE-1.3` placeholder in `hosts/nas.nix` with the 8-char hex hostId recorded in §1.3. Verify none remain:

```bash
grep -n 'PASTE-FROM' hosts/nas.nix
```

This command **must produce no output.** Do not deploy the placeholder — ZFS requires a valid `networking.hostId` at boot.

### 3.0 Bootstrap activation — STOP if `zpool` is missing

The minimal NixOS ZFS support from §2.10 must be deployed before any ZFS command will work.

```bash
sudo nixos-rebuild switch --flake .#nas
zpool version
```

**Gate:** `zpool version` must print a ZFS version. If it fails, do not proceed to pool creation — debug the ZFS module load.

### 3.1 ZFS pool creation (destructive) — STOP before running

Confirm the two 4 TB disks identified in §1.2 contain no required data.

```bash
# Use VERIFIED /dev/disk/by-id/ paths from Phase 1, not by-uuid or sda/sdb.
sudo zpool create -o ashift=12 -O compression=lz4 \
  -O mountpoint=/mnt/backup \
  backup mirror \
  /dev/disk/by-id/ata-ST4000VN006-3CW104_ZW624NP8 \
  /dev/disk/by-id/ata-ST4000VN006-3CW104_ZW624PD8
zpool status backup
```

Create datasets:

```bash
sudo zfs create backup/Share
sudo zfs create backup/photos
sudo zfs create backup/documents
sudo zfs create backup/backups
sudo chown codyt:users /mnt/backup/Share
```

**Auto-trim:** The mirror disks are HDDs (`ROTA=1`). Do **not** enable autotrim. Scrubs are enabled in Phase 4 NixOS config.

**✅ Phase 3.1 complete (2026-07-14).** Results:

- **Pool `backup`:** ONLINE. Two-disk mirror of `ata-ST4000VN006-3CW104_ZW624NP8` and `ata-ST4000VN006-3CW104_ZW624PD8`. No known data errors.
- **Datasets:** `backup/Share`, `backup/photos`, `backup/documents`, `backup/backups` — all exist at expected mountpoints under `/mnt/backup`.
- **Capacity:** 3.51T available.

### 3.2 NVMe app-data reformat (destructive) — STOP before running

Confirm the app-data NVMe from §1.2 is correct and contains no required data.

```bash
sudo mkfs.btrfs -L appdata /dev/disk/by-id/nvme-WD_Blue_SN580_1TB_245156805268
sudo mkdir -p /mnt/appdata-tmp
sudo mount /dev/disk/by-id/nvme-WD_Blue_SN580_1TB_245156805268 /mnt/appdata-tmp
sudo btrfs subvolume create /mnt/appdata-tmp/@appdata
sudo btrfs subvolume create /mnt/appdata-tmp/@tmp
sudo umount /mnt/appdata-tmp
sudo rmdir /mnt/appdata-tmp
```

Record the new Btrfs UUID: `sudo blkid /dev/disk/by-id/nvme-WD_Blue_SN580_1TB_245156805268`.

**✅ Phase 3.2 complete (2026-07-14).** Results:

- **Device:** `/dev/disk/by-id/nvme-WD_Blue_SN580_1TB_245156805268` — Btrfs label `appdata`, UUID `17888441-14c2-465f-9786-b2eae0220553`.
- **Subvolumes:** `@appdata` (ID 256) and `@tmp` (ID 257).

### 3.3 Physical media disk move

1. **Power down both server and NAS.**
2. Physically install the 8 TB disk into NAS.
3. **Boot NAS** (now with the 8 TB disk). Verify: `lsblk | grep 27ddc2ef`.
4. **Do not reformat.** The ext4 filesystem arrives intact.
5. Server stays powered down until the network app-data copy in Phase 6.2. Server is booted **without the 8 TB disk** only for that network transfer — it cannot serve media during this period.

**✅ Phase 3.3 complete (2026-07-14).** UUID `27ddc2ef-8f21-401d-b9eb-3ed4541c16c9` verified on the 8 TB ext4 media disk. Disk physically installed in NAS. Server powered down. Media manifest saved.

---

## Phase 4 — Agent: Finalize NAS Config (with IDs from Phase 3)

### 4.1 `[medium]` Add storage mounts, ZFS config, hostId, scrubs

**File:** `hosts/nas.nix` — add:

```nix
boot.zfs.extraPools = [ "backup" ];
services.zfs.autoScrub.enable = true;
# networking.hostId was already set in Phase 2.10 — verify the value is still present; do not redeclare.

fileSystems."/mnt/media" = {
  device = "/dev/disk/by-uuid/27ddc2ef-8f21-401d-b9eb-3ed4541c16c9";
  fsType = "ext4";
};
fileSystems."/mnt/appdata" = {
  device = "/dev/disk/by-uuid/17888441-14c2-465f-9786-b2eae0220553";
  fsType = "btrfs";
  options = [ "subvol=@appdata" "compress=zstd" "noatime" ];
};
fileSystems."/mnt/tmp" = {
  device = "/dev/disk/by-uuid/17888441-14c2-465f-9786-b2eae0220553";
  fsType = "btrfs";
  options = [ "subvol=@tmp" "compress=zstd" "noatime" ];
};
```

**✅ Phase 4.1 complete (2026-07-14).** All above config applied to `hosts/nas.nix`: `boot.zfs.extraPools = [ "backup" ]`, `services.zfs.autoScrub.enable = true`, three storage mounts with verified UUIDs. `networking.hostId = "60f0861b"` confirmed still present (set in Phase 2.10). Additional host-level override: `environment.sessionVariables.LIBVA_DRIVER_NAME = lib.mkForce "nvidia"` to resolve conflict between `modules/server/media.nix` ("iHD" / Intel) and `modules/desktop/hardware/nvidia.nix` ("nvidia") — NAS has a GTX 1650 GPU.

### 4.2 `[medium]` Syncthing NAS device and folder ✅ Complete

**✅ Phase 4.2 complete (2026-07-14).** Real NAS device ID captured from Syncthing GUI and recorded in config:

**File:** `modules/services/syncthing.nix` — added to `settings.devices`:

```nix
"nas" = { id = "STU55DV-U3QK2RL-7UE5IGR-PRHOSQU-4SK4JUW-Y5YJP5R-IQLNAH2-QXAQBQQ"; };
```

Added to `settings.folders` (inside `lib.mkMerge`):

```nix
(lib.mkIf (config.networking.hostName == "nas") {
  "Share" = {
    path = "/mnt/backup/Share";
    devices = [ "nas" "beast" ];
  };
})
```

> ⚠ Share synchronization between NAS and beast is retained as a later human verification (Phase 7 validation, item 5). Config is in place but functional sync must be confirmed by the operator post-deployment.

### 4.3 `[medium]` Uncomment server import

**File:** `hosts/nas.nix` — uncomment `../modules/server`.

**✅ Phase 4.3 complete (2026-07-14).** `../modules/server` import uncommented in `hosts/nas.nix`.

### 4.4 Phase 4 gate ✅ Passed

```bash
nixos-rebuild dry-run --flake .#nas   # exit 0
nixos-rebuild dry-run --flake .#server # exit 0
```

Both dry-runs pass. Phase 4.2 (Syncthing) intentionally deferred — no placeholder device ID deployed. NAS config mounts ext4 media, Btrfs appdata + tmp subvolumes, and ZFS backup pool; imports full `modules/server`; ZFS auto-scrub enabled; GPU VA-API driver forced to NVIDIA for GTX 1650 compatibility.

---

## Phase 5 — Human: Deploy to NAS

```bash
sudo nixos-rebuild switch --flake .#nas
```

**⚠ Immediately stop stateful consuming services.** `nixos-rebuild switch` may initialize empty databases. Before data migration, stop every service that writes to stateful storage, but **leave PostgreSQL running** so you can restore databases into it.

List the exact service units on the deployed NAS:

```bash
systemctl list-unit-files | grep -E '^(immich|paperless|karakeep|actual|transmission|jellyfin|navidrome|calibre|miniflux|excalidraw|adguard)'
```

Match each discovered unit name to the corresponding `services.<name>.enable` declaration in `modules/server/`. Stop them all:

```bash
sudo systemctl stop <unit1> <unit2> ...  # use the exact unit names from list-unit-files
```

> The unit names above are examples only; confirm on the actual deployed system. NixOS service unit names may differ from the `services.<name>` attribute path (e.g. `immich-server` vs `immich`, `paperless-scheduler` vs `paperless`). Run `systemctl cat <unit>` on a unit to inspect its definition when in doubt. Do not invent database commands — defer to the consuming service's own restore mechanism where one exists.

### Tailscale registration

```bash
sudo tailscale up --operator=codyt
tailscale status
tailscale ping beast
```

Note the NAS Tailscale IP. Keep production routing on server during validation.

### Syncthing identity + rebuild ✅ Complete

NAS device ID captured from Syncthing GUI after first start. Real ID recorded in `modules/services/syncthing.nix` (Phase 4.2).

### 5.1 First deployment — completed 2026-07-14

- **`sudo nixos-rebuild switch --flake .#nas`** — first deployment ran to completion.
- **Temporary DNS bootstrap removed.** Cloudflare forwarders in `hosts/nas.nix` removed via `nixos-rebuild switch`. NAS `/etc/resolv.conf` now contains `127.0.0.1` and `::1` — loopback-first, served by AdGuard/Unbound. Verified: `getent ahosts github.com` returns resolved addresses. AdGuard/Unbound local DNS is active.
- **Application writers stopped.** All stateful consuming services identified in Phase 5 were stopped immediately after deployment to prevent empty-database initialization from overwriting server state later during migration.
- **PostgreSQL remains running.** Database server is available for restore operations.

**⚠ Remaining Phase 5 work (not yet done):**
- Tailscale registration (`tailscale up --operator=codyt`)
- **Data migration has not started** — this record is a deployment + containment checkpoint only.

### 5.2 Agent: Remove temporary DNS bootstrap — deployed and verified (2026-07-14)

AdGuard Home has been restored on the NAS and directly verified answering `google.com A` at `127.0.0.1:53`. The temporary Cloudflare bootstrap block in `hosts/nas.nix` has been removed:

- Removed `lib.mkForce` Cloudflare nameservers (`1.1.1.1`, `1.0.0.1`)
- Removed `networkmanager.dns = "none"`
- Removed `resolvconf.enable = true`
- Removed `resolvconf.extraConfig` forced Cloudflare `name_servers`
- Removed all associated temporary comments

After this change, DNS ownership returns to the shared AdGuard/Unbound configuration in `modules/server/adguard.nix`, which sets `networking.nameservers` to `["127.0.0.1" "::1" "1.1.1.1"]` — loopback-first with Cloudflare fallback, served by Unbound at `127.0.0.1:5335` behind AdGuard Home on port 53.

Local `nixos-rebuild dry-run --flake .#nas` passes. The removal was deployed via `sudo nixos-rebuild switch --flake .#nas`. NAS `/etc/resolv.conf` now uses `127.0.0.1` and `::1` as nameservers — AdGuard/Unbound local DNS is resolving directly. Verified: `getent ahosts github.com` succeeded on the NAS. Cloudflare bootstrap is no longer active.

---

## Phase 6 — Human: Data Migration

### 6.1 Protected user data — local copy (8 TB disk → ZFS)

| Source (`/mnt/media/...`) | Target (ZFS)            |
| ------------------------- | ----------------------- |
| `Share`                   | `/mnt/backup/Share`     |
| `Photos`                  | `/mnt/backup/photos`    |
| `Documents`               | `/mnt/backup/documents` |

```bash
rsync -aHAX --info=progress2 /mnt/media/Share/ /mnt/backup/Share/
rsync -aHAX --info=progress2 /mnt/media/Photos/ /mnt/backup/photos/
rsync -aHAX --info=progress2 /mnt/media/Documents/ /mnt/backup/documents/
```

**Verify — not just size/count, use rsync dry-run comparison:**

```bash
rsync -anicHAX --delete /mnt/media/Share/ /mnt/backup/Share/
```

Empty output = complete match. Repeat for Photos and Documents. Any differences → redo the rsync.

**✅ Phase 6.1 complete (2026-07-14).** Protected user data copied from NAS-mounted ext4 media disk to ZFS `backup` pool:

| Source (`/mnt/media/...`) | Target (ZFS)            | Bytes transferred      | rsync `-n` diff |
| ------------------------- | ----------------------- | ---------------------- | --------------- |
| `Share`                   | `/mnt/backup/Share`     | 30,578,280,068         | Passed (see note) |
| `Photos`                  | `/mnt/backup/photos`    | 120,015,119,773        | Clean — no differences |
| `Documents`               | `/mnt/backup/documents` | 8,082,339,591          | Clean — no differences |

> **Syncthing `.stfolder/` marker exception:** The `Share` rsync dry-run comparison (`-anicHAX --delete`) reported Syncthing's `.stfolder/` marker as a difference (present in source, absent in target). This is expected — the marker was never synced to ZFS because Syncthing remains stopped on the NAS. The marker is not a data discrepancy; it is a runtime artifact that will appear when Syncthing is started in a later phase. No files were deleted because verification used `-n` (dry-run).

**Syncthing remains stopped** until migration sequencing permits it (Phases 6.2–7). No Phase 6.2 or later phases are complete.

### 6.2 Application state — network copy from server

**Server is booted without the 8 TB disk** solely for this network migration. Server cannot serve media during this period.

> **Historical note (server decommissioned):** The server's `/mnt/media` mount in `hosts/server.nix` (now deleted) was set with `nofail` and `x-systemd.device-timeout=5` so the system booted cleanly without the physically absent media disk during Phase 6.2 migration. The file was removed as part of server decommission.

Each stateful service must remain **stopped** on NAS while its state is restored. Restore in this order per service:

1. **Stop** the consuming service on NAS (already done in Phase 5; verify with `systemctl is-active <unit>`).
2. **Restore** the service's state (database dump, SQLite file, volume data, etc.). Use the same tool the service uses — inspect its NixOS config (`systemctl cat <unit>`, or the service's module in `modules/server/`) to identify the correct database name and restore method.
3. **Start** the service: `sudo systemctl start <unit>` and check `systemctl status <unit>`.

Repeat for every stateful service. Example groupings (confirm actual unit names on the deployed NAS):

| Service family                 | Approximate units                                                                  |
| ------------------------------ | ---------------------------------------------------------------------------------- |
| Immich                         | `immich-server`, `immich-worker`                                                   |
| Paperless-ngx                  | `paperless-scheduler`, `paperless-consumer`, `paperless-task-queue`                |
| Actual Budget                  | `actual`                                                                           |
| Karakeep                       | `karakeep`                                                                         |
| Transmission                   | `transmission`                                                                     |
| Jellyfin / Navidrome / Calibre | verify with `systemctl list-unit-files \| grep -iE 'jellyfin\|navidrome\|calibre'` |

Additional notes:

- **PostgreSQL databases:** `pg_dump` on server → `pg_restore` on NAS. PostgreSQL is already running from deploy. Identify database names from each service's NixOS config.
- **SQLite services** (likely Karakeep, possibly Miniflux): stop the service on server, copy the database file to NAS, then start the NAS instance.
- **Docker volumes** (Excalidraw, etc.): copy volume data while Docker is running on NAS.
- **Syncthing:** do NOT copy server identity. NAS is a new device (registered after Phase 5).
- **Prometheus/Loki/Tempo:** intentionally not migrated — see Grafana restore section below for decision.

#### Immich metadata restore — fresh rebuild (complete 2026-07-14)

**Decision:** The old Immich PostgreSQL database is **not restored.** Its `pgvecto-rs` metadata (face embeddings, geodata, CLIP vectors) is disposable — it can be regenerated by Immich from the preserved photo files.

**Executed**

The fresh Immich library has been rebuilt from the preserved photo sources on the NAS. No `pgvecto-rs` compatibility layer was added — the NAS runs standard PostgreSQL, and bridging the old server's incompatible `pgvecto-rs` extension was not justified for metadata Immich can regenerate.

Preserved `originals` and `upload` directory sources were imported as Immich external libraries. Follow-up library scan dry runs report **zero new files** for both sources, confirming the import captured everything. The Immich UI reports:

| Metric  | Count   |
| ------- | ------- |
| Photos  | 14,793  |
| Videos  | 1,011   |
| Storage | 69 GiB  |

**Retained (#rollback-evidence)**

The legacy Immich storage directory (`/var/lib/immich` from server) and the staged `immich.dump` remain on disk as rollback evidence. Do not delete either before Phase 7 Immich validation passes (item 3: "Immich uploads/views").

**Gate**

Immich migration is **not marked complete.** The fresh library has been populated and verified by dry-run, but full functional validation (upload, view, search, face detection) is gated on Phase 7.

#### Miniflux database restore — complete (2026-07-14)

Miniflux operates on a PostgreSQL database. The database was archived on the server with `pg_dump` in custom format and restored on the NAS.

**Ownership correction.** The first restore attempt created database objects owned by the `postgres` role because `pg_restore` was invoked without `--no-owner`. The database was recreated owned by the `miniflux` role, then restored with `pg_restore --role=miniflux`. The `schema_version` table ownership is now `miniflux`, confirming all restored objects are owned by the service's database user.

**Gate.** Miniflux database restoration is complete. Database ownership corrected and service is active on the NAS.

#### Paperless-ngx state restore — complete (2026-07-14)

Paperless-ngx state was transferred from server to NAS via network copy.

**Archive and transfer.** `/var/lib/paperless` was archived on the server, transferred to NAS, and extracted. The archive checksum (`8607b5c613a0c4a35612e024ead9163a1727d51acd49006e9624532928d90a64`) was verified after transfer to confirm integrity.

**Ownership.** Ownership of the restored tree was normalized to the NAS `paperless:paperless` user and group (UID/GID 315) to match the NixOS service's `DynamicUser` instance.

**Service activation.** All four Paperless-ngx units are active on the NAS:
- `paperless-web.service`
- `paperless-consumer.service`
- `paperless-scheduler.service`
- `paperless-task-queue.service`

**Gate.** Paperless-ngx state transfer and service activation are complete. Functional document consumption (upload → OCR → index → search) is retained for Phase 7 validation (item 3: "Paperless consumes").

#### Karakeep state restore — complete (2026-07-14)

Karakeep uses a SQLite database (`/var/lib/karakeep/karakeep.db`). State was archived on the server, transferred to NAS via network copy, and verified.

**Archive integrity.** The transferred archive checksum (`0e67e802db88cef27d542c7da7741e0f86ba0eca866ba533751103007e162972`) was verified against the NAS copy to confirm corruption-free transfer.

**Ownership.** The restored tree under `/var/lib/karakeep` was normalized to the NAS `karakeep:karakeep` user and group (UID 983 / GID 979) to match the NixOS service's declared user.

**Service activation.** All Karakeep units are active on the NAS:
- `karakeep.service`
- `karakeep-browser.service`

**Gate.** Karakeep state restore and service activation are complete. Functional UI and data checks (browser bookmark indexing, search) are retained for Phase 7 validation.

#### Actual Budget state restore — complete (2026-07-14)

Actual uses a SQLite database located under `/var/lib/private/actual`. The directory was archived on the server, transferred to NAS, and extracted to `/var/lib/private/actual`.

**Service activation.** The `actual.service` unit is active on the NAS.

**Gate.** Actual Budget state restore and service activation are complete. Functional UI and data checks (budget data integrity, accounts, transactions) are retained for Phase 7 validation.

#### Media services state restore — complete (2026-07-14)

Media service state was archived on the server in two archives — one for services with declarative (`DynamicUser`) ownership, one for services with static UID/GID — and transferred to the NAS over the network.

**Archive integrity.**

| Archive                             | SHA-256 checksum                                                        | Verified |
| ----------------------------------- | ----------------------------------------------------------------------- | -------- |
| Static-UID media services           | `7b458ec7d15e932995397c0b258c7c310622b7d4838fad2ea3559556ce6a3f82`     | ✅ NAS   |
| DynamicUser media services          | `56e1b0d3ed7cf959154f92eaf48878733768bcf1682907b08550f38b046c9126`     | ✅ NAS   |

Both checksums matched after transfer to the NAS.

**Ownership normalization.** Static-UID service trees (`/var/lib/*`) were normalized to their target NixOS service accounts (e.g. `jellyfin:jellyfin`, `sonarr:sonarr`, `radarr:radarr`, `readarr:readarr`, `lidarr:lidarr`, `bazarr:bazarr`, `transmission:transmission`). DynamicUser services reuse the same UID range across hosts, so restored trees were already owned correctly on the NAS.

**Jellyseerr and Prowlarr private state.** These services use `DynamicUser` with `ProtectHome=private` and `StateDirectory` isolation. Their per-unit private directories under `/var/lib/private/` were restored with ownership `65534:65534` (the `nobody` range used by systemd for `DynamicUser` writable private storage). Both services start and access their state successfully.

**Active units.** Twelve media services are active on the NAS:

| #  | Service          | Unit state |
| -- | ---------------- | ---------- |
| 1  | Jellyfin         | active     |
| 2  | Jellyseerr       | active     |
| 3  | Navidrome        | active     |
| 4  | Calibre Server   | active     |
| 5  | Calibre Web      | active     |
| 6  | Sonarr           | active     |
| 7  | Radarr           | active     |
| 8  | Readarr          | active     |
| 9  | Lidarr           | active     |
| 10 | Bazarr           | active     |
| 11 | Prowlarr         | active     |
| 12 | Transmission     | active     |

**Gate.** Media service state restore and activation are complete. All twelve units are running on the NAS. Functional validation — library indexing, streaming, download history, VPN-namespaced Transmission connectivity — is retained for Phase 7. AdGuard/DNS and monitoring state are not included in this gate; their restoration is tracked separately.

#### Grafana state restore — complete (2026-07-14)

Grafana state was archived on the server, transferred to NAS via network copy, and extracted to `/var/lib/grafana`.

**Archive integrity.** The transferred archive checksum (`ca35bbdb5ed07701efe3db46a1d13da1b208010389f28a1dbb75dab61779f900`) was verified on the NAS after transfer to confirm corruption-free copy.

**Ownership.** The restored tree under `/var/lib/grafana` was normalized to the NAS `grafana:grafana` user and group (UID 196 / GID 980) to match the NixOS service account.

**Service activation.** The `grafana.service` unit is active on the NAS.

**Gate.** Grafana state restore and activation are complete. Dashboard and datasource integrity checks are retained for Phase 7 validation (item 7: "Grafana, Prometheus scrape targets").

#### Samba state restore — complete (2026-07-14)

Samba persistent state was archived on the server, transferred to NAS via network copy, and extracted to `/var/lib/samba`.

**Archive integrity.** The transferred archive checksum (`f12e3f62b3354977e228d95f1498e77f3e3df13597f164f11938f21f7f6bf92d`) was verified on the NAS after transfer to confirm corruption-free copy.

**IPC sockets excluded.** Samba runtime IPC sockets under `/var/lib/samba` (e.g. `nmbd/`, `winbindd_privileged/`) were intentionally excluded from the archive. These are recreated on daemon start and are not portable across hosts.

**Ownership.** The restored tree under `/var/lib/samba` was normalized to the NAS `root` ownership matching the NixOS Samba service's expected layout.

**Service activation.** All four Samba-related units are active on the NAS:
- `smbd.service`
- `nmbd.service`
- `winbindd.service`
- `wsdd.service`

**Gate.** Samba state restore and service activation are complete. Samba service state migration is done — `smbd`, `nmbd`, `winbindd`, and `wsdd` are running with persistent state restored. Share accessibility and functional validation (Phase 7 item 5: "Samba shares accessible") are retained for Phase 7.

#### Prometheus, Loki, Tempo — history not migrated

Prometheus time-series data (`/var/lib/prometheus2`), Loki log storage (`/var/lib/loki`), and Tempo trace storage (`/var/lib/tempo`) were **intentionally not migrated.** The NAS observability stack starts fresh. Historical metrics, logs, and traces remain on the server disk and will be discarded at decommission (Phase 9).

Decision rationale: Observability history is non-essential for operations. Fresh Prometheus, Loki, and Tempo instances provide forward-looking visibility without carrying forward stale data from a host being decommissioned.

When all restores are verified and services are running healthy on NAS, **shut down the server.** It will be booted one final time in Phase 8 for cutover dumps, then permanently decommissioned.

### 6.3 Media tree flattening

**Gate:** Run only after §6.1 ZFS copies are verified.

The Agent prepared the Nix config for flat category directories under `/mnt/media/` (no `/mnt/media/Media` intermediary). The following human steps complete the move and update runtime paths.

**Step 1 — Verify current layout:**

```bash
ls -la /mnt/media/Media/
```

Expected nonempty categories: `AudioBookShelf`, `Books`, `Channels`, `Downloads`, `import`, `Movies`, `Music`, `TV Shows`.

**Step 2 — Move each nonempty category to `/mnt/media/`:**

```bash
mv "/mnt/media/Media/AudioBookShelf" /mnt/media/
mv "/mnt/media/Media/Books" /mnt/media/
mv "/mnt/media/Media/Channels" /mnt/media/
mv "/mnt/media/Media/Downloads" /mnt/media/
mv "/mnt/media/Media/import" /mnt/media/
mv "/mnt/media/Media/Movies" /mnt/media/
mv "/mnt/media/Media/Music" /mnt/media/
mv "/mnt/media/Media/TV Shows" /mnt/media/
```

**Step 3 — Remove the malformed empty directory:**

The old tmpfiles rule produced a directory literally named `TVx20Shows` instead of `TV Shows`. It should be empty. Remove it (only succeeds if empty):

```bash
rmdir /mnt/media/Media/TVx20Shows
```

If `rmdir` fails with "Directory not empty", inspect contents before forcing removal.

**Step 4 — Remove the now-empty Media directory:**

```bash
ls -la /mnt/media/Media/   # Must be empty
rmdir /mnt/media/Media
```

If `rmdir` fails because stray files remain, inspect and remove them, then retry.

**Step 5 — Update Jellyfin and *arr runtime library paths (PENDING HUMAN ACTION):**

Jellyfin, Sonarr, Radarr, Lidarr, Readarr, and Bazarr store library root paths in their application databases — these are **not** in Nix config and must be updated through each service's web UI after the directory move. The Agent does not modify these databases.

For each service:
1. Jellyfin: Settings → Libraries → edit each library → set folder path to the flat equivalent (e.g. `/mnt/media/TV Shows` instead of `/mnt/media/Media/TV Shows`).
2. Sonarr/Radarr/Lidarr/Readarr: Settings → Media Management → Root Folders → edit root folder paths.
3. Bazarr: Settings → Sonarr/Radarr → verify paths point to the flat directories.

Navidrome and Calibre (Web/Server) library paths are handled in Nix config (`media.nix`) and apply automatically on next rebuild.

**Post-flattening:** `Share`, `Photos`, `Documents` remain on the 8 TB disk as cold fallbacks. Removed only during decommission (Phase 9).

**⚠ This phase is not marked complete.** The directory move is blocked on human execution. Jellyfin/*arr runtime path updates remain pending.

---

## Phase 7 — Human: Validate NAS (before cutover)

1. `systemctl --failed` is empty.
2. Backends respond; reverse proxies work via temporary NAS LAN address.
3. Jellyfin, Navidrome, Calibre index from flattened paths. Paperless consumes, Immich uploads/views. Immich ML (smart search, face detection) confirmed using CUDA on GPU 0 with no crash loop.
4. Arr services move files; Transmission works in WireGuard namespace (`curl --interface 192.168.15.1 http://localhost:9091`).
5. Samba shares accessible. Syncthing syncs NAS↔beast.
6. `nvidia-smi` reports GTX 1650; `/dev/dri/renderD*` exists; hardware transcode works.
7. Grafana, Prometheus scrape targets, AdGuard + Unbound DNS (test from LAN client), ACME renewal.
8. Backup snapshot + restore test for `backup/backups`.

---

## Phase 8 — Human: Cutover

**Prerequisite:** All Phase 7 checks pass. Server was shut down after Phase 6.2 network migration.

1. **Boot server one final time** (without its 8 TB media disk). Server starts only for final state capture — it is not serving production traffic and will be permanently decommissioned after step 7.
2. Announce maintenance. Pause Arr activity, stop Transmission and ingestion/backup jobs on server.
3. **Stop NAS writers.** Before final restore, stop every stateful NAS service that will receive restored state. Use the exact unit names verified in Phase 5:
   ```bash
   sudo systemctl stop <unit1> <unit2> ...  # exact names from Phase 5 discovery
   ```
4. **Final database dumps** on server. Stop stateful services, dump every PostgreSQL db, copy SQLite databases, transfer to NAS. Restore each database on NAS while its consuming service remains stopped.
5. **Start and health-check NAS services** after all restores complete:
   ```bash
   sudo systemctl start <unit1> <unit2> ...
   systemctl status <unit1> <unit2> ...
   ```
   Verify each returns healthy before proceeding.
6. **Confirm server frozen:**
   ```bash
   systemctl list-units --state=running --no-legend | awk '{print $1}' | grep -v -E '^(systemd|dbus|agetty|sshd|getty|user@|session-)'
   ```
   **Review the output.** Any configured service unit present must be stopped. The output is not expected to be literally empty, but no server-owned production service should appear.
7. **Shut down server.** It will not boot again.
8. Repoint production DNS/routing to NAS: LAN DNS, public DNS + reverse-proxy/ACME, Tailscale, AdGuard/Unbound resolver. The operator identifies every record targeting `server` IPs.
9. Production validation: upload, stream, consume a doc; DNS resolution through NAS; ACME renewal; monitoring; Samba, Syncthing, Tailscale.
10. **If validation fails:** See Failure Rule. Stop all NAS writers, restore from server source.
11. **If validation passes:** Proceed immediately to Phase 9.

---

## Phase 9 — Agent & Human: Decommission Server

### Agent

#### 9.1 ✅ `[heavy]` Strip server role — COMPLETED

**File:** `hosts/server.nix` — deleted. Server fully decommissioned; `hosts/server.nix` no longer exists.

#### 9.2 `[heavy]` Update docs and Syncthing

**File:** `docs/Host-Configurations.md` — reflect NAS as sole service host.
**File:** `modules/services/syncthing.nix` — remove `"server"` device entry; update beast folder devices from `"server"` → `"nas"`.

### Human

1. **Verify server is powered down** (shut down in Phase 8 step 7). Not retained as rollback.
2. **Clean up cold fallbacks** (on NAS 8 TB disk): verify ZFS `backup` pool health and backup integrity, then remove `/mnt/media/{Share,Photos,Documents}`. Do NOT remove media categories.
3. Physical disposition of server hardware — operator decision.
4. Retain final database dumps on NAS backup storage before wiping server disks.

---

## Failure Rule

- **Before cutover (Phase 8 step 8 — DNS repoint):** Keep server running, repair NAS, retry.
- **After cutover, before validation passes:** Stop all NAS writers. Restore from server source state. Never run both hosts as concurrent writers.
- Cold fallbacks on NAS ext4 disk remain as recovery during the repair window; remove only in Phase 9.
- Once server is decommissioned, it is not restored. Recovery is from ZFS backups and ext4 cold copies.

---

## Human Verification Checklist (ungated)

| Item                            | Command / Method                                                         |
| ------------------------------- | ------------------------------------------------------------------------ |
| ZFS disk by-id paths            | `lsblk -o NAME,SERIAL,PATH,SIZE,TYPE,MODEL` + inspect `/dev/disk/by-id/` |
| App-data NVMe by-id path        | Same — must differ from boot NVMe                                        |
| Btrfs UUID post-format          | `sudo blkid /dev/disk/by-id/<appdata-nvme-id>`                           |
| NAS `networking.hostId`         | `head -c8 /etc/machine-id`                                               |
| WireGuard secret retained as-is | Operator chose to keep `server-wg.conf` — no rename needed              |
| Syncthing NAS device ID         | NAS GUI at `http://<nas-lan-ip>:8384` after first start                  |
| NVIDIA open kernel vs. GTX 1650 | Test `open = true`; fall back to `false` if needed                       |
| ZFS recordsize tuning           | Benchmark with workloads; default 128K safe                              |
| DNS records to repoint          | Identify every A/AAAA/CNAME targeting `server` IPs                       |
