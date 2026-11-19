{
  lib,
  fetchFromGitHub,
  fetchPypi,
  python3,
  runCommand,
  writers,
}:

let
  src = fetchFromGitHub {
    owner = "langfuse";
    repo = "claude-observability-plugin";
    rev = "b1619f994240ad49de4a97caa01d7d7853944fc0"; # plugin 1.2.2
    hash = "sha256-Sre9VdShLbnr5NUsYemrYSbBlwFtxZSqd6dDTADq+Kk=";
  };

  # The hook requires langfuse>=4.7,<5; nixpkgs ships 4.0.2. Match the
  # 4.15.2 SDK the Hermes Langfuse plugin already builds.
  python = python3.override {
    self = python;
    packageOverrides = _: prev: {
      langfuse = prev.langfuse.overridePythonAttrs (old: rec {
        version = "4.15.2";
        src = fetchPypi {
          pname = "langfuse";
          inherit version;
          hash = "sha256-f4GPOMwi2rqI/c7GLSrdzuThjRr0Upl4ttB1AehraUY=";
        };
        build-system = [ prev.uv-build ];
        # WORKAROUND: langfuse 4.15.2 caps uv_build below 0.12; nixpkgs has 0.12.x.
        # REVIEW-BY: 2026-11-30
        postPatch = (old.postPatch or "") + ''
          substituteInPlace pyproject.toml \
            --replace-fail 'uv_build>=0.11.2,<0.12.0' 'uv_build>=0.11.2'
        '';
        dependencies = old.dependencies ++ [ prev.typing-extensions ];
        doCheck = false;
      });
    };
  };

  pythonEnv = python.withPackages (ps: [ ps.langfuse ]);

  # Upstream runs the hook through `uv run --script`, which installs the SDK
  # from PyPI at hook time. Run it with the Nix interpreter instead.
  hooksJson =
    let
      hook = {
        type = "command";
        command = "${lib.getExe pythonEnv} \"\${CLAUDE_PLUGIN_ROOT}\"/hooks/langfuse_hook.py";
      };
    in
    writers.writeJSON "hooks.json" {
      hooks = {
        Stop = [ { hooks = [ hook ]; } ];
        SessionEnd = [ { hooks = [ hook ]; } ];
      };
    };
in
runCommand "claude-code-langfuse-observability-1.2.2" { passthru = { inherit pythonEnv src; }; } ''
  mkdir -p "$out/hooks"
  cp -R ${src}/.claude-plugin "$out/"
  cp ${src}/LICENSE ${src}/README.md "$out/"
  cp ${src}/hooks/langfuse_hook.py "$out/hooks/"
  cp ${hooksJson} "$out/hooks/hooks.json"
''
