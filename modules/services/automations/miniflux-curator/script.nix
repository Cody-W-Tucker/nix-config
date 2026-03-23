{ pkgs, inputs }:

let
  # Use unstable nixpkgs for the miniflux Python package
  unstablePkgs = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  # Python package with required libraries
  curatorPy = unstablePkgs.writers.writePython3Bin "miniflux-curator" {
    libraries = with unstablePkgs.python3Packages; [ miniflux pyyaml numpy ];
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
    AUTO_MARK_READ_BELOW=''${AUTO_MARK_READ_BELOW:-3.5}
    LIMIT_UNREAD=''${LIMIT_UNREAD:-400}
    DRY_RUN=''${DRY_RUN:-true}
    EMBED_MODEL=''${EMBED_MODEL:-qwen3-embedding-8b}
    BATCH_SIZE=''${BATCH_SIZE:-64}

    # Create temporary config file
    CONFIG_FILE=$(mktemp)
    trap 'rm -f "$CONFIG_FILE"' EXIT

    cat > "$CONFIG_FILE" << EOF
    miniflux_url: "$MINIFLUX_URL"
    api_key: "$MINIFLUX_API_KEY"
    embedding:
      host: "$OPENAI_HOST"
      model: "$EMBED_MODEL"
    auto_mark_read_below: $AUTO_MARK_READ_BELOW
    limit_unread: $LIMIT_UNREAD
    dry_run: $DRY_RUN
    batch_size: $BATCH_SIZE
    EOF

    exec ${curatorPy}/bin/miniflux-curator --config "$CONFIG_FILE"
  '';
}
