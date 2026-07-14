# NAS Service Migration

This runbook moves the `server` service role to `nas` without treating the new host as a disposable rebuild. `server` remains the production source until a named cutover gate passes.

## Current Facts

| Item               | Source (`server`)                                                                                    | Target (`nas`)                                            | Consequence                                                                                                                                            |
| ------------------ | ---------------------------------------------------------------------------------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| System storage     | 477 GB NVMe ext4, 150 GB used                                                                        | 931 GB NVMe Btrfs, 919 GB free                            | OS volume; retain capacity for Nix store and system recovery.                                                                                          |
| Service storage    | `/mnt/media` on a 7.3 TB ext4 volume, 5.4 TB used                                                    | Two unmounted 3.6 TB ext4 volumes (`sda1`, `sdb1`)        | The two 4 TB disks become the mirrored ZFS pool for locally protected data. Their existing data can be discarded.                                      |
| Media data         | `/mnt/media/Media` is 5.3 TB                                                                         | The existing 8 TB media drive will move physically to NAS | Mount the filesystem at `/mnt/media`; TV, movies, books, music, downloads, and channels remain under its `Media` directory on this non-redundant disk. |
| Protected files    | `/mnt/media/Share` is 29 GB; Photos and Documents currently use `/mnt/media`                         | Move to the mirrored ZFS pool                             | Home files, photos, documents, and all other non-media files live on the protected tier.                                                               |
| Service data       | Karakeep is 2.6 GB, Paperless is 633 MB, Syncthing is 30 MB; other state also lives under `/var/lib` | No service role enabled                                   | Migrate persistent state with service-aware backups or a stopped final copy.                                                                           |
| Video acceleration | `/dev/dri` is present                                                                                | GTX 1650 (`10de:1f82`), currently using `nouveau`         | Configure and verify the NVIDIA production driver before CUDA or NVIDIA transcoding workloads run.                                                     |

The target disk identifiers are:

| Device           | UUID                                   | Format              | Existing mount |
| ---------------- | -------------------------------------- | ------------------- | -------------- |
| `/dev/sda1`      | `7e4d866f-4494-41c6-850b-a5dc2cd8367a` | ext4                | none           |
| `/dev/sdb1`      | `9dc55264-1ade-4f7b-a157-60d022feec40` | ext4                | none           |
| `/dev/nvme1n1p1` | `34882b6b-6f50-4caa-93ff-b27688c41f1a` | Btrfs, label `work` | none           |

Do not format, repartition, or mount a target data disk read-write until its existing contents and intended role have been checked.

## Decisions Required Before Copying

1. Recreate the two 4 TB disks as the ZFS mirror pool `important`. It provides about 3.6 TB usable capacity with one-disk fault tolerance. Their existing data can be discarded.
2. Create `important/share`, `important/photos`, `important/documents`, and `important/backups` datasets. Mount them below `/mnt/important` and enable automatic pool import, scheduled scrubs, snapshots, and pool health monitoring in the NAS configuration.
3. Reformat the spare 1 TB NVMe (`nvme1n1`) as Btrfs and make it the fast application and recovery tier. Its current `work` filesystem contains no required data.
4. Create distinct Btrfs subvolumes for application state and temporary work. Back up the boot system and application state to the ZFS `important/backups` dataset; the mirror itself still needs an independent backup destination.
5. Set the cutover time and acceptable read-only window. The final state sync must occur while writers are stopped.
6. Confirm how LAN DNS and public ingress switch from `server` to `nas`. Both hosts cannot serve the same production addresses during the overlap.

## Service Inventory

The `../modules/server` role currently enables:

| Group               | Services                                                                                                                                               |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Ingress and network | Nginx, ACME/Cloudflare DNS-01, Tailscale, AdGuard Home, Unbound, Samba, NFS, Syncthing, Fail2Ban                                                       |
| Media               | Jellyfin, Navidrome, Calibre-Web, Calibre Server, Jellyseerr, Prowlarr, Radarr, Sonarr, Lidarr, Readarr, Bazarr, Transmission in WireGuard confinement |
| Personal data       | Immich, Paperless-ngx with Tika, Karakeep with Meilisearch, Miniflux and curator, Actual                                                               |
| Observability       | Grafana, Prometheus, Loki, Tempo, Fluent Bit, node/Nginx/SMART exporters                                                                               |
| Containers          | Excalidraw                                                                                                                                             |

`beast` continues to own Open WebUI and Qdrant. The NAS ingress configuration must retain the existing proxies to `beast`.

## Execution Plan

### 1. Prepare Host Configuration

