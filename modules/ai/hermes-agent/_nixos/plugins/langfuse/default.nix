{
  config,
  lib,
  pkgs,
  ...
}:
let
  langfusePlugin = import ../lib/build-plugin.nix pkgs {
    name = "langfuse";
    rev = "a4e311e433f1470b1fec15434deea6a05e8644eb";
    hash = "sha256-q9gpwik7FUp2z6H69z5eoq7qNZYvdi6KvU7fOG796C4=";
    requiresHermes = "0.21.7";
  };
  hermesPython = config.services.hermes-agent.package.python;
  hermesPythonPackages = hermesPython.pkgs;
  langfuse415 = hermesPythonPackages.buildPythonPackage rec {
    pname = "langfuse";
    version = "4.15.2";
    format = "pyproject";
    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-f4GPOMwi2rqI/c7GLSrdzuThjRr0Upl4ttB1AehraUY=";
    };
    build-system = [ hermesPythonPackages.uv-build ];
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
  systemd.services = {
    hermes-agent = {
      preStart = ''
        ln -sfn ${langfusePlugin} ${config.services.hermes-agent.stateDir}/.hermes/plugins/langfuse
      '';
      environment.PYTHONPATH = hermesPythonPath;
    };
    hermes-backend.environment.PYTHONPATH = hermesPythonPath;
  };
  codyos.workarounds.hermes-langfuse-uv-build = {
    reason = "Langfuse 4.15.2 caps uv_build below 0.12 while Hermes's Python set has 0.12.x, so langfuse415 relaxes the bound. Its --replace-fail breaks the build once a newer Langfuse drops the cap.";
    upstream = "https://github.com/NousResearch/hermes-agent/issues/48576";
    reviewBy = "2027-01-15";
  };

  codyos.hermes-agent.egress.loopbackPorts = [ 3030 ];
  services.hermes-agent = {
    extraPlugins = lib.mkOrder 1000 [ langfusePlugin ];
    environment.HERMES_LANGFUSE_BASE_URL = "http://127.0.0.1:3030";
  };
}
