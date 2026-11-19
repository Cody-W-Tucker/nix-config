# Backups

`den.aspects.backups` (Restic jobs, ZFS snapshots), `_backup-options.nix` (the `nas.backups.*` options) and `den.aspects.backup-health` (backup health metrics). Included by nas.


Photo and document data live on the `backup/photos` and `backup/documents` ZFS datasets, which `backups.nix` snapshots centrally. Service modules register their SQLite databases through `nas.backups.sqlite` for the Restic job in `backups.nix`; there are no per-service BorgBackup jobs.


Include order in `modules/hosts/nas.nix` fixes the order of the `nas.backups.*` lists (den concatenates included modules in reverse include order).
