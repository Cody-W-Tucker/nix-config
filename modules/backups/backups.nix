{ den, ... }:
{
  den.aspects = {
    nas.includes = [ den.aspects.backups ];

    backups.nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:

      let
        repository = "/mnt/backup/backups/restic";
        passwordFile = config.sops.secrets."restic-nas-password".path;

        cfg = config.nas.backups;

        fixedHostData = [
          "/mnt/projects"
          "/mnt/knowledge"
          "/var/lib/acme"
          "/mnt/backup/backups/postgresql"
        ];

        stagedDirs = lib.unique (map (s: "/mnt/backup/backups/${s.name}") cfg.sqlite);

        sqlitePrepare = pkgs.writeShellScript "restic-sqlite-prepare" (
          ''
            set -eu
            umask 077
          ''
          + lib.concatMapStringsSep "\n" (
            s:
            let
              destDir = "/mnt/backup/backups/${s.name}";
              dest = "${destDir}/${s.filename}";
              destTmp = "${dest}.in-progress";
              sqliteFileArg = "'${lib.replaceStrings [ "'" ] [ "''" ] destTmp}'";
              dotCommand = ".backup ${sqliteFileArg}";
            in
            ''
              ${pkgs.coreutils}/bin/install -d -m 0700 ${lib.escapeShellArg destDir} ${lib.escapeShellArg (dirOf dest)}
              if [ ! -f ${lib.escapeShellArg s.source} ]; then
                printf 'restic-sqlite-prepare: error: %s missing, refusing to back up %s/%s\n' ${lib.escapeShellArg s.source} ${lib.escapeShellArg s.name} ${lib.escapeShellArg s.filename} >&2
                exit 1
              fi
              ${pkgs.sqlite}/bin/sqlite3 ${lib.escapeShellArg s.source} ${lib.escapeShellArg dotCommand}
              ${pkgs.coreutils}/bin/mv -f ${lib.escapeShellArg destTmp} ${lib.escapeShellArg dest}
              ${pkgs.coreutils}/bin/chmod 0600 ${lib.escapeShellArg dest}
            ''
          ) cfg.sqlite
        );
      in
      {
        imports = [ ./_backup-options.nix ];

        sops.secrets."restic-nas-password" = { };
        nas.backups.healthJobs = [ "postgresqlBackup" ];

        services = {
          restic.backups.nas-files = {
            initialize = true;
            inherit passwordFile repository;
            paths = fixedHostData ++ cfg.dataDirectories ++ stagedDirs;
            exclude = [ "*.in-progress" ];
            backupPrepareCommand = "${sqlitePrepare}";
            timerConfig.OnCalendar = "*-*-* 05:00:00";
            pruneOpts = [
              "--keep-daily 7"
              "--keep-weekly 4"
              "--keep-monthly 6"
            ];
          };

          postgresqlBackup = {
            enable = true;
            backupAll = true;
            compression = "zstd";
            location = "/mnt/backup/backups/postgresql";
            startAt = [ ];
          };

          zfs.autoSnapshot = {
            enable = true;
            frequent = 0;
            hourly = 0;
            daily = 7;
            weekly = 4;
            monthly = 3;
            flags = "-k -p --utc";
          };
        };

        systemd.services = {
          restic-backups-nas-files.unitConfig = {
            After = [ "postgresqlBackup.service" ];
            Requires = [ "postgresqlBackup.service" ];
            ConditionPathIsMountPoint = [
              "/mnt/projects"
              "/mnt/knowledge"
              "/mnt/appdata"
              "/mnt/backup/backups"
            ];
            RequiresMountsFor = [
              "/mnt/projects"
              "/mnt/knowledge"
              "/mnt/appdata"
              repository
            ];
          };

          postgresqlBackup = {
            unitConfig = {
              RequiresMountsFor = "/mnt/backup/backups/postgresql";
              ConditionPathIsMountPoint = "/mnt/backup/backups";
            };
            serviceConfig = {
              ExecStartPre = [
                "+${pkgs.coreutils}/bin/install -d -o postgres -g postgres -m 0700 /mnt/backup/backups/postgresql"
              ];
              UMask = "0077";
            };
          };
        };

        system.activationScripts.zfs-auto-snapshot.text = ''
          ${pkgs.zfs}/bin/zfs set com.sun:auto-snapshot=false backup
          for dataset in backup/photos backup/documents backup/Share backup/backups; do
            ${pkgs.zfs}/bin/zfs set com.sun:auto-snapshot=true "$dataset"
          done
        '';
      };
  };
}