1. Preserve `hosts/nas.nix` as the host-facts file and add only NAS-specific storage, hardware, and network facts there.
2. After powering down `server`, move its 8 TB media disk to NAS. Verify its UUID and filesystem without formatting it, then mount its existing filesystem at `/mnt/media`. Only its `Media` directory remains in use for non-redundant media categories after the protected data is moved.
3. Build the two 4 TB disks as the ZFS mirror pool `important`, then create and mount `share`, `photos`, `documents`, and `backups` datasets below `/mnt/important`. This is destructive to their current standalone ext4 filesystems, but their data may be discarded. Configure ZFS pool import at boot, scheduled scrubs, snapshots, and `zpool` health alerts.
4. Create `/mnt/important/share` with `codyt:users` ownership and use it for the `codytHome` Samba share and the NAS Syncthing folder. Change the current `/mnt/media/Share` references in Samba and Syncthing. Change Immich and Paperless storage from `/mnt/media/Photos` and `/mnt/media/Documents` to `/mnt/important/photos` and `/mnt/important/documents`.
5. Add the NVIDIA production driver configuration for the GTX 1650 as host-local NAS hardware configuration. Start with the supported open kernel module, verify it binds to the card after rebuild, and use the proprietary kernel module only if the open module fails. Include the NVIDIA GPU Prometheus exporter only if it is useful to operate the NAS.
6. With 16 GB RAM and the full service stack, cap the ZFS ARC at 4 GiB initially and monitor memory pressure. ZFS can run reliably with this memory, but it must not crowd Immich, Karakeep, PostgreSQL, and media transcoding.
7. Reformat the spare WD Blue SN580 1 TB NVMe (`nvme1n1`) as Btrfs. Mount its application-state subvolume at `/mnt/appdata` and keep a separate temporary-work subvolume for downloads, transcodes, and unpacking.
8. Move application state onto `/mnt/appdata` through service-specific data paths or declared bind mounts. Start with PostgreSQL, Immich metadata, Paperless, Karakeep/Meilisearch, Actual, Grafana, Prometheus, Loki, Tempo, and Docker state. Do not migrate a state directory by copying it while its service is running.
9. Back up the boot system and `/mnt/appdata` to `important/backups`. Include `/boot`, `/etc/nixos`, SOPS configuration, service database dumps, and the data needed to rebuild the system. The application-state NVMe remains a single device, so its service data must not be its only copy.
10. Do not attach the NVMe as ZFS L2ARC, SLOG, or a special vdev: L2ARC adds RAM pressure, a consumer NVMe is not a safe write log without power-loss protection, and loss of a non-redundant special vdev can lose the pool.
11. Extract hard-coded `server` assumptions before importing `../modules/server` on NAS:

- Syncthing currently only declares the shared folder for hostname `server` and identifies the device as `server`; add a distinct NAS device identity and folder mapping.
- Monitoring labels and dashboard text currently identify the local host as `server`; change them to derive the host name or explicitly label NAS.
- Evaluate whether the `server-wg.conf` secret is a shared provider credential or needs a NAS-specific SOPS entry before Transmission starts.

12. Remove `arm.nix` from the server-role import before NAS imports that role. This retires ARM rather than carrying its custom image, optical-drive dependency, and privileged container to NAS.
13. Add the moved media disk's persistent `/mnt/media` declaration. Configure the protected ZFS dataset mountpoints independently; do not use the old `Share`, `Photos`, or `Documents` directories on the media disk after cutover.
14. Keep `server` online until the planned disk-move window. Build and deploy the NAS service role only after the target mounts are active and `systemd-tmpfiles` can see their directories.
15. Keep production hostnames directed to `server` during this stage. Test NAS services by its LAN address or a temporary internal hostname, not the production `homehub.tv` names.
16. Run `nixos-rebuild dry-run --flake .#nas` after each risky configuration change, then deploy to NAS only after it evaluates cleanly.

Exit gate: NAS boots with the moved 8 TB media volume at `/mnt/media`, all non-media data on the `important` ZFS mirror below `/mnt/important`, Btrfs application subvolumes on the spare NVMe, a bounded and healthy ARC, the GTX 1650 driver bound successfully, all intended services can start, no service writes to the root filesystem by accident, and production ingress still resolves to `server`.

### 2. Stage Data While Server Remains Live

1. Before moving the media disk, record `df -hT`, its UUID, and a manifest of the top-level `/mnt/media` tree. This is the before/after proof that the physical move did not alter the media filesystem.
2. Do not copy `/mnt/media/Media` over the network. It moves with the 8 TB disk. After NAS mounts it, compare the manifest and capacity report to the source record.
3. Seed `/mnt/media/Share`, `/mnt/media/Photos`, and `/mnt/media/Documents` into their matching `important` ZFS datasets using a resumable, metadata-preserving transfer, then perform a final incremental sync during cutover.
4. Copy only application state that remains on the source NVMe or Docker storage. A current source scan reports `Photos` and `Documents` nearly empty, but preserve their ownership and service database state regardless.
5. Restore migrated application state to `/mnt/appdata` before starting its owning service. Keep the service's normal pathname through its data-path option or a declared bind mount; do not change application paths ad hoc.
6. Copy application state by service class, not by one blind `/var/lib` copy:
   - PostgreSQL-backed applications: take a logical PostgreSQL backup and restore it to NAS. Do not copy live PostgreSQL data files.
   - SQLite-backed applications: use the service's backup/export method or stop it for the final copy, particularly Karakeep and Actual.
   - Immich and Paperless: migrate their databases plus their configured media roots. Redis can be recreated unless a service-specific recovery requirement proves otherwise.
   - Prometheus, Loki, Tempo, Grafana, AdGuard, Miniflux, Syncthing, and Docker volumes: identify their actual state directories from the running unit and migrate only required state. History may be intentionally discarded only by explicit choice.
