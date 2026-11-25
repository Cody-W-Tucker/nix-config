# Backups

The NAS keeps Restic backups and ZFS snapshots on the local backup pool. These are not off-site copies. Losing the NAS can mean losing both the original and its backup.

## Check the last backup

On the NAS, run `systemctl status restic-backups-nas-files.service` to see the result of the 05:00 Restic job. For details, run `journalctl -u restic-backups-nas-files.service`. If the backup pool is not mounted, the job skips the run. The [backup panels](monitoring.md) stay empty while the disk is unmounted.

| What you need back | Where to look |
| --- | --- |
| Projects, Knowledge, Hermes, Karakeep assets, Langfuse objects, Vaultwarden keys and attachments | Restic, 7 daily, 4 weekly and 6 monthly snapshots |
| An app database, last night's copy | `/mnt/backup/backups/<app>/` on the NAS |
| An app database, an older night | Restic, under `/mnt/backup/backups/<app>` |
| PostgreSQL databases (Hindsight, Immich, LiteLLM, Miniflux, Dawarich) | `/mnt/backup/backups/postgresql/all.sql.zstd`, one dump of all databases. It loads whole into an empty PostgreSQL server. |
| Photos, documents or the shared folder | ZFS snapshots on the NAS, 7 daily, 4 weekly and 3 monthly |
| The media library on `/mnt/media` | Not covered by these jobs |

## Bring back files from Restic

Run these on the NAS. `restic-nas-files` is Restic with the repository and password already set.

1. List the snapshots: `sudo restic-nas-files snapshots`.
2. Find a file by name: `sudo restic-nas-files find '<name>'`.
3. Restore into a scratch folder: `sudo restic-nas-files restore latest --target /tmp/restore --include /mnt/projects/<path>`. Use a snapshot ID in place of `latest` for an older night.
4. The files appear under their full path, for example `/tmp/restore/mnt/projects/<path>`. Compare them, then copy back what you need.
5. Delete `/tmp/restore`.

## Bring back an app database

Each app's SQLite database is exported to `/mnt/backup/backups/<app>/` before the 05:00 run. To list each export with its live path, run `nix eval --json .#nixosConfigurations.nas.config.nas.backups.sqlite` in `/etc/nixos`.

1. Stop the app: `sudo systemctl stop <app>`.
2. Move the live database and its `-wal` and `-shm` files to a scratch folder. A leftover `-wal` file damages the restored database.
3. Copy the export to the live path.
4. Give the file the owner the old one had, for example `sudo chown paperless:paperless /var/lib/paperless/db.sqlite3`.
5. Start the app.

For an older night, restore `/mnt/backup/backups/<app>` from Restic first, then copy from `/tmp/restore`.

### Hermes

Hermes keeps its databases in `/var/lib/hermes/.hermes`. Each export in `/mnt/backup/backups/hermes/` has the same relative path, for example `profiles/research/state.db`. Restic stores the other Hermes files under `/var/lib/hermes`; for snapshots from before the system service migration, look under `/home/codyt/.local/share/hermes`.

1. Stop Hermes: `sudo systemctl stop hermes-agent hermes-backend`.
2. Move the live database and its `-wal` and `-shm` files aside.
3. Copy the export to the same path under `/var/lib/hermes/.hermes`. For `crm/crm.db`, use `/var/lib/hermes/crm/crm.db` instead.
4. Run `sudo chown hermes:hermes` on the copied file.
5. Start Hermes: `sudo systemctl start hermes-agent hermes-backend`.

## Bring back from a ZFS snapshot

Each snapshot is a read-only folder. Only root can open it.

1. List the snapshots: `zfs list -t snapshot -r backup`.
2. List a snapshot's files: `sudo ls /mnt/backup/<dataset>/.zfs/snapshot/<snapshot>/`, for example `/mnt/backup/photos/.zfs/snapshot/zfs-auto-snap_daily-2026-11-22-06h00U/`.
3. Copy the files you need out with `sudo cp`, then give them back their owner.

## Changing it

| To change | Edit |
| --- | --- |
| Restic schedule, repository or ZFS snapshot coverage | [`backups.nix`](../../modules/backups/backups.nix) |
| Backup health reporting | [`backup-health.nix`](../../modules/backups/backup-health.nix) |
| Data backed up for an app | The app's aspect; see the [backup instructions](../../modules/backups/AGENTS.md) |
