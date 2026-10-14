{
  config,
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

  # Use the interpreter family selected by the Hermes flake's pythonLock.
  # Never layer a host or stale Python ABI over the sealed Hermes venv.
  hermesPython = config.services.hermes-agent.package.python;
  hermesPythonPackages = hermesPython.pkgs;
  # The official Langfuse plugin pins this exact SDK. Build only the SDK
  # wheel here; its shared dependencies stay in Hermes' sealed environment
  # or are supplied explicitly below, avoiding the module's collision guard.
  langfuse415 = hermesPythonPackages.buildPythonPackage rec {
    pname = "langfuse";
    version = "4.15.2";
    format = "pyproject";
    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-f4GPOMwi2rqI/c7GLSrdzuThjRr0Upl4ttB1AehraUY=";
    };
    build-system = [ hermesPythonPackages.uv-build ];
    dependencies = with hermesPythonPackages; [
      httpx
      pydantic
      backoff
      wrapt
      packaging
      opentelemetry-api
      opentelemetry-sdk
      opentelemetry-exporter-otlp-proto-http
      typing-extensions
    ];
    doCheck = false;
    pythonImportsCheck = [ ];
  };
  # PYTHONPATH only — wrapping extraPythonPackages would duplicate sealed
  # httpx/pydantic packages and intentionally fails collision checks.
  # Langfuse needs the OTLP HTTP exporter closure, not the meta exporter
  # package (which pulls gRPC).
  hermesPythonPath = lib.makeSearchPath hermesPython.sitePackages (
    with hermesPythonPackages;
    [
      backoff
      langfuse415
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
