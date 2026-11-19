# NAS Backups

- Register service data in the owning aspect's NixOS contribution through `nas.backups.*`. This directory owns the options, export and backup jobs, and backup health checks; don't add a per-service job for data the central job can handle.
- Register live SQLite files with `nas.backups.sqlite` for a consistent export before Restic runs. Never list a live database file as a direct Restic input. Give multiple databases from one service distinct export filenames.
- Declare service-specific exclusions alongside those inputs. If a service prepares a dump, register its unit as both `Requires` and `After` on the shared Restic unit; register the existing unit name (without `.service`) in `nas.backups.healthJobs` when it needs health reporting.
- Check the NAS's merged `nas.backups.sqlite` and `nas.backups.dataDirectories` entries when coverage changes. Preserve ordering when editing NAS aspect includes that contribute to these lists. Registration proves neither a successful backup nor a working restore.
