{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  python = config.services.hermes-agent.package.python.pkgs;
  hindsightSource = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.hindsight.src;
  hindsightClient = python.buildPythonPackage {
    pname = "hindsight-client";
    version = "0.10.1";
    pyproject = true;
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/ac/81/03d22890aa5fa8b09fa1c290814cf0ff716bd5c6b537305458467092e5a1/hindsight_client-0.10.1.tar.gz";
      hash = "sha256-dkxDJsFBI8XJIi8hrl6+Yu8jI8YMiQezVmf1+CkkyB0=";
    };
    build-system = [ python.hatchling ];
    dependencies = with python; [
      urllib3
      python-dateutil
      aiohttp
      aiohttp-retry
      pydantic
      typing-extensions
      yarl
    ];
    pythonImportsCheck = [ "hindsight_client" ];
    doCheck = false;
  };
  hindsightEmbed = python.buildPythonPackage {
    pname = "hindsight-embed";
    version = "0.10.1";
    pyproject = true;
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/63/e3/85af37fc3b35c24182fb24fa831fd36ad601331eb7e590a3d330cfb44767/hindsight_embed-0.10.1.tar.gz";
      hash = "sha256-Fhe28k2tFwmr7Q1fRuRNmc/PlgJxC+f1Wsgf6hp1gzg=";
    };
    build-system = [ python.hatchling ];
    dependencies = with python; [
      aiohttp
      rich
    ];
    pythonImportsCheck = [ "hindsight_embed" ];
    doCheck = false;
  };
  hindsightPlugin = pkgs.runCommand "hermes-plugin-hindsight" { } ''
    cp -R ${hindsightSource}/hindsight-integrations/hermes "$out"
  '';
  # Hermes already seals shared libraries into its environment. Package only
  # the plugin-specific modules so extraPythonPackages does not add their
  # propagated copies of aiohttp, urllib3, pydantic, etc. a second time.
  hindsightPython = python.toPythonModule (
    pkgs.runCommand "hermes-hindsight-python" { } ''
      mkdir -p "$out/${config.services.hermes-agent.package.python.sitePackages}"
      for package in ${hindsightClient} ${hindsightEmbed}; do
        cp -R "$package/${config.services.hermes-agent.package.python.sitePackages}/." \
          "$out/${config.services.hermes-agent.package.python.sitePackages}/"
      done
    ''
  );
in
{
  services.hermes-agent = {
    extraPythonPackages = [ hindsightPython ];
    hermesHomeFiles."hindsight/config.json" = builtins.toJSON {
      mode = "local_external";
      api_url = "http://127.0.0.1:8888";
      bank_id = "cody";
      auto_retain = true;
      auto_recall = true;
      memory_mode = "hybrid";
    };
  };

  home.activation.hermesHindsightPlugin = lib.hm.dag.entryAfter [ "hermesAgentSetup" ] ''
    $DRY_RUN_CMD ln -sfn ${hindsightPlugin} ${config.services.hermes-agent.hermesHome}/plugins/hindsight
  '';
}
