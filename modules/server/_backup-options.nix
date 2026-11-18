{ lib, ... }:

{
  options.nas.backups = {
    dataDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Service data directories and payload files backed up directly by Restic. Live SQLite database files must NOT be listed here; register them under nas.backups.sqlite instead so they are consistently exported before Restic runs.";
    };

    sqlite = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Staging directory name under /mnt/backup/backups/<name>/ holding the consistent export.";
            };
            source = lib.mkOption {
              type = lib.types.str;
              description = "Live SQLite database file to export with `sqlite3 .backup`. Never backed up directly; only the staged export is a Restic input.";
            };
            filename = lib.mkOption {
              type = lib.types.str;
              default = "database.db";
              description = "Staged export filename inside /mnt/backup/backups/<name>/. Use a non-default value when one service owns several SQLite files (e.g. Hermes state.db and crm.db).";
            };
          };
        }
      );
      default = [ ];
      description = "SQLite databases consistently exported to /mnt/backup/backups/<name>/<filename> by Restic backupPrepareCommand immediately before the Restic run. No dedicated systemd services or timers are created for these entries.";
    };
  };
}
