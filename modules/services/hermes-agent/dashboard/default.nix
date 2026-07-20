# Hermes Dashboard — remote web UI on port 9119.
#
# Separate process from hermes-agent.service (the messaging gateway).
# Shares HERMES_HOME for config/sessions. Requires basic auth when
# binding to a non-loopback address.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.hermes-agent;
  inherit (cfg) user group stateDir;

  # Mirror upstream effectivePackage so the dashboard gets the same
  # Python environment (extraDependencyGroups, extraPythonPackages).
  effectivePackage =
    if cfg.extraPythonPackages == [ ] && cfg.extraDependencyGroups == [ ] then
      cfg.package
    else
      cfg.package.override { inherit (cfg) extraPythonPackages extraDependencyGroups; };
in
{
  config = {
    sops.secrets = {
      "hermes-dashboard-username" = { };
      "hermes-dashboard-password" = { };
      "hermes-dashboard-secret" = { };
    };

    sops.templates."hermes-dashboard-env" = {
      content = ''
        HERMES_DASHBOARD_BASIC_AUTH_USERNAME=${config.sops.placeholder."hermes-dashboard-username"}
        HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=${config.sops.placeholder."hermes-dashboard-password"}
        HERMES_DASHBOARD_BASIC_AUTH_SECRET=${config.sops.placeholder."hermes-dashboard-secret"}
      '';
    };

    systemd.services.hermes-dashboard = {
      description = "Hermes Dashboard Web UI";
      wantedBy = [ "multi-user.target" ];
      after = [ "hermes-agent.service" ];
      wants = [ "hermes-agent.service" ];

      environment = {
        HOME = stateDir;
        HERMES_HOME = "${stateDir}/.hermes";
        HERMES_MANAGED = "true";
      };

      serviceConfig = {
        User = user;
        Group = group;
        WorkingDirectory = "${stateDir}/workspace";
        EnvironmentFile = [ config.sops.templates."hermes-dashboard-env".path ];
        ExecStart = lib.concatStringsSep " " [
          "${effectivePackage}/bin/hermes"
          "dashboard"
          "--no-open"
          "--host"
          "0.0.0.0"
          "--port"
          "9119"
          "--skip-build"
        ];
        Restart = "always";
        RestartSec = 5;
        UMask = "0007";

        # Hardening (matches hermes-agent.service)
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = false;
        ReadWritePaths = [
          stateDir
          "${stateDir}/workspace"
        ];
        PrivateTmp = true;
      };

      path = [
        effectivePackage
        pkgs.bash
        pkgs.coreutils
      ]
      ++ cfg.extraPackages;
    };
  };
}
