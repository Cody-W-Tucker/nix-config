{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Container-visible persistent path.  Host /var/lib/hermes/crm/crm.db maps
  # to /data/crm/crm.db inside the container; crm is installed via npm there.
  crmDatabasePath = "/data/crm/crm.db";
  inherit (config.services.hermes-agent) group stateDir user;
  ldLibraryPath = lib.concatStringsSep ":" [
    "/run/opengl-driver/lib"
    "/run/current-system/sw/lib"
    (lib.makeLibraryPath [ pkgs.libopus ])
  ];
in

{
  config = {
    systemd.tmpfiles.rules = [
      "d ${stateDir}/crm 0750 ${user} ${group} -"
    ];

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
        TimeoutStopSec = lib.mkDefault 210;
        UMask = "0007";
      }
      // lib.optionalAttrs (!config.services.hermes-agent.container.enable) {
        UnsetEnvironment = [ "MESSAGING_CWD" ];
      };
    };
  };
}
