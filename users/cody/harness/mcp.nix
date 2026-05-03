{ pkgs, ... }:

let
  qdrantReadOnlyMcp = pkgs.writeShellApplication {
    name = "qdrant-read-only-mcp";
    runtimeInputs = [ pkgs.uv ];
    text = ''
      export QDRANT_URL="https://qdrant.homehub.tv:443"
      export QDRANT_READ_ONLY=true
      export FASTEMBED_CACHE_PATH="$HOME/.cache/fastembed"
      mkdir -p "$FASTEMBED_CACHE_PATH"

      exec uvx --python 3.12 mcp-server-qdrant "$@"
    '';
  };
in
{
  # Global MCP tools for all agents
  programs.mcp = {
    enable = true;
    servers = {
      context7 = {
        command = "nix-shell";
        args = [
          "-p"
          "nodejs"
          "--run"
          "npx -y @upstash/context7-mcp"
        ];
      };
      gh_grep = {
        type = "remote";
        url = "https://mcp.grep.app";
      };
      nixos-option-search = {
        command = "nix";
        args = [
          "run"
          "github:utensils/mcp-nixos"
        ];
      };
      qdrantRead = {
        command = "${qdrantReadOnlyMcp}/bin/qdrant-read-only-mcp";
      };
    };
  };
}