7. Treat `/var/lib/syncthing` as identity state. Do not start NAS Syncthing with a copied server identity; create/register NAS as its own device, then retire the server device after cutover.

Exit gate: a repeatable transfer command and checksum/count comparison prove the seed copy is complete; NAS applications can read restored state while their public writers remain disabled.

### 3. Validate Services Before Cutover

1. Confirm every expected systemd unit is active on NAS and that `systemctl --failed` is empty.
2. Verify each local backend responds on its configured port, then test each reverse proxy through the temporary NAS route.
3. Verify permissions with the service users: Arr services can move a test file, Jellyfin/Navidrome/Calibre can index media, Paperless can consume a test document, and Immich can upload and view a test image.
4. Verify Transmission is confined to its WireGuard namespace and that its RPC remains available to the Arr services without exposing peer traffic outside the intended namespace.
5. Verify NAS NFS exports and Samba shares from `beast`; update the Beast media mount only at cutover.
6. Verify the GTX 1650 with `nvidia-smi`, verify its `/dev/dri` render node, and run a controlled Jellyfin or Immich NVIDIA hardware-transcode job.
7. Check the dashboards, Prometheus scrape targets, AdGuard DNS resolution, ACME renewal credentials, and NAS backups.

Exit gate: every service has a successful functional probe, data ownership is correct, and all services are reachable through the planned NAS ingress route.

### 4. Cut Over

1. Announce the maintenance window and stop new writes: pause Arr activity and Transmission, then stop stateful writers on `server` in dependency order.
2. Take final database backups and perform the final incremental application-state sync. Do not proceed until source/destination manifests match.
3. Start the restored stateful services on NAS, verify their local health, then switch LAN DNS, public DNS/reverse-proxy routing, and Beast NFS mounts to NAS.
4. Validate the production hostnames, uploads, a media stream, a Paperless consume action, a Karakeep action, and DNS resolution from a LAN client.
5. Keep `server` powered on but all conflicting services stopped for the rollback window. Do not let it resume writing to its old data.

Exit gate: production traffic reaches NAS, critical read and write paths pass, and the source is idle and preserved.

### 5. Stabilize and Retire

1. Monitor NAS logs, SMART metrics, disk capacity, backups, DNS, and service failures for the agreed rollback window.
2. Remove or disable the old service role only after backups from NAS complete and a restore check succeeds.
3. Update `docs/Host-Configurations.md`, `modules/server/README.md`, Syncthing device configuration, monitoring labels, and any Beast mounts to describe NAS as the service host.
4. Archive the final source manifest, database backup checksums, service inventory, and the exact DNS cutover time.

## Rollback Rule

Before DNS/NFS cutover, rollback means keep `server` running and repair NAS. After cutover, rollback means stop NAS writers, redirect ingress and mounts to `server`, and resume the source only from its preserved pre-cutover state. Never run both hosts as writers against divergent copies of the same service data.

## Operator Checklist

- [ ] 8 TB media disk is recorded, moved, and mounted at `/mnt/media` without reformatting.
- [ ] Two 4 TB disks are recreated as the `important` ZFS mirror with datasets for share, photos, documents, and backups.
- [ ] ZFS pool import, scrub schedule, health monitoring, and a 4 GiB ARC cap are configured.
- [ ] The spare 1 TB NVMe is reformatted as Btrfs with application-state and temporary-work subvolumes.
- [ ] Application state moves to `/mnt/appdata` through service-specific paths or declared bind mounts.
- [ ] Boot-system recovery data and app-state backups are stored in `important/backups`; the ZFS pool has an independent backup destination.
- [ ] The spare 1 TB NVMe is not a ZFS cache or special vdev.
- [ ] `/mnt/media/Share`, `Photos`, and `Documents` are transferred and verified on the `important` ZFS datasets.
- [ ] GTX 1650 driver, telemetry, and a hardware-transcode probe pass.
- [ ] NAS configuration evaluates and mounts persistent storage.
- [ ] NAS-specific secrets and Syncthing identity are present.
- [ ] Moved media filesystem and transferred application state verified.
- [ ] Functional probes pass on NAS.
- [ ] Cutover window scheduled and rollback owner named.
- [ ] Final sync and database backups verified.
- [ ] DNS, NFS, and service ingress cut over.
- [ ] NAS backup restore test passes before source retirement.
