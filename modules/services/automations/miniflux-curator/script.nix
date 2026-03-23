{ pkgs, inputs }:

let
  # Use unstable nixpkgs for the miniflux Python package
  unstablePkgs = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  # Python package with required libraries
  curatorPy = unstablePkgs.writers.writePython3Bin "miniflux-curator" {
    libraries = with unstablePkgs.python3Packages; [ miniflux numpy ];
  } (builtins.readFile ./curator.py);
in

pkgs.writeShellApplication {
  name = "miniflux-curator";
  runtimeInputs = [
    curatorPy
  ];
  text = ''
    set -euo pipefail

    # Validate required environment variables
    : "''${MINIFLUX_URL:?MINIFLUX_URL environment variable not set}"
    : "''${MINIFLUX_API_KEY:?MINIFLUX_API_KEY environment variable not set}"
    : "''${OPENAI_HOST:?OPENAI_HOST environment variable not set}"

    # Optional config with defaults
    export AUTO_MARK_READ_BELOW=''${AUTO_MARK_READ_BELOW:-3.5}
    export LIMIT_UNREAD=''${LIMIT_UNREAD:-400}
    export DRY_RUN=''${DRY_RUN:-true}
    export EMBED_MODEL=''${EMBED_MODEL:-qwen3-embedding-8b}
    export BATCH_SIZE=''${BATCH_SIZE:-64}

    exec ${curatorPy}/bin/miniflux-curator
  '';
}
