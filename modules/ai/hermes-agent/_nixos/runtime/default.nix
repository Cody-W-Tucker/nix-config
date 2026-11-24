{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.hermes-agent;
  inherit (inputs.workflow.packages.${pkgs.stdenv.hostPlatform.system}) workflowCli;
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
    services.hermes-agent.extraPackages = [
      pkgs.crm-cli
      workflowCli
    ];
    environment.etc."hermes/starter-skills/cli".source = pkgs.linkFarm "hermes-cli-starter-skills" {
      "tools/crm-cli/SKILL.md" = "${pkgs.crm-cli.src}/skills/SKILL.md";
      "operational/verified-work-run" = "${inputs.workflow}/skills/operational/verified-work-run";
    };

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
