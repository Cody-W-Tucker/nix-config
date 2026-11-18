# Host Configurations

The flake exports exactly two NixOS configurations. They are declared with [Den](https://github.com/denful/den) in [`den/`](../den) (see [`den/README.md`](../den/README.md)) and re-exported by [`flake.nix`](../flake.nix):

- `nixosConfigurations.beast` — [`modules/hosts/beast.nix`](../modules/hosts/beast.nix) holds the host, its machine facts and (via [`_beast-hardware.nix`](../modules/hosts/_beast-hardware.nix)) its hardware, with the desktop role and features, against `nixpkgs-unstable` and `home-manager`.
- `nixosConfigurations.nas` — [`modules/hosts/nas.nix`](../modules/hosts/nas.nix) holds the host, its machine facts and (via [`_nas-hardware.nix`](../modules/hosts/_nas-hardware.nix)) its hardware, with the NAS role, against stable `nixpkgs` and `home-manager-stable`.

Both hosts share foundational modules under [`modules/system/`](../modules/system) (e.g. [`modules/system/base.nix`](../modules/system/base.nix)).

## Beast — Desktop Workstation

- **Composition root:** [`den/hosts/beast.nix`](../den/hosts/beast.nix); machine facts in [`hosts/beast/default.nix`](../hosts/beast/default.nix).
- **Channel:** `nixpkgs-unstable` (see [`flake.nix`](../flake.nix)).
- **Role:** Development, gaming, and local AI workloads.

## NAS — Home Lab Server

- **Composition root:** [`den/hosts/nas.nix`](../den/hosts/nas.nix); machine facts in [`hosts/nas/default.nix`](../hosts/nas/default.nix), with host-local [`hosts/nas/models.nix`](../hosts/nas/models.nix).
- **Host documentation:** [`hosts/nas/README.md`](../hosts/nas/README.md) — hardware profile, storage layout, networking, services, ZFS pool health.
- **Channel:** stable `nixpkgs` (`nixos-26.05`), paired with `home-manager-stable` (`release-26.05`).
- **Role:** Central services host for the `homehub.tv` infrastructure. NAS service modules live under [`modules/nas/`](../modules/nas).

### Backup and snapshot health

- [NAS Backups dashboard](https://monitoring.homehub.tv/d/nas-backups) shows Restic repository health plus three daily database jobs and local ZFS snapshots of `backup/photos`, `backup/documents`, `backup/Share`, and `backup/backups` (daily, weekly, monthly). It reads restic-exporter and zfs_exporter metrics; per-snapshot creation timestamps come directly from the exporter at scrape time. Pool status/capacity for `backup` comes from the pool collector (`health,allocated,free,size`).
- Restic health uses repository check/snapshot age; database health combines the latest result with last-success age (26-hour daily limit). Snapshot health uses per-snapshot creation timestamps and collection success from the exporter. Missing metrics mean **not reporting**, not a successful backup; monthly snapshots can be pending until their first scheduled run.
- For a failed or missing job, check `systemctl status <unit>` and `journalctl -u <unit>`. For a stale report, also check the backup mount at `/mnt/backup/backups` and `.prom` files under `/var/lib/node-exporter-textfile/`. Run `systemctl start <unit>` only after resolving the cause, then confirm the dashboard updates.

## Comparison Summary

| Feature             | Beast (Workstation)                              | NAS (Home Lab)                                       |
| ------------------- | ------------------------------------------------ | ---------------------------------------------------- |
| **Nixpkgs channel** | `nixos-unstable`                                 | `nixos-26.05` (stable)                               |
| **Home Manager**    | `home-manager` (unstable)                        | `home-manager-stable` (`release-26.05`)              |
| **Composition root**| [`den/hosts/beast.nix`](../den/hosts/beast.nix) | [`den/hosts/nas.nix`](../den/hosts/nas.nix)  |
| **Module scope**    | Desktop + AI modules under `modules/`            | NAS service modules under [`modules/nas/`](../modules/nas) |
