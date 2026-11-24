{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.hermes-agent;
  # Expose only the CRM directory, not HERMES_HOME, to terminal commands.
  crmDir = "${cfg.stateDir}/crm";
  ldLibraryPath = lib.concatStringsSep ":" [
    "/run/opengl-driver/lib"
    "/run/current-system/sw/lib"
    (lib.makeLibraryPath [ pkgs.libopus ])
  ];
in

{
  config = {
    # Upstream's activation creates stateDir, HERMES_HOME, the workspace and
    # the standard state subdirs; this adds the CRM directory.
    systemd.tmpfiles.rules = [
      "d ${crmDir} 2770 ${cfg.user} ${cfg.group} - -"
    ];
    codyos.hermes-agent.sandbox.binds = [
      {
        src = crmDir;
        readonly = false;
      }
    ];

    systemd.services.hermes-agent = {
      environment = {
        CRM_DB = "${crmDir}/crm.db";
        LD_LIBRARY_PATH = ldLibraryPath;
      };
      serviceConfig.TimeoutStopSec = lib.mkDefault 210;
    };
  };
}
