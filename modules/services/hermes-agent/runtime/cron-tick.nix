{
  config,
  lib,
  pkgs,
  ...
}:

let
  hermesAgent = config.services.hermes-agent;
in
{
  config = {
    systemd.services.hermes-agent-cron-tick = {
      description = "Run due Hermes cron jobs";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        HOME = hermesAgent.stateDir;
        HERMES_HOME = "${hermesAgent.stateDir}/.hermes";
        HERMES_MANAGED = "true";
        MESSAGING_CWD = hermesAgent.workingDirectory;
      };

      path = [
        hermesAgent.package
        pkgs.bash
        pkgs.coreutils
        pkgs.git
      ]
      ++ hermesAgent.extraPackages;

      serviceConfig = {
        Type = "oneshot";
        User = hermesAgent.user;
        Group = hermesAgent.group;
        WorkingDirectory = hermesAgent.workingDirectory;
        ExecStart = "${lib.getExe hermesAgent.package} cron tick";
        UMask = "0007";
      };
    };

    systemd.timers.hermes-agent-cron-tick = {
      description = "Wake system and run Hermes cron scheduler";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = [
          "*-*-* 07:00:00"
          "*-*-* 23:00:00"
        ];
        Persistent = true;
        WakeSystem = true;
      };
    };
  };
}
