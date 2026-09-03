{ pkgs, inputs }:

let
  # Use unstable nixpkgs for the miniflux Python package
  unstablePkgs = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  unstablePython = unstablePkgs.python3;

  # Build the curator package (curator/ directory in this tree)
  curatorPackage = unstablePython.pkgs.buildPythonPackage {
    pname = "miniflux-curator";
    version = "0.1.0";
    format = "pyproject";
    src = ./.;
    nativeBuildInputs = [ unstablePython.pkgs.setuptools ];
    dependencies = [
      unstablePython.pkgs.miniflux
      unstablePython.pkgs.numpy
    ];
    doCheck = false;
  };

  # A thin bin wrapper that exposes the `miniflux-curator` command
  curatorBin = unstablePkgs.writeShellApplication {
    name = "miniflux-curator";
    runtimeInputs = [ curatorPackage ];
    text = "exec ${curatorPackage}/bin/miniflux-curator \"$@\"";
  };
in

pkgs.writeShellApplication {
  name = "miniflux-curator";
  runtimeInputs = [ curatorBin ];
  text = ''
    set -euo pipefail

    # Validate required environment variables
    : "''${MINIFLUX_URL:?MINIFLUX_URL environment variable not set}"
    : "''${MINIFLUX_API_KEY:?MINIFLUX_API_KEY environment variable not set}"
    : "''${KARAKEEP_URL:?KARAKEEP_URL environment variable not set}"
    : "''${KARAKEEP_API_KEY:?KARAKEEP_API_KEY environment variable not set}"
    : "''${OPENAI_HOST:?OPENAI_HOST environment variable not set}"
    : "''${OPENAI_API_KEY:?OPENAI_API_KEY environment variable not set}"

    # Optional config with defaults
    export AUTO_MARK_READ_BELOW=''${AUTO_MARK_READ_BELOW:-3.5}
    export LIMIT_UNREAD=''${LIMIT_UNREAD:-400}
    export DRY_RUN=''${DRY_RUN:-true}
    export EMBED_MODEL=''${EMBED_MODEL:-qwen3-embedding-8b}
    export BATCH_SIZE=''${BATCH_SIZE:-64}
    export KARAKEEP_FETCH_LIMIT=''${KARAKEEP_FETCH_LIMIT:-100}
    export REFERENCE_LIMIT=''${REFERENCE_LIMIT:-50}

    exec ${curatorBin}/bin/miniflux-curator
  '';
}
