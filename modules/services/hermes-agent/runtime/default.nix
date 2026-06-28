{
  config,
  hermesComputerUseRuntime,
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
    ./computer-use.nix
    ./filesystem-access.nix
    ./cron-tick.nix
  ];

  config = {
    services.dbus.enable = true;

    environment.systemPackages = [
      pkgs.at-spi2-core
    ];

    systemd.services.hermes-agent = {
      path = hermesComputerUseRuntime.extraPackages;

      restartTriggers = [
        (pkgs.writeText "hermes-agent-config-trigger" (
          builtins.toJSON config.services.hermes-agent.settings
        ))
      ];

      environment = {
        CRM_DB = crmDatabasePath;
        LD_LIBRARY_PATH = ldLibraryPath;
      }
      // hermesComputerUseRuntime.serviceEnvironment;

      serviceConfig = {
        TimeoutStopSec = 210;
        UMask = "0007";
        UnsetEnvironment = [ "MESSAGING_CWD" ];
      };
    };
  };
}
