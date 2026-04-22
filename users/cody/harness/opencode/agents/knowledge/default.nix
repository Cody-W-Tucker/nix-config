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
in
{
  imports = [
    ../../skills/obsidian
    ../../skills/qmd
  ];

  sops.secrets.karakeep-api-key = { };

  programs.opencode.settings = {
    mcp.karakeep = {
      type = "local";
      command = [ "${karakeepMcp}/bin/karakeep-mcp" ];
      enabled = true;
    };

    tools."karakeep_*" = false;
  };

  programs.opencode.agents.knowledge = ''
    ---
    description: Knowledge work agent for notes, bookmarks, dashboards, and research.
    mode: primary
    tools:
      "karakeep_*": true
    permission:
      edit: allow
      bash: allow
      "context7_*": deny
      "nixos-option-search_*": deny
      skill:
        "*": deny
        "obsidian-*": allow
        qmd: allow
    ---

    Knowledge mode for notes, bookmarks, and research workflows.
  '';
}
