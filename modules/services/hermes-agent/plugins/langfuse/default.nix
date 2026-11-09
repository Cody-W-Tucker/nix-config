{
  config,
  lib,
  pkgs,
  ...
}:
let
  officialPlugins = pkgs.fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-official-plugins";
    rev = "a4e311e433f1470b1fec15434deea6a05e8644eb";
    hash = "sha256-q9gpwik7FUp2z6H69z5eoq7qNZYvdi6KvU7fOG796C4=";
  };
  langfusePlugin = pkgs.runCommand "langfuse" { } ''
    cp -R ${officialPlugins}/langfuse "$out"
    # The installed Hermes source is post-extraction but its Nix derivation
    # reports 0.0.0, so the catalog's semantic-version gate is a false reject.
    substituteInPlace "$out/plugin.yaml" \
      --replace-fail 'requires_hermes: ">=0.21.7"' 'requires_hermes: ">=0.0.0"'
  '';
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
    # WORKAROUND: Langfuse 4.15.2 caps its build backend below uv-build 0.12,
    # while Hermes's locked Python set provides uv-build 0.12.5. Patch the
    # obsolete upper bound so PEP 517 can build the wheel.
    # Upstream: https://github.com/NousResearch/hermes-agent/issues/48576
    # REVIEW-BY: 2026-11-30
    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail 'uv_build>=0.11.2,<0.12.0' 'uv_build>=0.11.2'
    '';
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
  home.activation.hermesLangfusePlugin = lib.hm.dag.entryAfter [ "hermesAgentSetup" ] ''
    $DRY_RUN_CMD ln -sfn ${langfusePlugin} ${config.services.hermes-agent.hermesHome}/plugins/langfuse
  '';
  services.hermes-agent = {
    extraPlugins = lib.mkOrder 1000 [ langfusePlugin ];
    environment.HERMES_LANGFUSE_BASE_URL = "https://langfuse.homehub.tv";
  };
  systemd.user.services.hermes-agent.Service.Environment = [ "PYTHONPATH=${hermesPythonPath}" ];
  systemd.user.services.hermes-backend.Service.Environment = [ "PYTHONPATH=${hermesPythonPath}" ];
}
