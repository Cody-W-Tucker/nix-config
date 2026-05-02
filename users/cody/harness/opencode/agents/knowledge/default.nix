{ pkgs, config, ... }:

let
  karakeepMcp = pkgs.writeShellApplication {
    name = "karakeep-mcp";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      export KARAKEEP_API_ADDR="https://karakeep.homehub.tv"
      KARAKEEP_API_KEY="$(< ${config.sops.secrets.karakeep-api-key.path})"
      export KARAKEEP_API_KEY

      exec npx -y @karakeep/mcp "$@"
    '';
  };

  qdrantMcp = pkgs.writeShellApplication {
    name = "qdrant-mcp";
    runtimeInputs = [ pkgs.uv ];
    text = ''
      export QDRANT_URL="https://qdrant.homehub.tv"
      export FASTEMBED_CACHE_PATH="$HOME/.cache/fastembed"
      mkdir -p "$FASTEMBED_CACHE_PATH"

      exec uvx --python 3.12 mcp-server-qdrant "$@"
    '';
  };
in
{
  imports = [
    ./skills/qmd
    ./skills/obsidian
  ];

  sops.secrets.karakeep-api-key = { };

  programs.opencode.settings = {
    mcp.karakeep = {
      type = "local";
      command = [ "${karakeepMcp}/bin/karakeep-mcp" ];
      enabled = true;
    };

    mcp.qdrant = {
      type = "local";
      command = [ "${qdrantMcp}/bin/qdrant-mcp" ];
      enabled = true;
    };

    tools."karakeep_*" = false;
    tools."qdrant_*" = false;
  };

  programs.opencode.agents.knowledge = ''
    ---
    description: Knowledge work agent for notes, bookmarks, dashboards, and research.
    mode: subagent
    tools:
      "karakeep_*": true
      "qdrant_*": true
    permission:
      "context7_*": deny
      "nixos-option-search_*": deny

    ---
    You are a knowledge management specialist focused on research, note-taking, and information organization.

    Examples:

    - Use QMD for fast full-text search across markdown files
    - Search Obsidian vault by content, properties, or graph connections
    - Retrieve bookmarks
    - Store and retrieve semantic memory in Qdrant collections
    - Synthesize information from multiple sources
  '';
}
