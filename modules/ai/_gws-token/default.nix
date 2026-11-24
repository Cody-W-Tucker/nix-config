{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.hermes-agent;
  gws = inputs.googleworkspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.gws;
  encryptedCredentials = inputs.nixos-secrets + "/secrets/hermes-gws.yaml";
  enrolled = builtins.pathExists encryptedCredentials;
  credentials = config.sops.secrets."hermes-gws-oauth".path;
  tokenDir = "/run/hermes-gws";
  token = "${tokenDir}/access-token";
  wrapper = pkgs.writeShellScriptBin "gws" ''
    if [[ ''${1-} == --help || ''${1-} == --version ]]; then
      exec ${lib.getExe gws} "$@"
    fi
    if [[ ! -s ${token} || ! -r ${token} ]]; then
      echo 'gws: no Hermes access token; check hermes-gws-token.timer and hermes-gws-token.service on the NAS.' >&2
      exit 1
    fi
    export GOOGLE_WORKSPACE_CLI_TOKEN="$(<${token})"
    exec ${lib.getExe gws} "$@"
  '';
in
{
  # Put only the expiring access token in the terminal, never the refresh credential.
  services.hermes-agent.extraPackages = [ wrapper ];
  codyos.hermes-agent.sandbox.binds = [
    {
      src = tokenDir;
      readonly = true;
    }
  ];
  systemd.tmpfiles.rules = [ "d ${tokenDir} 0750 root ${cfg.group} - -" ];

  sops.secrets."hermes-gws-oauth" = lib.mkIf enrolled {
    sopsFile = encryptedCredentials;
    format = "yaml";
    key = "oauth";
    restartUnits = [ "hermes-gws-token.service" ];
  };

  systemd.services.hermes-gws-token = lib.mkIf enrolled {
    description = "Refresh Hermes's Google Workspace access token";
    after = [
      "network-online.target"
      "systemd-tmpfiles-setup.service"
    ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = credentials;
    environment.SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe pkgs.python3} ${./refresh.py} ${credentials} ${token} ${cfg.group}";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      ReadWritePaths = [ tokenDir ];
    };
  };
  systemd.timers.hermes-gws-token = lib.mkIf enrolled {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15s";
      OnCalendar = "*:0/20";
    };
  };
}
