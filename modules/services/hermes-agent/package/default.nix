{
  inputs,
  pkgs,
  self,
  ...
}:

let
  hermesPkgBase = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  hermesPythonOverridePatchDir = builtins.path {
    path = ./patches;
    name = "hermes-agent-patches";
  };
  enCoreWebSm = self.packages.${pkgs.stdenv.hostPlatform.system}.en-core-web-sm;
  mem0ai = self.packages.${pkgs.stdenv.hostPlatform.system}.mem0ai;
  mem0PythonSupport = pkgs.python313.withPackages (ps: [
    enCoreWebSm
    ps.fastembed
    mem0ai
    ps.spacy
  ]);
  mem0PythonPath = "${mem0PythonSupport}/${pkgs.python313.sitePackages}";
in
{
  config.services.hermes-agent.package = hermesPkgBase.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      python_overrides="$out/share/hermes-agent/python-overrides"
      site_packages="${hermesPkgBase.passthru.hermesVenv}/lib/python3.12/site-packages"

      mkdir -p "$python_overrides"
      cp "$site_packages/hermes_constants.py" "$python_overrides/hermes_constants.py"
      cp "$site_packages/utils.py" "$python_overrides/utils.py"
      cp -rL "$site_packages/hermes_cli" "$python_overrides/hermes_cli"
      chmod -R u+w "$python_overrides"

      if [ ! -f "$python_overrides/hermes_constants.py" ] || [ ! -f "$python_overrides/hermes_cli/auth.py" ] || [ ! -f "$python_overrides/utils.py" ]; then
        echo "failed to locate Hermes auth sources in $out" >&2
        exit 1
      fi

      # This host intentionally shares HERMES_HOME between the hermes service
      # user and the codyt CLI via the hermes group, so keep the upstream
      # local patches explicit and reviewable in ./patches.
      for patch_file in ${hermesPythonOverridePatchDir}/*.patch; do
        patch -p1 -d "$python_overrides" < "$patch_file"
      done

      for bin_name in hermes hermes-agent hermes-acp; do
        wrapProgram "$out/bin/$bin_name" --prefix PYTHONPATH : "$python_overrides:${mem0PythonPath}"
      done
    '';
  });
}
