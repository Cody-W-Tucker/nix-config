{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # Persistent user-scoped CRM database under HERMES_HOME.
  crmDatabasePath = "${hermesHome}/crm/crm.db";
  inherit (config.services.hermes-agent) hermesHome;
  ldLibraryPath = lib.concatStringsSep ":" [
    "/run/opengl-driver/lib"
    "/run/current-system/sw/lib"
    (lib.makeLibraryPath [ pkgs.libopus ])
  ];

  # Match the Python 3.12 interpreter used by Hermes' sealed uv2nix venv.
  hermesPythonPackages =
    inputs.hermes-agent.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.python312Packages;
  # PYTHONPATH only — do not wrap extraPythonPackages (httpx collision).
  # Langfuse 4 needs the OTLP HTTP exporter closure, not the meta
  # opentelemetry-exporter-otlp package (that pulls gRPC).
  hermesPythonPath = lib.makeSearchPath "lib/python3.12/site-packages" (
    with hermesPythonPackages;
    [
      backoff
      langfuse
      wrapt
      opentelemetry-api
      opentelemetry-sdk
      opentelemetry-semantic-conventions
      opentelemetry-exporter-otlp-proto-http
      opentelemetry-exporter-otlp-proto-common
      opentelemetry-proto
    ]
  );
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
        "PYTHONPATH=${hermesPythonPath}"
      ];

      TimeoutStopSec = lib.mkDefault 210;
    };

    systemd.user.services.hermes-backend.Service = {
      Environment = [ "PYTHONPATH=${hermesPythonPath}" ];
    };
  };
}
