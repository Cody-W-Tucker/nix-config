{
  config,
  lib,
  pkgs,
  ...
}:

let
  crmDatabasePath = "/home/codyt/.crm/crm.db";
  ldLibraryPath = lib.concatStringsSep ":" [
    "/run/opengl-driver/lib"
    "/run/current-system/sw/lib"
    (lib.makeLibraryPath [ pkgs.libopus ])
  ];
in

{
  imports = [
    ./filesystem-access.nix
    ./cron-tick.nix
  ];

  config = {
    systemd.services.hermes-agent = {
      restartTriggers = [
        (pkgs.writeText "hermes-agent-config-trigger" (
          builtins.toJSON config.services.hermes-agent.settings
        ))
      ];

      environment = {
        CRM_DB = crmDatabasePath;
        LD_LIBRARY_PATH = ldLibraryPath;
      };

      serviceConfig = {
        TimeoutStopSec = 210;
        UMask = "0007";
        UnsetEnvironment = [ "MESSAGING_CWD" ];
      };
    };
  };
}
