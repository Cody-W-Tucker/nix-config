{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Persistent user-scoped CRM database. Under the NixOS scope this lived in
  # /var/lib/hermes/crm and was mapped into a container; the Home Manager
  # service runs natively as the user, so the DB lives under HERMES_HOME.
  crmDatabasePath = "${hermesHome}/crm/crm.db";
  inherit (config.services.hermes-agent) hermesHome;
  ldLibraryPath = lib.concatStringsSep ":" [
    "/run/opengl-driver/lib"
    "/run/current-system/sw/lib"
    (lib.makeLibraryPath [ pkgs.libopus ])
  ];
in

{
  config = {
    # User-scoped runtime dirs. Upstream's hermes-agent-setup activation
    # creates HERMES_HOME, the workspace and the standard state subdirs; this
    # rule adds the CRM directory that nothing else provisions.
    systemd.user.tmpfiles.rules = [
      "d ${hermesHome}/crm 0700 - - -"
    ];

    # Home Manager user units have no NixOS-style restartTriggers; changes to
    # settings or provisioned documents apply on the next
    # `systemctl --user restart hermes-agent`.
    systemd.user.services.hermes-agent.Service = {
      Environment = [
        "CRM_DB=${crmDatabasePath}"
        "LD_LIBRARY_PATH=${ldLibraryPath}"
      ];

      TimeoutStopSec = lib.mkDefault 210;
    };
  };
}
