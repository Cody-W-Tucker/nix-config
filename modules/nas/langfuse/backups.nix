{ pkgs, ... }:

{
  nas.backups.dataDirectories = [
    "/mnt/appdata/langfuse/minio"
    "/mnt/backup/backups/langfuse"
  ];

  systemd.services.langfuse-postgres-backup = {
    description = "Create a consistent Langfuse PostgreSQL dump";
    after = [
      "docker-postgres.service"
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
      UMask = "0077";
      ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0700 /mnt/backup/backups/langfuse";
      ExecStart = pkgs.writeShellScript "langfuse-postgres-backup" (
        builtins.readFile ./langfuse-postgres.sh
      );
    };
  };

  systemd.services.langfuse-clickhouse-backup = {
    description = "Create a consistent Langfuse ClickHouse backup";
    after = [
      "docker-clickhouse.service"
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
      ExecStart = pkgs.writeShellScript "langfuse-clickhouse-backup" (
        builtins.readFile ./langfuse-clickhouse.sh
      );
    };
  };

  systemd.timers.langfuse-postgres-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  systemd.timers.langfuse-clickhouse-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
