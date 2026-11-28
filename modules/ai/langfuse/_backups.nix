{ pkgs, ... }:

let
  jobs = [
    "langfuse-postgres-backup"
    "langfuse-clickhouse-backup"
  ];
  backup = db: description: serviceConfig: {
    inherit description;
    after = [
      "docker-${db}.service"
      "mnt-backup-backups.mount"
    ];
    requires = [ "mnt-backup-backups.mount" ];
    path = [
      pkgs.docker
      pkgs.coreutils
    ];
    unitConfig.ConditionPathIsMountPoint = "/mnt/backup/backups";
    serviceConfig = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0700 /mnt/backup/backups/langfuse";
      ExecStart = pkgs.writeShellScript "langfuse-${db}-backup" (builtins.readFile ./langfuse-${db}.sh);
    }
    // serviceConfig;
  };
in
{
  nas.backups = {
    healthJobs = jobs;
    dataDirectories = [
      "/mnt/appdata/langfuse/minio"
      "/mnt/backup/backups/langfuse"
    ];
  };

  systemd.services = {
    restic-backups-nas-files.unitConfig = rec {
      After = map (job: "${job}.service") jobs;
      Requires = After;
    };
    langfuse-postgres-backup = backup "postgres" "Create a consistent Langfuse PostgreSQL dump" {
      UMask = "0077";
    };
    langfuse-clickhouse-backup =
      backup "clickhouse" "Create a consistent Langfuse ClickHouse backup"
        { };
  };
}
