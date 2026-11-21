# Backups

The NAS keeps Restic backups and ZFS snapshots on the local backup pool. These are not off-site copies. Losing the NAS can mean losing both the original and its backup.

## Check the last backup

On the NAS, run `systemctl status restic-backups-nas-files.service` to see the result of the 05:00 Restic job. For details, run `journalctl -u restic-backups-nas-files.service`. If the backup pool is not mounted, the job skips the run. The [backup panels](monitoring.md) stay empty while the disk is unmounted.

| What you need back | Where to look |
| --- | --- |
| Projects, Knowledge, Hermes state or application database exports | Restic at `/mnt/backup/backups/restic` |
| Immich originals, Paperless originals or an older version of the shared folder | `zfs list -t snapshot -r backup` on the NAS |
| The media library on `/mnt/media` | Not covered by these jobs |

## Changing it

| To change | Edit |
| --- | --- |
| Restic schedule, repository or ZFS snapshot coverage | [`backups.nix`](../../modules/backups/backups.nix) |
| Backup health reporting | [`backup-health.nix`](../../modules/backups/backup-health.nix) |
| Data backed up for an app | The app's aspect; see the [backup instructions](../../modules/backups/AGENTS.md) |
