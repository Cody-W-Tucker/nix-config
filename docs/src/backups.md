# Backups

The NAS backs itself up every night and snapshots its storage pool. Both copies live on the NAS's own `backup` pool; there is no off-site copy.

## What is protected

| Data | Method | Retention |
| --- | --- | --- |
| Projects, Knowledge, certificates, every service database and registered data directory | Restic, nightly 05:00 | 7 daily, 4 weekly, 6 monthly |
| `backup/photos`, `backup/documents`, `backup/Share`, `backup/backups` | ZFS snapshots (UTC) only | 7 daily, 4 weekly, 3 monthly |

## Checking it

Open the [NAS Backups dashboard](https://monitoring.homehub.tv/d/nas-backups). It shows Restic repository health and snapshot age (refreshed hourly), the three nightly database dumps, each ZFS snapshot, and the pool's health and capacity. A dump is green if it succeeded within 26 h. An empty panel means the job is not reporting, not that it is healthy; a monthly snapshot stays pending until its first run. Nothing alerts; check the dashboard.

## When something is red

1. On the NAS, run `systemctl status <unit>` and `journalctl -u <unit>`. Units: `restic-backups-nas-files`, `postgresqlBackup`, `langfuse-postgres-backup`, `langfuse-clickhouse-backup`. If Restic stopped on a missing SQLite file, the error names the file.
2. If the panel is stale rather than failed, check that `/mnt/backup/backups` is mounted, and check the `nas_backup_*.prom` files in `/var/lib/node-exporter-textfile/`.
3. Correct the cause.
4. Run `systemctl start <unit>`. Confirm the dashboard updates.

## Restoring

No restore procedure is written yet. Restic repository: `/mnt/backup/backups/restic`, password in the SOPS secret `restic-nas-password`. Snapshot data is in each dataset's snapshots.

## Changing it

| To change | Edit |
| --- | --- |
| Back up a service's SQLite or data directory | `nas.backups.sqlite` / `nas.backups.dataDirectories` in that service's file. Options: [`_backup-options.nix`](../../modules/backups/_backup-options.nix) |
| Schedule, retention, fixed paths, ZFS snapshots | [`backups.nix`](../../modules/backups/backups.nix) |
| Health-checked jobs (`nas.backups.healthJobs`) | [`backup-health.nix`](../../modules/backups/backup-health.nix) |
